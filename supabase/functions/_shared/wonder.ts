export type Fetcher = typeof fetch

export interface AuthIdentity {
  id?: string
  identity_id?: string
  provider?: string
}

export interface AuthUser {
  id: string
  last_sign_in_at?: string
  identities?: AuthIdentity[]
}

export function json(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: { 'cache-control': 'no-store' },
  })
}

export function bearer(request: Request): string | null {
  const value = request.headers.get('authorization')
  return value?.startsWith('Bearer ') ? value.slice(7) : null
}

export function jwtSubject(token: string | null): string | null {
  if (!token) return null
  try {
    const part = token.split('.')[1]
    if (!part) return null
    const normalized = part.replaceAll('-', '+').replaceAll('_', '/')
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=')
    const payload = JSON.parse(atob(padded))
    return typeof payload.sub === 'string' ? payload.sub : null
  } catch {
    return null
  }
}

function namedKey(pluralName: string, singleName: string): string {
  const plural = Deno.env.get(pluralName)
  if (plural) {
    const value = JSON.parse(plural)?.default
    if (typeof value === 'string' && value) return value
  }
  const single = Deno.env.get(singleName)
  if (!single) throw new Error(`missing ${pluralName}/${singleName}`)
  return single
}

export function supabaseConfig() {
  const url = Deno.env.get('SUPABASE_URL')
  if (!url) throw new Error('missing SUPABASE_URL')
  return {
    url,
    publishableKey: namedKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_PUBLISHABLE_KEY'),
    secretKey: namedKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SECRET_KEY'),
  }
}

export async function getUser(
  url: string,
  publishableKey: string,
  token: string,
  fetcher: Fetcher = fetch,
): Promise<AuthUser | null> {
  const response = await fetcher(`${url}/auth/v1/user`, {
    headers: {
      apikey: publishableKey,
      authorization: `Bearer ${token}`,
    },
    signal: AbortSignal.timeout(5_000),
  })
  if (!response.ok) return null
  const user = await response.json()
  return typeof user?.id === 'string' ? user as AuthUser : null
}

export async function userRpc(
  url: string,
  publishableKey: string,
  token: string,
  name: string,
  body: unknown,
  fetcher: Fetcher = fetch,
): Promise<{ ok: boolean; status: number; body: any }> {
  const response = await fetcher(`${url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: publishableKey,
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(5_000),
  })
  return { ok: response.ok, status: response.status, body: await response.json() }
}

export async function secretRpc(
  url: string,
  secretKey: string,
  name: string,
  body: unknown,
  fetcher: Fetcher = fetch,
): Promise<{ ok: boolean; status: number; body: any }> {
  const response = await fetcher(`${url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: secretKey,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(5_000),
  })
  return { ok: response.ok, status: response.status, body: await response.json() }
}

export async function profileExists(
  url: string,
  secretKey: string,
  userId: string,
  fetcher: Fetcher = fetch,
): Promise<boolean> {
  const response = await fetcher(
    `${url}/rest/v1/wonder_profiles?user_id=eq.${encodeURIComponent(userId)}&select=user_id`,
    {
      headers: { apikey: secretKey },
      signal: AbortSignal.timeout(5_000),
    },
  )
  if (!response.ok) throw new Error(`profile check failed: ${response.status}`)
  const rows = await response.json()
  return Array.isArray(rows) && rows.length > 0
}

export class RateLimiter {
  // ponytail: isolate-local cap; move to a shared store only if distributed abuse is observed.
  readonly #events = new Map<string, number[]>()

  allow(key: string, limit: number, windowMs: number, now = Date.now()): boolean {
    const recent = (this.#events.get(key) ?? []).filter((value) => value > now - windowMs)
    if (recent.length >= limit) {
      this.#events.set(key, recent)
      return false
    }
    recent.push(now)
    this.#events.set(key, recent)
    return true
  }
}

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
}
