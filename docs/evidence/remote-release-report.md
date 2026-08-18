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

- Apple and Google Auth providers remain disabled until their owner-controlled identifiers are final.
- The separate Sign in with Apple credentials required for account-token revocation are not present; Apple Maps credentials are configured independently.
- Google Cloud project `wander-wonders-v1-2026` remains available for Google Auth OAuth only. Google Places is no longer used, so no Google Maps billing action is required.
- Final bundle/team/App Store/TestFlight records, public privacy/support URLs, signed device archive, physical acceptance, 24-hour soak, review, and beta invitations remain pending.
