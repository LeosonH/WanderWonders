# Wander Wonders V1 owner inputs

Status: production art, Supabase deployment, Apple Maps, Apple Auth, App ID, and App Store/TestFlight records are complete; Google Auth, public-contact, publication, and signed-device actions remain pending.

This file records only nonsecret readiness status. Credentials, authorization codes, private keys, tester email addresses, and provider responses belong in the owner-controlled vault or account surfaces and must never be copied here.

## Account and access checklist

| Input | Safe repository record | Owner status |
|---|---|---|
| Apple Developer Program team and App Store Connect access | Team `ALF5X476P3` | CONFIGURED |
| Final bundle identifier and App ID | `com.judy.wanderwonders`; Sign in with Apple and HealthKit enabled | CONFIGURED |
| App Store Connect app record and internal TestFlight group | App `6802547488`; `Wander Wonders Internal`; automatic distribution enabled | CONFIGURED_NO_BUILD |
| Apple Sign in with Apple credentials | Team `ALF5X476P3`; client ID `com.judy.wanderwonders`; Key `TT8D4RTNUU`; `.p8` remains outside Git | CONFIGURED |
| Apple Maps Server API credentials | Team `ALF5X476P3`; Maps ID `maps.com.judy.wanderwonders`; Key ID `TT8D4RTNUU`; `.p8` remains outside Git | CONFIGURED_AND_PROVIDER_VALIDATED |
| Google Cloud/OAuth configuration | Project `wander-wonders-v1-2026`; consent setup awaits owner policy acceptance; iOS/Web OAuth clients remain uncreated; Places is unused | PARTIAL_OWNER_ACTION |
| Dedicated Supabase project | `qmsliloouxmybnfzzlks` in dedicated Org `ilwcbtpsthckxclqqipz` | DEPLOYED_AND_AUDITED |
| Supabase publishable and server secret keys | App publishable configuration validated locally; server keys remain hosted only | CONFIGURED_NO_SECRET_IN_GIT |
| Privacy Policy and Support URLs | Final public URLs only after signed-out HTTP verification | PENDING_OWNER_ACTION |
| Feedback/review contact | Monitored contact status only; no email address in this repository | PENDING_OWNER_ACTION |
| External beta cohort | Count/policy only; tester emails remain in App Store Connect or the owner vault | PENDING_OWNER_ACTION |

## Art gate checklist

- [x] Named accountable art owner: Judy — Product Owner / Final Art Approver
- [x] Approved internal AI-assisted creator workflow
- [x] Approved budget: USD 0 additional project spend; existing software subscriptions excluded
- [x] Rights/ownership confirmed by the owner for project and release use on 2026-08-13
- [x] Two review rounds and final delivery accepted on 2026-08-13
- [x] 50-asset manifest approved on 2026-08-13

## Step 0 exit blockers

The remaining readiness gate cannot close until the owner accepts Google's user-data policy and finishes Google Auth, supplies the review phone/contact, approves public Privacy Policy and Support publication, refreshes the local Apple Development/Distribution signing certificates, and confirms remaining review metadata. Art, Apple Maps, Apple Auth, App ID/bundle, dedicated Supabase deployment, App Store record, internal TestFlight group, and local signing configuration are complete.
