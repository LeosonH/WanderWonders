import { type AuthUser, bearer, isUuid, json, jwtSubject } from '../_shared/wonder.ts'

interface DeleteInput {
  confirmation: string
  requestId: string
  appleAuthorizationCode?: string
}

export interface DeleteDependencies {
  authenticate(token: string): Promise<AuthUser | null>
  profileExists(userId: string): Promise<boolean>
  revokeApple(code: string): Promise<boolean>
  deleteUser(userId: string): Promise<boolean>
  allow(userId: string): boolean
  now(): number
}

function validInput(value: any): value is DeleteInput {
  return value?.confirmation === 'DELETE' && isUuid(value?.requestId) &&
    (value.appleAuthorizationCode === undefined ||
      (typeof value.appleAuthorizationCode === 'string' && value.appleAuthorizationCode.length > 0))
}

export async function handleDeleteRequest(
  request: Request,
  dependencies: DeleteDependencies,
): Promise<Response> {
  if (request.method !== 'POST') return json({ ok: false, code: 'method_not_allowed' }, 405)
  const token = bearer(request)
  if (!token) return json({ ok: false, code: 'auth_required' }, 401)
  const subject = jwtSubject(token)

  let input: unknown
  try {
    input = await request.json()
  } catch {
    return json({ ok: false, code: 'invalid_request' }, 400)
  }
  if (!validInput(input)) return json({ ok: false, code: 'delete_confirmation_required' }, 400)

  const user = await dependencies.authenticate(token)
  if (!user) {
    if (subject && !await dependencies.profileExists(subject)) {
      return json({ ok: true, deleted: true, replayed: true })
    }
    return json({ ok: false, code: 'auth_required' }, 401)
  }

  const providers = new Set(user.identities?.map((identity) => identity.provider))
  if (!providers.has('apple') && !providers.has('google')) {
    return json({ ok: false, code: 'identity_not_approved' }, 403)
  }
  const signedInAt = Date.parse(user.last_sign_in_at ?? '')
  const age = dependencies.now() - signedInAt
  if (!Number.isFinite(signedInAt) || age < -60_000 || age > 5 * 60_000) {
    return json({ ok: false, code: 'fresh_reauthentication_required' }, 401)
  }
  if (!dependencies.allow(user.id)) return json({ ok: false, code: 'rate_limited' }, 429)

  let providerRevoked = true
  if (providers.has('apple')) {
    if (!input.appleAuthorizationCode) {
      return json({ ok: false, code: 'apple_reauthentication_required' }, 400)
    }
    providerRevoked = await dependencies.revokeApple(input.appleAuthorizationCode)
  }

  const deleted = await dependencies.deleteUser(user.id)
  if (!deleted) {
    console.info(JSON.stringify({
      event: 'account_delete',
      outcome: 'auth_delete_failed',
      request_id: input.requestId,
      provider_revoked: providerRevoked,
    }))
    return json({ ok: false, code: 'delete_unavailable' }, 502)
  }

  if (await dependencies.profileExists(user.id)) {
    console.info(JSON.stringify({
      event: 'account_delete',
      outcome: 'cascade_incomplete',
      request_id: input.requestId,
      provider_revoked: providerRevoked,
    }))
    return json({ ok: false, code: 'delete_incomplete' }, 500)
  }

  console.info(JSON.stringify({
    event: 'account_delete',
    outcome: 'deleted',
    request_id: input.requestId,
    provider_revoked: providerRevoked,
  }))
  return json({
    ok: true,
    deleted: true,
    replayed: false,
    providerRevocation: providerRevoked ? 'completed' : 'attempted',
  })
}
