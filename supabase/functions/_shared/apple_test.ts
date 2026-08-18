import { type AppleConfig, appleMapsAccessToken, revokeAppleAuthorization } from './apple.ts'

function base64(data: Uint8Array): string {
  let binary = ''
  for (const byte of data) binary += String.fromCharCode(byte)
  return btoa(binary).match(/.{1,64}/g)?.join('\n') ?? ''
}

async function config(): Promise<AppleConfig> {
  const key = await crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  )
  const bytes = new Uint8Array(await crypto.subtle.exportKey('pkcs8', key.privateKey))
  return {
    clientId: 'com.example.wanderwonders',
    teamId: 'TEAM123456',
    keyId: 'KEY1234567',
    privateKeyP8: `-----BEGIN PRIVATE KEY-----\n${base64(bytes)}\n-----END PRIVATE KEY-----`,
  }
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) throw new Error(`expected ${expected}, got ${actual}`)
}

Deno.test('Apple revoke retries one transient revoke failure', async () => {
  let calls = 0
  const fetcher: typeof fetch = (_input, _init) => {
    calls++
    if (calls === 1) return Promise.resolve(Response.json({ refresh_token: 'refresh' }))
    if (calls === 2) return Promise.resolve(new Response('', { status: 500 }))
    return Promise.resolve(new Response('', { status: 200 }))
  }
  assertEquals(await revokeAppleAuthorization('code', await config(), fetcher), true)
  assertEquals(calls, 3)
})

Deno.test('Apple exchange and non-retryable revoke failures stop safely', async () => {
  let calls = 0
  const exchangeFailure: typeof fetch = () => {
    calls++
    return Promise.resolve(new Response('', { status: 400 }))
  }
  assertEquals(await revokeAppleAuthorization('code', await config(), exchangeFailure), false)
  assertEquals(calls, 1)

  calls = 0
  const revokeFailure: typeof fetch = () => {
    calls++
    return Promise.resolve(
      calls === 1 ? Response.json({ refresh_token: 'refresh' }) : new Response('', { status: 400 }),
    )
  }
  assertEquals(await revokeAppleAuthorization('code', await config(), revokeFailure), false)
  assertEquals(calls, 2)
})

Deno.test('Apple Maps token uses the server-only scope', async () => {
  let captured = ''
  const fetcher: typeof fetch = (_input, init) => {
    captured = (init?.headers as Record<string, string>).authorization.slice(7)
    return Promise.resolve(Response.json({ accessToken: 'maps-access-token' }))
  }
  const apple = await config()
  assertEquals(
    await appleMapsAccessToken(apple, fetcher, 1_800_000_000),
    'maps-access-token',
  )
  const [header, claims] = captured.split('.').slice(0, 2).map((part) => {
    const normalized = part.replaceAll('-', '+').replaceAll('_', '/')
    return JSON.parse(atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=')))
  })
  assertEquals(header.alg, 'ES256')
  assertEquals(header.kid, apple.keyId)
  assertEquals(header.typ, 'JWT')
  assertEquals(claims.iss, apple.teamId)
  assertEquals(claims.iat, 1_800_000_000)
  assertEquals(claims.exp, 1_800_000_300)
  assertEquals(claims.scope, 'server_api')
})
