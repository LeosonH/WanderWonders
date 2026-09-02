# WanderWonders

A calm walk n' collect game for iPhone. Walk outside, bring home seasonal flowers, arrange them in vases, and preserve them in a permanent Pressbook.

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

   Edit `Config/Debug.xcconfig` and fill in your Supabase URL, publishable key, and Google client IDs. Without credentials the app builds but stops at the sign-in screen.

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
