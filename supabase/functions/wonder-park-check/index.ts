import { getUser, RateLimiter, secretRpc, supabaseConfig, userRpc } from '../_shared/wonder.ts'
import { handleParkRequest, hasNearbyPark, type ParkDependencies } from './handler.ts'
const limiter = new RateLimiter()

function dependencies(): ParkDependencies {
  const config = supabaseConfig()
  const googleKey = Deno.env.get('GOOGLE_PLACES_API_KEY')
  if (!googleKey) throw new Error('missing GOOGLE_PLACES_API_KEY')

  return {
    authenticate: (token) => getUser(config.url, config.publishableKey, token),
    authorize: async (user, token) => {
      const identity = user.identities?.find((item) =>
        item.provider === 'apple' || item.provider === 'google'
      )
      const providerId = identity?.id
      if (!identity?.provider || !providerId) return false
      const result = await userRpc(
        config.url,
        config.publishableKey,
        token,
        'wonder_auth_gate',
        {
          p_provider: identity.provider,
          p_provider_identity_id: providerId,
        },
      )
      return result.ok && result.body?.ok === true && result.body?.approved === true
    },
    allow: (userId) => limiter.allow(userId, 5, 60_000),
    nearby: (input) => hasNearbyPark(input, googleKey),
    start: async (userId, input) => {
      const result = await secretRpc(
        config.url,
        config.secretKey,
        'wonder_start_verified_wander_internal',
        {
          p_user_id: userId,
          p_session_id: input.sessionId,
          p_time_zone: input.timeZone,
          p_expected_revision: input.expectedRevision,
          p_idempotency_key: input.idempotencyKey,
          p_allow_zero_reward: input.allowZeroReward ?? false,
        },
      )
      return { ok: result.ok && result.body?.ok === true, body: result.body }
    },
  }
}

Deno.serve((request) => handleParkRequest(request, dependencies()))
