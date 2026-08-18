# Wander Wonders V1 remote deployment report

Date: 2026-08-17
Target: Supabase project `qmsliloouxmybnfzzlks`, organization `ilwcbtpsthckxclqqipz`

## Deployed and verified

- The new project was empty and dedicated before deployment. The prior project `aaajakflsjcwemcxjqhq` was not linked or changed.
- All 10 versioned migrations and `wonder_catalog_v1.sql` were applied.
- Remote catalog counts are 13 species and 5 shop items.
- The schema audit passed: 22 `wonder_*` tables, 24 public RPCs, 22 private helpers, 22/22 tables with enabled and forced RLS, and no direct `PUBLIC`, `anon`, or `authenticated` table grants.
- `authenticated` and `service_role` both have the intended five-second statement timeout.
- `wonder-park-check` is active at version 2 with Apple Maps Server API and JWT verification enabled; `wonder-delete-account` remains active at version 1. Both return HTTP 401 without a JWT.
- Apple Maps Team `ALF5X476P3`, Maps ID `maps.com.judy.wanderwonders`, and Key ID `TT8D4RTNUU` are configured. The three custom Function secrets are present, the downloaded PKCS#8 key passes OpenSSL validation, and the production signing code completed a live Apple Maps access-token request plus Search request with a nearby-park result. No private key or access token entered Git or logs.
- App ID `com.judy.wanderwonders` is registered to Team `ALF5X476P3` with Sign in with Apple and HealthKit. Active Key `TT8D4RTNUU` is enabled for Maps and Sign in with Apple; superseded Key `6S2B527TY9` was revoked.
- Supabase Apple Auth is enabled for native client ID `com.judy.wanderwonders`. The four account-token revocation secrets are present in hosted Edge Function secrets and absent from Git.
- App Store Connect app `6802547488` and internal group `Wander Wonders Internal` exist; automatic distribution is enabled, the beta description/feedback address are saved, and no build or tester is present.
- A rollback-only remote transaction passed bootstrap, manual Wander start, exact three-offer/three-reward creation, idempotent replay, and refresh. No fixture rows were retained.
- Security Advisor has no errors. Its warnings are the reviewed, intentional authenticated `SECURITY DEFINER` RPC allowlist. Performance Advisor reports 0 errors and 0 warnings.
- The temporary pgTAP diagnostic extension and temporary CLI schema usage grant were removed; final remote state has no pgTAP extension and no `cli_login_postgres` usage on `extensions`.

## Recovery and limitations

Predeployment role settings can be restored with:

```sql
alter role authenticated set statement_timeout = '8s';
alter role service_role reset statement_timeout;
notify pgrst, 'reload config';
```

The project is on Supabase Free and has no scheduled backup. It had no application data before deployment, so the Git migrations and seed are the deployment recovery source until the backup policy changes.

The installed CLI's linked Postgres login cannot run `migration list`, remote lint, or remote pgTAP without the database password. The migration ledger was therefore verified through a read-only Management API query; schema and transactional behavior were verified through Management API queries; the unchanged local release gate remains the 139/139 pgTAP and lint-0 evidence.

## Still blocked

- Google Auth remains disabled. Google Cloud project `wander-wonders-v1-2026` is stopped at owner acceptance of Google's user-data policy; its iOS/Web OAuth clients do not exist yet. Google Places is unused, so no Google Maps billing action is required.
- Public privacy/support URLs, complete review contact, a local Team `ALF5X476P3` Apple Development/Distribution certificate, signed device archive, physical acceptance, 24-hour soak, review, and beta invitations remain pending.
