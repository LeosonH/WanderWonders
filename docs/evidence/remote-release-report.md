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
- App Store Connect app `6802547488` and internal group `Wander Wonders Internal` exist; automatic distribution is enabled, and the beta description/feedback address are saved. Internal-only build `1.0 (1)` is Ready to Test, its build-specific What to Test copy is saved, and the owner tester has installed it.
- Xcode automatic signing produced a generic-iPhone Debug app. Independent `codesign --verify --deep --strict` passed; signed entitlements identify Team `ALF5X476P3`, bundle `com.judy.wanderwonders`, Sign in with Apple, and HealthKit.
- Google Cloud project `wander-wonders-v1-2026` has dedicated iOS and Web OAuth clients. Supabase Google Auth stores the Web-first + iOS client list and Web secret, has Skip nonce enabled, and disallows users without email. The public Auth settings endpoint reports both Apple and Google enabled. The signed generic-iPhone app contains the matching iOS/server IDs and reversed iOS URL scheme; the client secret is absent from the app and Git.
- Physical Google sign-in completed successfully: the device stayed running, Supabase created 1 non-anonymous Google identity, 1 profile, 1 daily grant, and 1 living Daily Daisy. A terminate-and-relaunch check created no duplicate profile, grant, or flower and left the app process running, verifying session restore and idempotent bootstrap on the device.
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

- Google External/Testing has 1 authorized OAuth test user. Runtime validation remains pending on the paired physical iPhone. Google Places is unused, so no Google Maps billing action is required.
- A device-targeted signed Debug build passed and installed on the paired iPhone. Programmatic launch reached the device and was denied only because the phone was locked; interactive physical acceptance remains pending.
- Exact Git commit `5ce0e4d` produced Release archive `1.0 (1)` with valid strict code signature, matching bundle ID, exempt-encryption declaration, and retained dSYM. Xcode uploaded it with `testFlightInternalTestingOnly=true`; App Store Connect returned `Upload succeeded` and `EXPORT SUCCEEDED`.
- App Store Connect confirms build `1.0 (1)` is Ready to Test and assigned to `Wander Wonders Internal`; the owner tester status is `Installed 1.0 (1)` on iPhone 16 Pro / iOS 26.5.2. The second private tester is intentionally deferred until the owner supplies the mentor's App Store Connect email.
- Google Auth and force-quit/session restore are verified. TestFlight acceptance and installation identity are now confirmed; remaining application flows still require interactive acceptance.
- Apple sign-in, Location/Apple Maps, Health/Motion, remaining product flows, VoiceOver, clean reinstall, and the 24-hour internal soak remain pending.
- Release scope is private internal TestFlight only. Public privacy/support URLs, complete review contact, external TestFlight App Review, public App Store submission, and sale are outside the current scope.
