# Wander Wonders V1 local release report

Date: 2026-08-13
Branch: `codex/wander-v1-end-to-end`

Remote status moved forward on 2026-08-17; see `docs/evidence/remote-release-report.md`. The evidence below remains the local release baseline.

## 2026-08-17 configured-client regression

- The app's prior generated Info.plist omitted custom `WW*` runtime fields even though Xcode build settings contained them. The XcodeGen source now generates an explicit Info.plist, and the ignored local secret overlay is embedded into both Debug and Release builds.
- The UI smoke previously exercised the configuration-error brand surface. It now proves the configured signed-out Auth surface and rejects the old configuration-error copy.
- The unified code-only gate passed: content contract, Edge fmt/lint/check and 13/13 tests, Debug/Release builds, 15/15 iOS unit tests, and 1/1 configured Auth UI smoke. A separate production-art check confirmed `filesChecked=true` for all 50 sets.

## Verified current

- Content contract: 13 active species, 12 Autumn offers, 5 shop items, 50 declared asset sets.
- Database: two clean resets; 139/139 pgTAP each; lint 0; cap/telemetry/concurrency/timeouts probes passed in both final full runs.
- Edge: fmt, lint, type check, and 13/13 tests passed.
- iOS: Debug and Release builds passed; 15/15 unit tests and 1/1 branded Autumn UI smoke passed in both final full runs.
- Privacy manifest and entitlements are valid plists; secret and out-of-scope scans passed.
- Owner-approved production art: all 50 declared PNGs exist, pass filename/dimensions/alpha/color-space/state-distinction/manifest checks, load from the app bundle, and are wired into the product surfaces and App Icon.
- Two independent full runs from a stopped local stack passed clean reset, 139/139 pgTAP, lint 0, schema/security audit, concurrency/adversarial/timeout probes, iOS tests, UI smoke, and unsigned archive.

## Deliberately not claimed

- Final bundle/team/App Store record, provider IDs/secrets, public privacy/support URLs, signing, and review metadata are owner inputs.
- Remote Supabase deployment and audit are now recorded separately. Provider completion, physical-device acceptance, TestFlight upload, soak, review, and beta invitation have not occurred.

Run `Scripts/run_wonder_checks.sh --code-only` for code checks. The default full mode additionally verifies the local database, all 50 production assets, and an unsigned archive.
