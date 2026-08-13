# Wander Wonders V1 local release report

Date: 2026-08-13
Branch: `codex/wander-v1-end-to-end`

## Verified current

- Content contract: 13 active species, 12 Autumn offers, 5 shop items, 50 declared asset sets.
- Database: clean resets; 139/139 pgTAP; lint 0; cap/telemetry/concurrency/timeouts probes passed before the iOS-only work.
- Edge: fmt, lint, type check, and 13/13 tests passed.
- Final code-only runner: Debug and Release builds passed; 13/13 focused iOS unit tests and 1/1 branded Autumn UI smoke passed.
- Privacy manifest and entitlements are valid plists; secret and out-of-scope scans passed.
- Asset contract validation passes for 50 declared sets; file validation cleanly reports all 50 production PNGs missing.

## Deliberately not claimed

- The 50 production PNG assets do not exist, so file validation and archive/release preflight are blocked.
- Final bundle/team/App Store record, provider IDs/secrets, public privacy/support URLs, signing, and review metadata are owner inputs.
- No remote Supabase mutation, provider configuration, Edge deployment, physical-device acceptance, TestFlight upload, soak, review, or beta invite has occurred.

Run `Scripts/run_wonder_checks.sh --code-only` for code checks. The default full mode additionally requires the local database and fails closed on missing production art or archive gates.
