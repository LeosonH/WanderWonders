import { type AuthUser } from '../_shared/wonder.ts'
import {
  acceptedPoiCategories,
  handleParkRequest,
  hasNearbyPark,
  type ParkDependencies,
} from './handler.ts'

const valid = {
  latitude: 37.4,
  longitude: -122.1,
  accuracyMeters: 20,
  sessionId: '00000000-0000-4000-8000-000000000701',
  timeZone: 'America/Los_Angeles',
  expectedRevision: 4,
  idempotencyKey: '00000000-0000-4000-8000-000000000702',
}
const user: AuthUser = { id: '00000000-0000-4000-8000-000000000700' }

function request(body: unknown = valid, method = 'POST') {
  return new Request('http://local/wonder-park-check', {
    method,
    headers: { authorization: 'Bearer token', 'content-type': 'application/json' },
    body: method === 'POST' ? JSON.stringify(body) : undefined,
  })
}

function dependencies(overrides: Partial<ParkDependencies> = {}): ParkDependencies {
  return {
    authenticate: () => Promise.resolve(user),
    authorize: () => Promise.resolve(true),
    nearby: () => Promise.resolve(true),
    start: () => Promise.resolve({ ok: true, body: { ok: true } }),
    allow: () => true,
    ...overrides,
  }
}

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`)
  }
}

Deno.test('park check rejects non-POST and invalid coordinates', async () => {
  assertEquals((await handleParkRequest(request(undefined, 'GET'), dependencies())).status, 405)
  assertEquals(
    (await handleParkRequest(
      request({ ...valid, latitude: 91 }),
      dependencies(),
    )).status,
    400,
  )
})

Deno.test('park check enforces auth, approval, and rate limit', async () => {
  assertEquals(
    (await handleParkRequest(
      request(),
      dependencies({ authenticate: () => Promise.resolve(null) }),
    )).status,
    401,
  )
  assertEquals(
    (await handleParkRequest(
      request(),
      dependencies({ authorize: () => Promise.resolve(false) }),
    )).status,
    403,
  )
  assertEquals(
    (await handleParkRequest(
      request(),
      dependencies({ allow: () => false }),
    )).status,
    429,
  )
})

Deno.test('park check does not start without a supported place', async () => {
  let started = false
  const response = await handleParkRequest(
    request(),
    dependencies({
      nearby: () => Promise.resolve(false),
      start: () => {
        started = true
        return Promise.resolve({ ok: true, body: {} })
      },
    }),
  )
  assertEquals(response.status, 200)
  assertEquals(started, false)
  assertEquals((await response.json()).eligible, false)
})

Deno.test('park check maps provider failure and starts verified Wander once', async () => {
  assertEquals(
    (await handleParkRequest(
      request(),
      dependencies({
        nearby: () => Promise.reject(new Error('timeout')),
      }),
    )).status,
    503,
  )

  let starts = 0
  const response = await handleParkRequest(
    request(),
    dependencies({
      start: () => {
        starts++
        return Promise.resolve({ ok: true, body: { ok: true, state_revision: 5 } })
      },
    }),
  )
  assertEquals(starts, 1)
  assertEquals((await response.json()).eligible, true)
})

Deno.test('Apple Maps search sends the exact privacy-minimal contract', async () => {
  let captured: { url?: string; init?: RequestInit } = {}
  const fetcher: typeof fetch = (input, init) => {
    captured = { url: String(input), init }
    return Promise.resolve(Response.json({
      results: [{ coordinate: { latitude: 37.4001, longitude: -122.1 } }],
    }))
  }
  assertEquals(await hasNearbyPark(valid, 'access-token', fetcher), true)
  const url = new URL(captured.url ?? '')
  assertEquals(`${url.origin}${url.pathname}`, 'https://maps-api.apple.com/v1/search')
  assertEquals(url.searchParams.get('q'), 'park')
  assertEquals(url.searchParams.get('includePoiCategories'), acceptedPoiCategories.join(','))
  assertEquals(url.searchParams.get('resultTypeFilter'), 'Poi')
  assertEquals(url.searchParams.get('searchLocation'), `${valid.latitude},${valid.longitude}`)
  assertEquals(
    (captured.init?.headers as Record<string, string>).authorization,
    'Bearer access-token',
  )
})

Deno.test('Apple Maps search rejects results outside 805 meters', async () => {
  const fetcher: typeof fetch = () =>
    Promise.resolve(Response.json({
      results: [{ coordinate: { latitude: 37.42, longitude: -122.1 } }],
    }))
  assertEquals(await hasNearbyPark(valid, 'access-token', fetcher), false)
})
