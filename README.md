# WanderWonders

A calm walk n' collect game for iPhone. Walk outside, bring home seasonal flowers, arrange them in vases, and preserve them in a permanent Pressbook.

## Features

| Feature | Description |
|---|---|
| Daily Daisy | A free daisy every day just for opening the app |
| Wander | Go for a walk and collect flowers at 10, 20, and 30-minute milestones |
| Living flowers | Flowers stay alive for 1–3 days and must be displayed or pressed before they fade |
| Vases | Arrange living flowers across up to 3 unlockable vase slots |
| Pocket | Holds unassigned flowers waiting to be placed in a vase |
| Pressbook | Press flowers to preserve them permanently before they expire |
| Glow | In-game currency earned by walking steps, spent in the shop |
| Shop | Buy Sunshine (extends a flower's life) or unlock additional vase slots |
| Live Activity | Active Wanders appear on the Dynamic Island and lock screen with a live timer and milestone chips |
| Offline Wander | Wanders can be completed without a network connection and sync on reconnect |
| Hibernate | Pause flower timers when travelling or taking a break |

## Tech stack

| Layer | Technology |
|---|---|
| iOS app | Swift 6, SwiftUI, SwiftData, ActivityKit |
| Backend | Supabase (PostgreSQL + Edge Functions) |
| Auth | Sign in with Apple, Google Sign-In |
| Project generation | XcodeGen (`project.yml`) |

Deployment target: iOS 17.0. Swift strict concurrency is fully enabled.

## Project structure

```
WanderWonders/          iOS app source
  App/                  Entry point, GameStore (central state), WonderArt helpers
  Core/                 Models, WonderClient (Supabase RPC), WonderPersistence (SwiftData), MutationQueue
  Features/             Screens: Home, Launch, Onboarding, Pocket, Pressbook, Settings, Shop, Wander
WanderWondersShared/    ActivityKit attributes shared between app and widget
WanderWondersWidget/    Widget extension: Live Activity for active Wanders
WanderWondersTests/     Unit tests
WanderWondersUITests/   UI tests
Content/                Bundled assets (flower catalog JSON, offline fixtures, art)
supabase/               Migrations, Edge Functions, local config
Scripts/                Local dev and verification scripts
docs/                   Architecture decisions, privacy map, readiness checklists
```

## First-time setup

1. **Install tools**

   ```bash
   # Xcode 26.6 required
   brew install xcodegen
   ```

2. **Create local configuration**

   ```bash
   cp Config/Debug.xcconfig.example Config/Debug.xcconfig
   ```

   Edit `Config/Debug.xcconfig` and fill in your Supabase URL, publishable key, and Google client IDs. Without credentials the Debug build launches in **demo mode** — a pre-loaded fixture garden with sample flowers, vases, and a pressbook, so all screens are browsable without a backend.

3. **Generate the Xcode project**

   ```bash
   xcodegen generate --spec project.yml
   ```

   Re-run this whenever `project.yml` changes (adding targets, dependencies, etc.).

4. **Open and run**

   ```bash
   open WanderWonders.xcodeproj
   ```

   Select an iPhone 17 simulator and press ⌘R. Or build from the command line:

   ```bash
   WW_DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=latest' Scripts/build_wander.sh
   ```

## Local backend (full flow)

The game requires a Supabase backend to progress past sign-in. A local stack is available:

```bash
npm run wonder:local-start          # starts local Supabase on port 55321
npx supabase status --local         # shows the local anon key
npm run wonder:local-stop           # stops the stack
```

Requires Docker Desktop. See `docs/supabase-local.md` for the full workflow.

## Running tests

```bash
xcodebuild -project WanderWonders.xcodeproj -scheme WanderWonders \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' test
```

Or use `Scripts/build_wander.sh`, which runs both Debug and Release builds followed by the test suite.
