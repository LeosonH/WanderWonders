# Wander Wonders V1 TestFlight metadata readiness

Status: private internal-TestFlight target. App Store record, internal group, beta description, feedback address, and test copy are ready. The signed app is installed on the paired iPhone; build upload, unlock-time acceptance, and the second internal tester remain pending.

## Required owner inputs

- [x] App name `Wander Wonders`, bundle `com.judy.wanderwonders`, and App Store Connect app `6802547488`
- [x] Internal group `Wander Wonders Internal` with automatic distribution
- [x] Monitored feedback contact
- [ ] Full review contact — deferred until external TestFlight is authorized
- [ ] Public Privacy Policy URL — deferred until external TestFlight or App Store release
- [ ] Public Support URL — deferred until external TestFlight or App Store release
- [x] Beta App Description saved in App Store Connect
- [x] “What to Test” copy
- [ ] Review account/instructions if the implemented flow requires gated access
- [ ] Second private internal tester's App Store Connect email

## Copy constraints

- Describe the fixed Autumn flower collection loop only.
- Explain location-assisted/manual/fallback/offline Wander behavior accurately.
- Explain HealthKit, Motion, identity, notifications, and account deletion from the implemented data map.
- Do not claim payments, StoreKit, social features, cloud photo upload, or other excluded scope.
- Do not place tester emails, tokens, precise location, routes, place names, or raw Health values in this repository.

Current App Store Connect state: 0 builds and 0 TestFlight testers. Internal upload/distribution is authorized; external TestFlight review and invitations remain out of scope.

The App Store Connect record exists only to support TestFlight. Public App Store release, sale, payments, and StoreKit remain out of scope.

## Draft Beta App Description

Wander Wonders is a calm Autumn walking and flower-collecting game. Players receive a daily Daisy, start a manual or park-assisted Wander, unlock timed flower rewards, care for and preserve flowers, arrange a vase and Pressbook, and use earned Glow for cosmetic garden items. The beta is free and has no purchases.

## Draft What to Test

1. Sign in with Apple and Google, complete onboarding, and confirm the daily Daisy appears.
2. Start a manual Wander, background or force-quit the app, return after a tier boundary, and resolve a flower reward.
3. With permission granted, try the near-a-park check; with permission denied or no match, confirm manual Wander remains available.
4. Press, sell, apply Sunshine, arrange the vase and Pressbook, and buy a cosmetic item with earned Glow.
5. Try step sync, Hibernate, temporary network loss, sign out/in, and account deletion.

Please report the build number, action, expected result, actual result, and whether the issue repeats. Do not send precise location, Health data, tokens, or account credentials.

## Draft review note

No demo account is required. The reviewer can use Sign in with Apple, deny Location/Health/Motion/Notifications, and still exercise the core manual Wander flow. Account deletion is available in Settings and requires fresh reauthentication.
