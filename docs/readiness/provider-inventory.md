# Wander Wonders V1 provider inventory

Status: dedicated Supabase backend and Edge Functions deployed and audited; Apple Maps, Apple Auth, and Google Auth are configured. Google runtime testing awaits at least one Google OAuth test user.

## Active deployment target — 2026-08-17

The owner replaced the prior target with new project `qmsliloouxmybnfzzlks` (`hackathon`) in dedicated organization `ilwcbtpsthckxclqqipz` (`Wunder wonders`). The project is `ACTIVE_HEALTHY`, Postgres 17.6 in `us-east-2`, and was empty at predeployment audit: zero remote migrations, public objects, Edge Functions, custom Function secrets, and application users/requests. Database advisors returned no issues. Apple and Google Auth are enabled. The organization is on Free and scheduled backups are unavailable.

Predeployment role settings and exact rollback:

```sql
alter role authenticated set statement_timeout = '8s';
alter role service_role reset statement_timeout;
notify pgrst, 'reload config';
```

The migration set both roles to five seconds only on this dedicated project. All 10 migrations, catalog seed, and two JWT-protected Edge Functions are deployed. Postdeployment audit and rollback-only business smoke passed; detailed evidence is in `docs/evidence/remote-release-report.md`.

## Read-only Supabase inventory — 2026-08-02

The authorized Supabase CLI project inventory found the intended dedicated project `aaajakflsjcwemcxjqhq` with name `Project Wunder Wonders`, region `us-west-2`, Postgres 17, and platform status `ACTIVE_HEALTHY`. The project was not linked to this checkout, and no remote schema, provider, secret, or data surface was inspected or changed. Owner authorization is still required before any remote mutation.

Secret values are intentionally absent. A secret row may record only `present`, `validated`, owner, vault location label, and rotation/expiry status after the owner verifies it.

| Provider/surface | Nonsecret identifier | Safe status | Owner/vault note |
|---|---|---|---|
| Supabase | `qmsliloouxmybnfzzlks` | Deployed and audited | Modern publishable configuration is local-only; hosted server keys remain outside Git |
| Apple Developer/App Store Connect | Team `ALF5X476P3`; bundle `com.judy.wanderwonders`; app `6802547488`; internal group `Wander Wonders Internal` | CONFIGURED_NO_BUILD | App ID has Sign in with Apple + HealthKit; TestFlight group has automatic distribution and no build/tester yet |
| Sign in with Apple | Team `ALF5X476P3`; client ID `com.judy.wanderwonders`; Key ID `TT8D4RTNUU` | CONFIGURED | Supabase Apple provider enabled; four account-revocation Function secrets present; `.p8` remains outside Git |
| Apple Maps Server API | Team `ALF5X476P3`; Maps ID `maps.com.judy.wanderwonders`; Key ID `TT8D4RTNUU` | CONFIGURED_AND_PROVIDER_VALIDATED | Three hosted Function secrets are present; live token + Search passed; Maps `.p8` remains outside Git |
| Google Cloud | `wander-wonders-v1-2026`; `Wander Wonders iOS`; `Wander Wonders Backend` | CONFIGURED_PENDING_TEST_USER; Places unused | Supabase has Web-first + iOS client IDs, Web secret, and Skip nonce enabled; Google audience is External/Testing with 0 test users; no Maps billing action required |
| Privacy/Support publication | PENDING_OWNER_INPUT | Not verified | URLs must be checked signed out and return the final domain |
| Feedback/review contact | PENDING_OWNER_INPUT | Not verified | Contact is monitored; address is not stored in this file |

## Secret inventory protocol

For each required secret, the owner may later fill the status fields in the vault, not the value here:

```text
status=present|validated
owner=<vault owner label>
vault_location=<vault item label>
expiry_or_rotation=<owner-maintained note>
```

The repository must remain clean of Apple `.p8`, OAuth codes, tokens, private keys, restricted API keys, and raw provider responses.

The superseded Maps Key `6S2B527TY9` had no retained private-key download and was revoked in Apple Developer on 2026-08-17. Active Key `TT8D4RTNUU` is restricted to Maps and Sign in with Apple.
