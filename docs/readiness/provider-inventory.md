# Wander Wonders V1 provider inventory

Status: dedicated Supabase backend and Edge Functions deployed and audited; Apple Maps and Apple/Google Auth provider completion remain pending.

## Active deployment target — 2026-08-17

The owner replaced the prior target with new project `qmsliloouxmybnfzzlks` (`hackathon`) in dedicated organization `ilwcbtpsthckxclqqipz` (`Wunder wonders`). The project is `ACTIVE_HEALTHY`, Postgres 17.6 in `us-east-2`, and was empty at predeployment audit: zero remote migrations, public objects, Edge Functions, custom Function secrets, and application users/requests. Database advisors returned no issues. Apple and Google Auth providers are disabled; the organization is on Free and scheduled backups are unavailable.

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
| Apple Developer/App Store Connect | PENDING_OWNER_INPUT | Not validated | Team, App ID, bundle ID, app record, and internal group are owner inputs |
| Sign in with Apple | PENDING_OWNER_INPUT | Not validated | Key ID/Team ID/client ID may be recorded after confirmation; `.p8` never enters Git |
| Apple Maps Server API | PENDING_OWNER_INPUT | Code complete; credentials pending | Maps ID/Key ID/Team ID status may be recorded; Maps `.p8` never enters Git |
| Google Cloud | `wander-wonders-v1-2026` | Project created; OAuth incomplete; Places unused | OAuth clients wait for the final bundle ID; no Maps billing action required |
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
