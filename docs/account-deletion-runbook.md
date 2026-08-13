# Wander Wonders V1 account deletion runbook

1. The player opens Settings → Delete account and types `DELETE`.
2. The app requires a fresh sign-in with the current Apple or Google identity.
3. For Apple, the one-time authorization code is sent directly to `wonder-delete-account`; it is never persisted or logged.
4. The Edge Function attempts Apple token revocation, then deletes the Supabase Auth user even if revocation is unavailable.
5. The database cascade removes all owned `wonder_*` rows; the function verifies the profile is gone.
6. The app clears its SwiftData cache, pending mutations, Supabase session, Google session, and notifications.
7. A lost response can safely replay: an already absent profile returns success.

If deletion is incomplete, keep the local account in deletion quarantine, do not reopen the garden, and prompt the player to reauthenticate and retry. Provider secrets and admin keys remain only in Supabase Edge secrets.
