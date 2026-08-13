import type { Fetcher } from './wonder.ts'

export interface AppleConfig {
  clientId: string
  teamId: string
  keyId: string
  privateKeyP8: string
}

function base64url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '')
}

function pkcs8Bytes(pem: string): Uint8Array {
  const base64 = pem.replaceAll('\\n', '\n')
    .replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '')
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0))
}

export async function appleClientSecret(
  config: AppleConfig,
  nowSeconds = Math.floor(Date.now() / 1_000),
): Promise<string> {
  const header = base64url(JSON.stringify({ alg: 'ES256', kid: config.keyId }))
  const claims = base64url(JSON.stringify({
    iss: config.teamId,
    iat: nowSeconds,
    exp: nowSeconds + 300,
    aud: 'https://appleid.apple.com',
    sub: config.clientId,
  }))
  const input = `${header}.${claims}`
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pkcs8Bytes(config.privateKeyP8).buffer as ArrayBuffer,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: 'ECDSA', hash: 'SHA-256' },
      key,
      new TextEncoder().encode(input),
    ),
  )
  return `${input}.${base64url(signature)}`
}

async function applePost(
  url: string,
  form: URLSearchParams,
  fetcher: Fetcher,
): Promise<Response> {
  return await fetcher(url, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: form,
    signal: AbortSignal.timeout(5_000),
  })
}

export async function revokeAppleAuthorization(
  code: string,
  config: AppleConfig,
  fetcher: Fetcher = fetch,
): Promise<boolean> {
  const clientSecret = await appleClientSecret(config)
  let exchange: Response
  try {
    exchange = await applePost(
      'https://appleid.apple.com/auth/token',
      new URLSearchParams({
        client_id: config.clientId,
        client_secret: clientSecret,
        code,
        grant_type: 'authorization_code',
      }),
      fetcher,
    )
  } catch {
    return false
  }
  if (!exchange.ok) return false
  const refreshToken = (await exchange.json())?.refresh_token
  if (typeof refreshToken !== 'string' || !refreshToken) return false

  const revokeForm = new URLSearchParams({
    client_id: config.clientId,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: 'refresh_token',
  })
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const response = await applePost(
        'https://appleid.apple.com/auth/revoke',
        revokeForm,
        fetcher,
      )
      if (response.ok) return true
      if (response.status !== 429 && response.status < 500) return false
    } catch {
      if (attempt === 1) return false
    }
  }
  return false
}
