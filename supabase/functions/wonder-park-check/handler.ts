import { type AuthUser, bearer, type Fetcher, isUuid, json } from '../_shared/wonder.ts'

export const acceptedPoiCategories = ['Park', 'NationalPark', 'Hiking']

export interface ParkInput {
  latitude: number
  longitude: number
  accuracyMeters: number
  sessionId: string
  timeZone: string
  expectedRevision: number
  idempotencyKey: string
  allowZeroReward?: boolean
}

export interface ParkDependencies {
  authenticate(token: string): Promise<AuthUser | null>
  authorize(user: AuthUser, token: string): Promise<boolean>
  nearby(input: ParkInput): Promise<boolean>
  start(userId: string, input: ParkInput): Promise<{ ok: boolean; body: unknown }>
  allow(userId: string): boolean
}

export async function hasNearbyPark(
  input: Pick<ParkInput, 'latitude' | 'longitude'>,
  accessToken: string,
  fetcher: Fetcher = fetch,
): Promise<boolean> {
  const query = new URLSearchParams({
    q: 'park',
    includePoiCategories: acceptedPoiCategories.join(','),
    resultTypeFilter: 'Poi',
    searchLocation: `${input.latitude},${input.longitude}`,
  })
  const response = await fetcher(`https://maps-api.apple.com/v1/search?${query}`, {
    headers: {
      authorization: `Bearer ${accessToken}`,
    },
    signal: AbortSignal.timeout(8_000),
  })
  if (!response.ok) throw new Error(`maps search status ${response.status}`)
  const body = await response.json()
  return Array.isArray(body?.results) &&
    body.results.some((place: any) =>
      Number.isFinite(place?.coordinate?.latitude) &&
      Number.isFinite(place?.coordinate?.longitude) &&
      distanceMeters(input, place.coordinate) <= 805
    )
}

function distanceMeters(
  first: Pick<ParkInput, 'latitude' | 'longitude'>,
  second: { latitude: number; longitude: number },
): number {
  const radians = Math.PI / 180
  const latitudeDelta = (second.latitude - first.latitude) * radians
  const longitudeDelta = (second.longitude - first.longitude) * radians
  const value = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(first.latitude * radians) * Math.cos(second.latitude * radians) *
      Math.sin(longitudeDelta / 2) ** 2
  return 2 * 6_371_000 * Math.asin(Math.min(1, Math.sqrt(value)))
}

function validInput(value: any): value is ParkInput {
  return Number.isFinite(value?.latitude) && value.latitude >= -90 && value.latitude <= 90 &&
    Number.isFinite(value?.longitude) && value.longitude >= -180 && value.longitude <= 180 &&
    Number.isFinite(value?.accuracyMeters) && value.accuracyMeters >= 0 &&
    value.accuracyMeters <= 200 && isUuid(value?.sessionId) &&
    typeof value?.timeZone === 'string' && value.timeZone.length > 0 &&
    Number.isSafeInteger(value?.expectedRevision) && value.expectedRevision >= 0 &&
    isUuid(value?.idempotencyKey) &&
    (value.allowZeroReward === undefined || typeof value.allowZeroReward === 'boolean')
}

export async function handleParkRequest(
  request: Request,
  dependencies: ParkDependencies,
): Promise<Response> {
  if (request.method !== 'POST') return json({ ok: false, code: 'method_not_allowed' }, 405)
  const token = bearer(request)
  if (!token) return json({ ok: false, code: 'auth_required' }, 401)

  let input: unknown
  try {
    input = await request.json()
  } catch {
    return json({ ok: false, code: 'invalid_request' }, 400)
  }
  if (!validInput(input)) return json({ ok: false, code: 'invalid_request' }, 400)

  const user = await dependencies.authenticate(token)
  if (!user) return json({ ok: false, code: 'auth_required' }, 401)
  if (!await dependencies.authorize(user, token)) {
    return json({ ok: false, code: 'identity_not_approved' }, 403)
  }
  if (!dependencies.allow(user.id)) return json({ ok: false, code: 'rate_limited' }, 429)

  let eligible: boolean
  try {
    eligible = await dependencies.nearby(input)
  } catch {
    console.info(JSON.stringify({
      event: 'park_check',
      outcome: 'provider_unavailable',
      request_id: input.idempotencyKey,
    }))
    return json({ ok: false, code: 'park_check_unavailable' }, 503)
  }

  if (!eligible) {
    console.info(JSON.stringify({
      event: 'park_check',
      outcome: 'not_eligible',
      request_id: input.idempotencyKey,
    }))
    return json({ ok: true, eligible: false, reason: 'no_supported_park' })
  }

  const start = await dependencies.start(user.id, input)
  console.info(JSON.stringify({
    event: 'park_check',
    outcome: start.ok ? 'started' : 'start_rejected',
    request_id: input.idempotencyKey,
  }))
  if (!start.ok) return json({ ok: false, code: 'start_rejected', result: start.body }, 409)
  return json({ ok: true, eligible: true, result: start.body })
}
