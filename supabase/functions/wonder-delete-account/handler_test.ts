import { type AuthUser } from '../_shared/wonder.ts'
import { type DeleteDependencies, handleDeleteRequest } from './handler.ts'

const now = Date.parse('2026-08-13T12:00:00Z')
const user: AuthUser = {
  id: '00000000-0000-4000-8000-000000000800',
  last_sign_in_at: '2026-08-13T11:58:00Z',
  identities: [{ provider: 'google' }],
}
const token = 'header.' + btoa(JSON.stringify({ sub: user.id }))
  .replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '') +
  '.signature'
const valid = {
  confirmation: 'DELETE',
  requestId: '00000000-0000-4000-8000-000000000801',
}

function request(body: unknown = valid, method = 'POST') {
  return new Request('http://local/wonder-delete-account', {
    method,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: method === 'POST' ? JSON.stringify(body) : undefined,
  })
}

function dependencies(overrides: Partial<DeleteDependencies> = {}): DeleteDependencies {
  return {
    authenticate: () => Promise.resolve(user),
    profileExists: () => Promise.resolve(false),
    revokeApple: () => Promise.resolve(true),
    deleteUser: () => Promise.resolve(true),
    allow: () => true,
    now: () => now,
    ...overrides,
  }
}

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`)
  }
}

Deno.test('delete requires POST and exact typed confirmation', async () => {
  assertEquals(
    (await handleDeleteRequest(request(undefined, 'DELETE'), dependencies())).status,
    405,
  )
  assertEquals(
    (await handleDeleteRequest(
      request({ ...valid, confirmation: 'delete' }),
      dependencies(),
    )).status,
    400,
  )
})

Deno.test('delete requires fresh supported-provider reauthentication', async () => {
  const stale = { ...user, last_sign_in_at: '2026-08-13T11:00:00Z' }
  assertEquals(
    (await handleDeleteRequest(
      request(),
      dependencies({ authenticate: () => Promise.resolve(stale) }),
    )).status,
    401,
  )
  assertEquals(
    (await handleDeleteRequest(
      request(),
      dependencies({ authenticate: () => Promise.resolve({ ...user, identities: [] }) }),
    )).status,
    403,
  )
})

Deno.test('delete replay succeeds only when the game profile is already gone', async () => {
  const response = await handleDeleteRequest(
    request(),
    dependencies({
      authenticate: () => Promise.resolve(null),
      profileExists: () => Promise.resolve(false),
    }),
  )
  assertEquals(response.status, 200)
  assertEquals((await response.json()).replayed, true)
})

Deno.test('Apple deletion requires an authorization code', async () => {
  const apple = { ...user, identities: [{ provider: 'apple' }] }
  assertEquals(
    (await handleDeleteRequest(
      request(),
      dependencies({ authenticate: () => Promise.resolve(apple) }),
    )).status,
    400,
  )
})

Deno.test('Apple revoke failure does not block Auth deletion', async () => {
  const apple = { ...user, identities: [{ provider: 'apple' }] }
  let deleted = false
  const response = await handleDeleteRequest(
    request({ ...valid, appleAuthorizationCode: 'one-time-code' }),
    dependencies({
      authenticate: () => Promise.resolve(apple),
      revokeApple: () => Promise.resolve(false),
      deleteUser: () => {
        deleted = true
        return Promise.resolve(true)
      },
    }),
  )
  assertEquals(deleted, true)
  assertEquals((await response.json()).providerRevocation, 'attempted')
})

Deno.test('delete reports Auth failure and incomplete cascade', async () => {
  assertEquals(
    (await handleDeleteRequest(
      request(),
      dependencies({ deleteUser: () => Promise.resolve(false) }),
    )).status,
    502,
  )
  assertEquals(
    (await handleDeleteRequest(
      request(),
      dependencies({ profileExists: () => Promise.resolve(true) }),
    )).status,
    500,
  )
})
