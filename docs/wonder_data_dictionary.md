# Wander Wonders V1 data dictionary

Step 3 defines exactly 22 application-owned tables in `public`. Every table uses the `wonder_` prefix. No table is granted directly to `anon` or `authenticated`; the reviewed RPC surface added in Step 4 is the only client data path.

| # | Table | Ownership/key role |
|---:|---|---|
| 1 | `wonder_profiles` | Auth owner, Glow balance, state revision |
| 2 | `wonder_account_identities` | Approved Apple/Google provider identities |
| 3 | `wonder_player_settings` | Time zone, onboarding, step, Hibernate, notification settings |
| 4 | `wonder_app_config` | Seed/admin versioned configuration |
| 5 | `wonder_species` | Versioned Daisy and Autumn catalog rows |
| 6 | `wonder_discoveries` | Owner/species Pressbook discovery state |
| 7 | `wonder_wander_sessions` | Online/offline Wander lifecycle and captured catalog |
| 8 | `wonder_flower_instances` | Authoritative living/pressed/sold flower state |
| 9 | `wonder_flower_events` | Immutable flower lifecycle/economy event log |
| 10 | `wonder_daily_grants` | One online Daisy grant per owner/local date |
| 11 | `wonder_wander_offers` | Immutable persisted three-offer session set |
| 12 | `wonder_wander_rewards` | Durable tier reservation/resolution/rejection state |
| 13 | `wonder_vase_slots` | Owner vase capacities, unlocks, and patterns |
| 14 | `wonder_vase_assignments` | Owner flower-to-vase placement |
| 15 | `wonder_shelf_assignments` | Six-position Pressbook shelf |
| 16 | `wonder_shop_items` | Seeded Glow Shop catalog |
| 17 | `wonder_player_entitlements` | Owner slot/pattern entitlements |
| 18 | `wonder_glow_ledger` | Immutable signed Glow entries and running balance |
| 19 | `wonder_daily_step_credits` | Owner/local-day Health or fallback high-water state |
| 20 | `wonder_hibernate_intervals` | Owner Hibernate intervals and deadline exclusion inputs |
| 21 | `wonder_idempotency_keys` | Owner/request canonical payload and replay response |
| 22 | `wonder_product_events` | Typed allowlisted UI telemetry |

## Security baseline

- All 22 tables have RLS enabled and `FORCE ROW LEVEL SECURITY`.
- `PUBLIC`, `anon`, and `authenticated` have no table privileges.
- Owner references cascade from `auth.users` through `wonder_profiles`; composite owner FKs prevent cross-user child references.
- Ledger, flower-event, offer, and product-event rows reject update/delete through an immutable trigger. Idempotency rows are append/complete records and have no client table privileges.
- Foreign-key leading indexes are explicit and audited with the namespace-safe query in V5 Section 10.8.
- `wonder_private` is not an exposed API schema and its trigger helper has an empty search path.

The migration is intentionally seed-free. Catalog content, prices, and assets are added only by Step 5.
