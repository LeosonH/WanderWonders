# Wander Wonders V1 provider inventory

Status: nonsecret inventory opened; no provider was linked or mutated.

## Read-only Supabase inventory — 2026-08-02

The authorized Supabase CLI project inventory found the intended dedicated project `aaajakflsjcwemcxjqhq` with name `Project Wunder Wonders`, region `us-west-2`, Postgres 17, and platform status `ACTIVE_HEALTHY`. The project was not linked to this checkout, and no remote schema, provider, secret, or data surface was inspected or changed. Owner authorization is still required before any remote mutation.

Secret values are intentionally absent. A secret row may record only `present`, `validated`, owner, vault location label, and rotation/expiry status after the owner verifies it.

| Provider/surface | Nonsecret identifier | Safe status | Owner/vault note |
|---|---|---|---|
| Supabase | `aaajakflsjcwemcxjqhq` | Owner confirmation required before any link | Dedicated-project inventory and keys remain owner-controlled |
| Apple Developer/App Store Connect | PENDING_OWNER_INPUT | Not validated | Team, App ID, bundle ID, app record, and internal group are owner inputs |
| Sign in with Apple | PENDING_OWNER_INPUT | Not validated | Key ID/Team ID/client ID may be recorded after confirmation; `.p8` never enters Git |
| Google Cloud | PENDING_OWNER_INPUT | Not validated | Project, OAuth clients, Places (New), billing, and budget alert are owner inputs |
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
