# Wander Wonders V1 TestFlight metadata readiness

Status: App Store record, internal group, beta description, and feedback address are configured; URLs, complete review contact, build-specific test copy, and owner approval remain pending.

## Required owner inputs

- [x] App name `Wander Wonders`, bundle `com.judy.wanderwonders`, and App Store Connect app `6802547488`
- [x] Internal group `Wander Wonders Internal` with automatic distribution
- [ ] Review contact and monitored feedback contact
- [ ] Public Privacy Policy URL
- [ ] Public Support URL
- [x] Beta App Description saved in App Store Connect
- [ ] “What to Test” copy
- [ ] Review account/instructions if the implemented flow requires gated access
- [ ] External adult cohort policy or owner-managed tester list

## Copy constraints

- Describe the fixed Autumn flower collection loop only.
- Explain location-assisted/manual/fallback/offline Wander behavior accurately.
- Explain HealthKit, Motion, identity, notifications, and account deletion from the implemented data map.
- Do not claim payments, StoreKit, social features, cloud photo upload, or other excluded scope.
- Do not place tester emails, tokens, precise location, routes, place names, or raw Health values in this repository.

Current external state: 0 builds and 0 testers. No App Review submission or beta invitation is authorized by this file.

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
