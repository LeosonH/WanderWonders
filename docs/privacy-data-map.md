# Wander Wonders V1 privacy data map

| Data | Purpose | Location | Retention |
|---|---|---|---|
| Supabase user ID and Apple/Google identity ID | Authentication and account ownership | Supabase Auth + `wonder_account_identities` | Until account deletion |
| Garden state, flowers, Glow, settings, Wander timestamps | Provide the game | Supabase `wonder_*` rows; per-user SwiftData cache | Until account deletion; cache cleared on sign-out/deletion |
| Combined daily step totals | Calculate Glow | Seven-day server summaries and local snapshot | Rolling product need; no raw samples |
| One location fix | Check for a supported park | Edge request memory only | Discarded after response |
| Typed product events | Beta reliability and funnel checks | `wonder_product_events` | Server policy; capped at 200/user/UTC day |

Never retained: email as game identity, raw Health samples, source/device, routes, exact coordinates, park names, Google place records, provider response bodies, OAuth codes, tokens, secrets, or arbitrary analytics payloads.

The App Store privacy answers and public privacy page require owner review before TestFlight external review.

Draft App Store disclosures: linked User ID, Gameplay Content, and Fitness for app functionality; linked Product Interaction for analytics; no tracking. Precise location is transmitted only to service one park check and is discarded with the provider result, so it is not retained as collected data.
