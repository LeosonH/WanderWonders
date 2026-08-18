# Wander Wonders V1 owner inputs

Status: production art, Supabase deployment, Apple Maps/Auth, Google Auth configuration, App ID, and App Store/TestFlight records are complete. One Google OAuth test user is authorized and the signed app is installed on the paired iPhone; unlock-time acceptance and the second private internal tester remain pending.

This file records only nonsecret readiness status. Credentials, authorization codes, private keys, tester email addresses, and provider responses belong in the owner-controlled vault or account surfaces and must never be copied here.

## Account and access checklist

| Input | Safe repository record | Owner status |
|---|---|---|
| Apple Developer Program team and App Store Connect access | Team `ALF5X476P3` | CONFIGURED |
| Final bundle identifier and App ID | `com.judy.wanderwonders`; Sign in with Apple and HealthKit enabled | CONFIGURED |
| App Store Connect app record and internal TestFlight group | App `6802547488`; `Wander Wonders Internal`; automatic distribution enabled | CONFIGURED_NO_BUILD |
| Apple Sign in with Apple credentials | Team `ALF5X476P3`; client ID `com.judy.wanderwonders`; Key `TT8D4RTNUU`; `.p8` remains outside Git | CONFIGURED |
| Apple Maps Server API credentials | Team `ALF5X476P3`; Maps ID `maps.com.judy.wanderwonders`; Key ID `TT8D4RTNUU`; `.p8` remains outside Git | CONFIGURED_AND_PROVIDER_VALIDATED |
| Google Cloud/OAuth configuration | Project `wander-wonders-v1-2026`; iOS/Web clients created; Supabase Google enabled; External/Testing audience has 1 authorized test user; Places is unused | CONFIGURED_PENDING_DEVICE_TEST |
| Dedicated Supabase project | `qmsliloouxmybnfzzlks` in dedicated Org `ilwcbtpsthckxclqqipz` | DEPLOYED_AND_AUDITED |
| Supabase publishable and server secret keys | App publishable configuration validated locally; server keys remain hosted only | CONFIGURED_NO_SECRET_IN_GIT |
| Privacy Policy and Support URLs | Not required for the locked internal-only TestFlight scope; required before any external beta or App Store release | DEFERRED_EXTERNAL_ONLY |
| Feedback/review contact | Feedback address configured; full review contact is required before any external TestFlight review | CONFIGURED_INTERNAL_ONLY |
| Beta cohort | Private internal group only; tester emails remain in App Store Connect or the owner vault | PENDING_SECOND_INTERNAL_TESTER |

## Art gate checklist

- [x] Named accountable art owner: Judy — Product Owner / Final Art Approver
- [x] Approved internal AI-assisted creator workflow
- [x] Approved budget: USD 0 additional project spend; existing software subscriptions excluded
- [x] Rights/ownership confirmed by the owner for project and release use on 2026-08-13
- [x] Two review rounds and final delivery accepted on 2026-08-13
- [x] 50-asset manifest approved on 2026-08-13

## Remaining release blockers

Step 13 owner/provider/art readiness is complete for the locked private internal-TestFlight scope. A device-targeted signed build passed and installed on the paired iPhone; launch was correctly denied while the phone was locked, so interactive provider/permission acceptance and the second tester's App Store Connect email still gate Step 14 completion. Public Privacy/Support URLs, full review contact, external cohort metadata, and TestFlight App Review remain deferred unless the owner later expands distribution beyond internal testers. No public App Store release is in scope.
