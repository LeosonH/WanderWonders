import { revokeAppleAuthorization } from '../_shared/apple.ts'
import { getUser, profileExists, RateLimiter, supabaseConfig } from '../_shared/wonder.ts'
import { type DeleteDependencies, handleDeleteRequest } from './handler.ts'

const limiter = new RateLimiter()

function dependencies(): DeleteDependencies {
  const config = supabaseConfig()
  return {
    authenticate: (token) => getUser(config.url, config.publishableKey, token),
    profileExists: (userId) => profileExists(config.url, config.secretKey, userId),
    allow: (userId) => limiter.allow(userId, 3, 10 * 60_000),
    now: () => Date.now(),
    revokeApple: (code) =>
      revokeAppleAuthorization(code, {
        clientId: Deno.env.get('APPLE_CLIENT_ID') ?? '',
        teamId: Deno.env.get('APPLE_TEAM_ID') ?? '',
        keyId: Deno.env.get('APPLE_KEY_ID') ?? '',
        privateKeyP8: Deno.env.get('APPLE_PRIVATE_KEY_P8') ?? '',
      }),
    deleteUser: async (userId) => {
      const response = await fetch(
        `${config.url}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
        {
          method: 'DELETE',
          headers: { apikey: config.secretKey },
          signal: AbortSignal.timeout(5_000),
        },
      )
      return response.ok || response.status === 404
    },
  }
}

Deno.serve((request) => handleDeleteRequest(request, dependencies()))
