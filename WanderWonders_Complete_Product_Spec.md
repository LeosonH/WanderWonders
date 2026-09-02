# Wander Wonders

## Complete Product and Business Specification

**Version:** 2.0  
**Date:** August 1, 2026  
**Status:** V1 product definition; V2 and V3 directional roadmap  
**Source:** Rewritten from `WanderWonders_V1.6_EN.docx` and subsequent product decisions  
**Product owner:** Claudia  
**Initial platform:** iPhone  
**Backend:** Supabase project `aaajakflsjcwemcxjqhq`  

---

## 1. Executive Summary

Wander Wonders is a calm collecting game that gives people a gentle reason to leave a building and walk outside. A player starts a Wander near a park, spends time walking, brings home seasonal digital flowers, arranges living flowers in vases, and eventually preserves them in a permanent Pressbook.

The product is deliberately not a fitness tracker, competitive game, or task system. Walking is the input, but the emotional reward is bringing something beautiful home. The product should feel welcoming after a long workday and forgiving when life becomes busy.

The first release validates one focused behavior:

> Does turning an ordinary outdoor walk into a small collection and home-arranging ritual motivate people to go outside and return to the app?

The release sequence is intentionally staged:

| Release | Purpose | Included |
|---|---|---|
| V1 | Validate the flower loop | Wanders, seasonal flowers, pocket, vases, lifecycle, Pressbook, glow, Hibernate |
| V2 | Add companionship and interoperability | Built-in AI and read-only MCP |
| V3 | Add quiet social connection | Friends by invitation code, visits, likes, preset messages, gifts |

V1 should be tested as a free beta before monetization is introduced. If the core loop works, the recommended public business model is a free core experience supported by optional permanent cosmetic purchases. A V2 AI subscription is only appropriate if AI provides clear ongoing value and creates ongoing operating cost.

---

## 2. Business Opportunity

### 2.1 Customer problem

Many office, remote, and hybrid workers know that going outside would help them reset, but the benefit is delayed and abstract. Fitness products often add targets, streaks, performance pressure, or guilt. Those systems work for some people and repel people who want encouragement without measurement becoming the point.

Wander Wonders turns the decision to go outside into an immediate, visible outcome:

- Start a Wander.
- Spend a few minutes outside.
- Bring home a seasonal flower.
- Decide how to display or preserve it.
- Build a personal collection over time.

### 2.2 Primary customer

**Primary segment:** Adults approximately 25–50 who work indoors for much of the day, including office, remote, and hybrid workers.

**Broader reachable segment:** Adults approximately 20–50 who enjoy cozy games, nature, collecting, journaling, or low-pressure wellness products.

Common characteristics:

- They spend long periods inside or at a desk.
- They want motivation to step outside without adopting a fitness identity.
- They respond to beauty, collecting, and gentle rituals.
- They dislike competitive pressure, streak loss, and aggressive notifications.
- They may have an iPhone, Apple Watch, or another device that contributes steps to Apple Health, but no wearable is required.

### 2.3 Job to be done

> When I have been working inside for too long, give me a calm and enjoyable reason to take a short walk, so that leaving the building feels rewarding rather than like another obligation.

### 2.4 Value proposition

**Functional value:** A real walk produces a visible collectible and currency for decorating a personal home.

**Emotional value:** The player returns with something instead of merely completing exercise.

**Long-term value:** First-discovery dates and pressed flowers turn repeated walks into a personal archive.

### 2.5 Positioning

**Recommended positioning line:**

> A calm reason to step outside and bring something home.

Supporting promise:

> Did you go outside today? Bring something new home.

### 2.6 What the product is not

- Not a medical or fitness product.
- Not a step-goal or calorie product.
- Not a competitive game.
- Not a farming or production-management simulation.
- Not a location-history or route-tracking service.
- Not an AI-first product in V1.
- Not a social network in V1 or V2.

---

## 3. Product Strategy

### 3.1 First-principles product logic

The product succeeds only if four links remain strong:

1. **Going outside must be easy to start.** Park verification should be approximate and forgiving.
2. **Time outside must produce a clear reward.** The 10-, 20-, and 30-minute ladder provides early and continued payoff.
3. **The reward must create an emotional choice.** Players display, extend, sell, or press individual flowers.
4. **The choice must leave a lasting trace.** Pressed flowers and first-discovery dates accumulate into a personal collection.

If any link becomes too complex, the game turns into inventory administration. If any link becomes meaningless, walking and collecting disconnect from each other.

### 3.2 Product principles

1. **Reward, never punish.** No streak loss, missed-day penalty, or decaying currency.
2. **Outside time is the trigger; beauty is the reward.** Steps support the economy but do not gate collection.
3. **Collection must never be blocked during a walk.** Pocket limits create later curation, not outdoor friction.
4. **Approximate presence is enough.** This is not a competitive or safety-critical location system.
5. **The player controls permanence.** Natural fading and optional early pressing both preserve flowers.
6. **Absence is safe.** Hibernate stops the world without penalizing the player.
7. **V1 stays focused.** AI, MCP, birds, and social features must not obscure validation of the flower loop.
8. **Private by default.** No exact route history, precise collection coordinates, contact upload, or public profile.

### 3.3 What V1 optimizes

- First Wander completion.
- Repeated weekly Wanders.
- Emotional attachment to collected flowers.
- A satisfying daily curation ritual.
- Trust in location, Health, and account permissions.
- A calm experience that can be ignored without consequence.

### 3.4 What V1 intentionally avoids optimizing

- Maximum daily screen time.
- Streak retention.
- Social virality.
- Competitive ranking.
- Ad impressions.
- Artificial scarcity or fear of missing out.
- AI engagement.

---

## 4. Release Roadmap

### 4.1 V1 — Flower Loop

V1 includes:

- Google and Apple account sign-in through Supabase Auth.
- One daily login daisy.
- Start Wander near a recognized park or use a manual fallback.
- Continuous 10-, 20-, and 30-minute reward ladder.
- Seasonal flower offers.
- Pocket as the single inventory for all living flowers.
- Per-flower display, sell, early press, and sunshine actions.
- Natural flower fading and permanent Pressbook preservation.
- Three vase slots with capacities 1, 2, and 3.
- Glow earned from eligible steps and flower sales.
- Apple Health combined step totals when authorized.
- Active-Wander device-step fallback when Health is unavailable.
- Device-time-zone daily boundaries.
- Manual Hibernate.
- Offline-safe Wander completion and later synchronization.
- Server-authoritative economy, rewards, and lifecycle state.

V1 excludes:

- Built-in AI.
- MCP.
- Friends, visits, likes, messages, and gifting.
- Game Center.
- Bird photography and Field Guide.
- Exact park memory, GPS routes, or precise collection coordinates.
- Weather effects.
- AR.
- Free-form home decoration.
- Multiple rooms.
- Push campaigns, streaks, quests, or leaderboards.

### 4.2 V2 — AI and MCP

V2 may add:

- A lightweight built-in AI resident.
- Read-only MCP access using standard HTTP authorization.
- Flower and arrangement observations.
- Collection summaries and seasonal reflections.
- Suggestions based on the player's collection and current season.

V2 must not allow AI or MCP clients to sell flowers, spend glow, press flowers, change vase assignments, or reveal precise location or Health data.

### 4.3 V3 — Social

V3 may add:

- Friend connections through invitation codes.
- Asynchronous home snapshot visits.
- Likes.
- Preset warm messages.
- Sunshine gifts.
- Visitor log.
- Blocking, unfriending, and invitation revocation.

Game Center is not part of the roadmap. Invitation codes are the universal fallback and the primary V3 friend mechanism.

---

## 5. V1 Experience Overview

### 5.1 First-use journey

1. The player sees the positioning promise before any permission request.
2. The player signs in with Google or Apple.
3. The app introduces the Home, Pocket, Wander, and Pressbook in four short screens or contextual steps.
4. Location permission is requested only when the player first taps **Start Wander**.
5. Health permission is requested when the glow benefit is explained, not during the initial launch screen.
6. If either permission is declined, the product remains usable through manual park confirmation and active-Wander step counting.
7. The first daily daisy appears in the Pocket and can be displayed immediately.

### 5.2 Daily loop

1. Open the app and receive today's daisy if eligible.
2. Review the living flowers in the Pocket.
3. Arrange flowers in unlocked vases.
4. Start a Wander near a park or use manual confirmation.
5. Collect one, two, or three seasonal flowers based on Wander duration.
6. Earn glow from eligible steps.
7. Display, sell, press early, or preserve flowers by allowing them to fade naturally.
8. Return later to see the Home and Pressbook grow.

### 5.3 Example session

A player finishes work and walks toward a nearby park. At roughly half a mile from a place Apple Maps identifies as a park, the player taps **Start Wander**. After 10 minutes, the app offers three seasonal flowers. The player chooses one. After another 10 minutes, the two unchosen flowers return and the player chooses a second. At 30 minutes, the final flower is awarded automatically.

At home, the player places one flower in the starter vase. A favorite older flower is close to fading, so the player uses sunshine to keep it alive for another day. The new flower is pressed immediately because the player wants it in the Pressbook now. Another flower remains in the Pocket and will press naturally when its bloom timer ends.

---

## 6. Accounts and Onboarding

### 6.1 Account requirement

An account is required because flowers, glow, vase ownership, daily limits, and Hibernate must survive reinstall and work consistently across supported devices.

### 6.2 Sign-in methods

V1 offers:

- **Continue with Google**
- **Sign in with Apple**

Both methods create or attach to one Supabase Auth user. The game identity is the Supabase authenticated user ID, not an email address or provider-specific ID.

If the same person signs in with different providers that have not been linked, the app must not silently merge accounts. Account linking is an explicit authenticated action.

### 6.3 Collected profile data

Required:

- Authentication provider identifier.
- Email when supplied by the provider.
- Player-created display name, optional in V1 and required only before V3 social use.
- Account creation date.

Not required:

- Contacts.
- Birthday.
- Gender.
- Home address.
- Advertising profile.
- Always-on location.

### 6.4 Account controls

Settings must include:

- Sign out.
- Delete account and associated game data.
- Location permission status and explanation.
- Health permission status and explanation.
- Enter or exit Hibernate.
- Privacy summary.

---

## 7. Home and Navigation

### 7.1 Primary navigation

V1 has four primary destinations:

- **Home** — living flower display and current state.
- **Wander** — eligibility, active timer, reward choices, and daily capacity.
- **Pocket** — all living flowers and per-flower actions.
- **Pressbook** — permanent pressed collection.

Settings and the Glow Shop are secondary destinations.

### 7.2 Home layout

The Home contains:

- Three fixed vase positions: left, center, and right.
- A shelf with preset positions for pressed flowers.
- A visible Pocket entry.
- Current glow balance.
- A Start Wander entry point.
- A quiet seasonal treatment.
- A snowflake charm during Hibernate.

The wall and bird-photo slots from the earlier document are deferred because V1 is flower-only.

### 7.3 Home design goal

The Home is a place to look at, not a dashboard to manage. Step totals, timers, and limits should be available but visually secondary to the flowers.

---

## 8. Pocket

### 8.1 Single source of truth

Every living flower belongs to the Pocket. A vase is only a display assignment.

- Displaying a flower does not move it out of the Pocket.
- Removing a flower from a vase returns it to undisplayed status.
- Rearranging is immediate, free, and reversible.
- Display state does not change bloom duration.
- Each flower exists as a unique instance.

### 8.2 Capacity

- Soft capacity: **12 living flowers**.
- Collection is never blocked by capacity.
- Flowers above 12 remain valid Pocket items.
- The next suitable Home or Pocket visit shows a gentle curation prompt.
- The prompt can be dismissed.

The overflow prompt offers selection shortcuts for selling or early pressing, but every action remains per flower and requires the applicable confirmation.

### 8.3 Flower card

Each flower shows:

- Species name and artwork.
- Source: daily gift or Wander.
- Time remaining while living.
- Current vase assignment, if any.
- First-discovery marker when this is the player's first instance of the species.
- Available actions.

### 8.4 Per-flower actions

| Action | Effect | Rules |
|---|---|---|
| Display | Assigns the flower to an available position in an unlocked vase | Free, immediate, reversible |
| Remove from display | Clears its vase assignment | Flower remains living in Pocket |
| Sell | Converts the living flower to glow | Confirmation required; flower does not enter Pressbook |
| Press now | Ends the living state and adds the flower to Pressbook immediately | Confirmation required; no glow; irreversible |
| Apply sunshine | Extends the flower's bloom by one day | Costs 20 glow; displayed flowers only |

Early pressing remains a normal option on every living flower, not only an overflow action.

---

## 9. Flower Acquisition

### 9.1 Daily login flower

- One daisy is granted on the first eligible app open of each local calendar day.
- The local calendar day uses the device's current IANA time-zone identifier.
- The app records the UTC event time, local date, and time-zone identifier used for the decision.
- A daisy has a default bloom duration of one day.
- Unclaimed daisies do not stack or backfill.
- A daisy is not granted during Hibernate.
- On leaving Hibernate, only the current day's daisy may be granted; missed Hibernate days are not restored.
- The daisy counts toward the total daily acquisition design, but does not reduce the separate six-flower Wander allowance.

### 9.2 Wander flower allowance

- Maximum Wander flowers per local calendar day: **6**.
- This permits two complete 30-minute Wanders or a mix of shorter sessions.
- The app shows remaining capacity before a Wander begins.
- Starting a Wander remains allowed after the flower cap is reached, but the app clearly states that no more flowers can be earned that day.
- V1 has no other Wander drop type after the cap; the session may still be used for active-Wander fallback steps.

### 9.3 Seasonal catalog

- Target: **10–15 Wander flower species per real-world season**.
- Login daisies are separate from the seasonal Wander pool.
- Species availability uses broad seasonal and climate rules, not precise park-level ecology.
- The offer does not claim that a species is physically present at the player's exact location.
- Species records and bloom durations are remotely configurable without changing already-acquired flower deadlines.

### 9.4 First discovery

For each species, V1 remembers only:

- The first discovery date.
- The number of pressed instances.

First discovery occurs when the first instance of that species is acquired. The date remains part of the player's discovery record even if that particular instance is later sold. A species becomes visible in the Pressbook only after an instance is naturally or manually pressed; when that happens, the entry shows the original first-discovery date.

V1 does not remember or display:

- Park name.
- Route.
- Exact coordinates.
- Weather.
- Trip grouping.

The product copy must not imply that V1 can later identify the exact place where a flower was found.

---

## 10. Park Eligibility and Wander Sessions

### 10.1 Product intent

The location check exists to encourage leaving a building and moving toward outdoor green space. It is not an anti-cheat boundary and does not need property-line precision.

### 10.2 Verified start

When the player taps **Start Wander** and grants location access:

1. Obtain the current location for this start attempt.
2. Use Apple Maps Server API Search and accept only results within **0.5 miles, approximately 805 meters**.
3. Accept the start when a nearby result matches an approved park-related place type.
4. Explain the result as **near a park**, not necessarily inside a mapped park boundary.
5. Discard the exact coordinates after completing the eligibility check.

Initial accepted point-of-interest categories:

- `Park`
- `NationalPark`
- `Hiking`

The accepted type list is remotely configurable because provider taxonomies and product judgment may change.

### 10.3 Manual start fallback

If location is unavailable, denied, inaccurate, timed out, or cannot reach the network, show:

> I am walking in or near a park.

The player can confirm and start a manual Wander. Manual sessions grant the same flower rewards and do not display a warning or reduced status.

Because the product is noncompetitive, the design favors inclusion and motivation over strict location enforcement.

### 10.4 Location retention

V1 stores only the verification mode:

- `verified`
- `manual_location_unavailable`
- `manual_permission_denied`
- `manual_network_unavailable`
- `manual_user_choice`

V1 does not store the current coordinates, park name, place result, place ID, or route history in the game database.

### 10.5 Wander lifecycle

- Only one Wander can be active per player.
- The timer starts when the server acknowledges the start or, when offline, when the local session record is created.
- Once a Wander starts, continuous location monitoring is not required.
- The Wander timer advances by elapsed session time, including when the app moves to the background.
- The player can end the Wander at any time.
- The session automatically closes at 60 minutes.
- A session under 10 minutes earns no flowers.
- A session already credited through 30 minutes cannot earn additional flowers by remaining active.

### 10.6 Reward ladder

At **10 minutes**:

- Generate and persist three seasonal species offers.
- The player chooses one flower.
- The two unchosen offers remain attached to the session.

At **20 minutes**:

- Present the two remaining species.
- The player chooses one.
- The last offer remains attached to the session.

At **30 minutes**:

- Award the last remaining flower automatically.
- A complete Wander therefore awards all three offered species, subject to daily capacity.

### 10.7 Background and pending choices

- If the app is open at 10 or 20 minutes, show the applicable choice without forcibly ending the Wander.
- If the app is closed or backgrounded, persist a pending choice and show it the next time the app opens.
- Pending choices never expire merely because the session ended.
- If the player reaches 20 minutes without resolving the 10-minute choice, show the 10-minute choice first and then the 20-minute choice.
- If the player reaches 30 minutes without resolving either choice, show the first and second choices in order; then award the final unchosen flower automatically.
- All awards use idempotent session-threshold records so reopening or retrying cannot duplicate flowers.

### 10.8 Daily-cap behavior

The reward ladder respects the number of Wander flowers remaining for the day:

- Three or more remaining: normal ladder.
- Two remaining: award the 10- and 20-minute choices; the 30-minute tier gives no flower.
- One remaining: award the 10-minute choice only.
- Zero remaining: show the timer but no flower choices.

The session never promises a reward that the remaining daily capacity cannot deliver.

### 10.9 Offline behavior

- A manual Wander can start without network access.
- The local app records start time, end time, thresholds reached, choices, and a unique session ID.
- Earned flower choices remain usable offline from a locally available seasonal catalog.
- The app synchronizes the session and actions when connectivity returns.
- The server accepts each session, threshold, and flower action once.
- Conflicts resolve without deleting a flower the player already saw as earned, unless the same reward is a confirmed duplicate.

---

## 11. Flower Lifecycle

### 11.1 Species-defined duration

Each species has a configurable default bloom duration.

| Flower type | V1 default |
|---|---:|
| Daily daisy | 1 day |
| Wander flower | 3 days |

The duration used at acquisition is copied into the flower's immutable lifecycle calculation. Later catalog changes affect new flowers only.

### 11.2 Timer start

- The bloom timer starts at acquisition.
- Displayed and undisplayed flowers age identically.
- Moving a flower between vases does not change its deadline.
- The server is authoritative for deadlines and remaining time.

### 11.3 Natural pressing

When the bloom deadline reaches zero:

- The flower changes from living to pressed.
- It is removed from its vase assignment.
- It is removed from the living Pocket view.
- It appears permanently in the Pressbook.
- Its terminal reason is recorded as `natural_fade`.

### 11.4 Early pressing

Every living flower has a **Press now** action.

- The confirmation names the species and explains that the living flower will leave the Pocket.
- The action produces no glow.
- The flower enters the Pressbook immediately.
- The action is irreversible.
- Its terminal reason is recorded as `pressed_early`.
- Early-pressed and naturally pressed flowers both count toward the species total.
- The Pressbook may visually distinguish the two reasons later, but V1 does not require a separate collection category.

Early pressing intentionally gives players control over preservation. It weakens the original sell-versus-wait tension, so the product should measure whether players press everything immediately or still enjoy the living lifecycle.

### 11.5 Selling

Selling converts a living flower to glow and permanently forfeits its Pressbook entry.

- Confirmation names the species and sale amount.
- Sale is irreversible.
- A sold flower is retained as an auditable terminal record but is absent from the Pocket and Pressbook.
- Applied sunshine is not refunded.
- Terminal reason is `sold`.

Sale value uses remaining 24-hour blocks:

> Sale value = 5 glow × the greater of 1 or the ceiling of remaining lifetime in days.

Examples:

| Remaining time | Sale value |
|---|---:|
| More than 2 days and up to 3 days | 15 glow |
| More than 1 day and up to 2 days | 10 glow |
| More than 0 and up to 1 day | 5 glow |

This rule is explicit so the displayed value and server result cannot disagree at partial-day boundaries.

### 11.6 Sunshine

- Cost: **20 glow**.
- Effect: add exactly one day to one chosen living flower.
- Eligibility: the flower must currently be displayed.
- Sunshine works on daisies and Wander flowers.
- Multiple applications stack.
- Sunshine is consumed immediately and is not refunded after sale or early pressing.
- Sunshine cannot be applied after the flower has expired.

---

## 12. Vases and Arrangement

### 12.1 Fixed slots

| Slot | Position | Initial state | Capacity |
|---|---|---|---:|
| 1 | Left | Unlocked with starter vase | 1 |
| 2 | Center | Purchased with glow; includes default vase | 2 |
| 3 | Right | Purchased with glow; includes default vase | 3 |

At full progression, the Home displays up to six living flowers.

### 12.2 Rules

- Any living Pocket flower can be assigned to any available vase position.
- A vase may contain mixed species or repeated stems of one species.
- A vase cannot exceed its capacity.
- Assignments are free, immediate, and reversible.
- When a displayed flower is sold, pressed, or naturally fades, the display position becomes available.
- Locked slots appear as quiet placeholders, not blocking prompts.

### 12.3 Design principle

The one-flower starter Home must feel complete. Additional slots expand the creative canvas; they do not repair a deliberately poor free experience.

---

## 13. Pressbook

### 13.1 Purpose

The Pressbook is the permanent record that gives short walks long-term meaning.

### 13.2 V1 organization

- Organized by species.
- Shows species with at least one pressed instance.
- Shows first discovery date.
- Shows total pressed count.
- Includes daily daisies and Wander flowers.
- Includes naturally pressed and early-pressed flowers.
- Excludes sold flowers.

### 13.3 Instance history

V1 may show individual pressed instances by date if the interface remains simple. The minimum required presentation is one species entry with first-discovery date and cumulative pressed count.

### 13.4 Shelf display

- The Home shelf has preset positions.
- A pressed species or instance can be assigned to a shelf position.
- Changing the shelf display never changes Pressbook ownership.
- Removing an item from the shelf returns it to undisplayed Pressbook status.

---

## 14. Glow Economy and Steps

### 14.1 Sources and uses

Glow is a soft currency that never expires.

Earn glow from:

- Eligible steps at **100 steps = 1 glow**.
- Selling living flowers.

Spend glow on:

- Sunshine.
- Vase-slot unlocks.
- Cosmetic vase patterns.

Glow is not purchasable with money in V1. This protects the walking-to-beauty relationship during validation.

### 14.2 Primary step source: Apple Health

When the player authorizes Health access:

- Use Apple Health's combined step-count result rather than adding raw samples independently.
- Eligible sources include iPhone, Apple Watch, and other devices or apps whose steps are available through the player's Health store.
- Count the player's eligible daily Health steps, not only steps taken during an active Wander.
- Import only the aggregate required to calculate glow.
- Do not retain raw Health samples, source-device names, routes, workouts, heart rate, calories, or unrelated health data.
- Health data is used only for the visible glow feature, never for advertising or social ranking.

### 14.3 Health-step crediting

For each local calendar day:

> Health glow earned = floor(eligible Health steps ÷ 100).

The server credits only the increase since the last accepted daily total. Repeated synchronization is idempotent.

- The sub-100 remainder resets with the local day.
- A later reduction in Health's total does not remove glow already granted.
- The system records the daily aggregate, credited glow, local date, time zone, and synchronization time.
- Health synchronization may update glow after steps arrive from another device.

### 14.4 Fallback step source

If Health permission is denied, unavailable, or returns no usable access:

- Count steps only while a Wander is active using the device's motion/pedometer capability.
- Stop fallback counting when the Wander ends.
- Do not count all-day background steps.
- The same rate of 100 steps = 1 glow applies.
- If motion permission is also unavailable, the Wander timer and flower rewards still work, but no step glow is earned.

The app labels the source clearly:

- **Health steps** — combined eligible total across connected Health sources.
- **Wander steps** — steps counted only during active Wanders on this device.
- **Time only** — no step data available; flowers can still be earned.

### 14.5 Avoiding double credit

- A day uses either Health aggregation as the authoritative source or the active-Wander fallback ledger.
- When Health becomes available after fallback steps were already credited, the server credits only any positive difference above the glow already awarded for that day.
- Switching modes never gives less glow than already shown and never duplicates the same day's first step thresholds.

### 14.6 Hibernate and steps

- No glow accrues while Hibernate is active.
- Record the UTC start and end of every Hibernate interval.
- For a local day that overlaps Hibernate, query Health only for the non-Hibernate time intervals and combine those permitted aggregates.
- Store only the resulting eligible aggregate, not the underlying Health samples.
- Steps taken during Hibernate are not credited later.
- Late-arriving Health samples are evaluated by their sample time, so samples inside a recorded Hibernate interval remain excluded even if another device synchronizes them later.
- If the necessary interval calculation cannot be established immediately, step credit remains pending until the calculation can safely exclude the Hibernate interval.

### 14.7 Glow Shop

| Item | Type | V1 cost | Effect |
|---|---|---:|---|
| Sunshine | Consumable | 20 glow | Extends one displayed flower by one day |
| Slot 2 unlock | Permanent | To be tuned in beta | Adds capacity-2 center vase |
| Slot 3 unlock | Permanent | To be tuned in beta | Adds capacity-3 right vase |
| Vase patterns | Permanent cosmetic | To be tuned in beta | Changes vase appearance only |

Pricing target:

- Slot 2 should be reachable after several weeks of casual use.
- Slot 3 should represent a longer-term goal.
- Cosmetic patterns should be attainable without exhausting the utility path.
- Prices must be finalized from beta earning data, not guessed before observing real step and flower-sale behavior.

---

## 15. Seasons, Time, and Hibernate

### 15.1 Seasons

- The current flower pool follows the current real-world season.
- V1 uses a single initial seasonal model appropriate to the launch market, with broader hemisphere handling as a launch-readiness requirement if distributed internationally.
- Changing season affects new offers only.
- Existing living and pressed flowers are unchanged.

### 15.2 Device time zone

- Daily boundaries use the device's current IANA time-zone identifier.
- Store all event timestamps in UTC.
- Also store the local date and time-zone identifier used for daily decisions.
- This applies to daily daisy grants, six-flower Wander limits, step-credit days, and later V3 daily social limits.
- Device time-zone changes are accepted because the product is noncompetitive.
- Server-side uniqueness and idempotency still prevent accidental duplicate processing of the same action.

### 15.3 Hibernate

Hibernate is a manual pause, entered and exited from Settings.

While active:

- Bloom timers freeze.
- Flowers do not fade.
- No daily daisies are granted.
- Wanders cannot start.
- Location is not requested.
- Step glow does not accrue.
- Existing glow can still be spent.
- Vase and shelf arrangements remain editable.
- A snowflake charm appears in the Home.

On return:

- Each living flower resumes with exactly the remaining duration it had at Hibernate entry.
- The available collection pool immediately uses the current real-world season.
- Missed daisies and step glow are not backfilled.
- The current day's daisy can be granted if otherwise eligible.
- The snowflake charm disappears.

The snowflake charm has no inventory, sale, pressing, or economy behavior.

---

## 16. Background, Offline, and Error States

### 16.1 App backgrounded during a Wander

- The elapsed timer continues.
- Thresholds become pending when reached.
- Choice screens appear on the next foreground opportunity.
- A local notification may announce a threshold only if the player has opted in; no notification is required for the reward to remain available.

### 16.2 App terminated during a Wander

- Restore the session from its persisted start and end constraints.
- Reconcile elapsed time with the server when network is available.
- Never create a second active session during restoration.
- Apply the 60-minute maximum.

### 16.3 Network unavailable

- Allow a manual Wander.
- Queue flower rewards and Pocket actions locally.
- Show a quiet **Waiting to sync** state.
- Do not block arranging already-synchronized flowers.
- Resolve repeated requests through idempotency keys.

### 16.4 Location unavailable

- Offer manual confirmation immediately after a short failure, not after repeated retries.
- Explain that exact location is not saved.

### 16.5 Health or motion unavailable

- Explain the current step mode.
- Preserve flower rewards based on time.
- Provide a Settings link to reconsider permission without repeatedly prompting.

### 16.6 Server conflict

The server remains authoritative for balance and ownership. If a local action conflicts:

- Keep the user's action pending while retryable.
- Explain any permanent rejection in plain language.
- Never silently remove a displayed or newly earned flower.
- Provide a refresh/reconcile action when needed.

---

## 17. Content and Experience Standards

### 17.1 Visual direction

- Warm, quiet, illustrated, and tactile.
- Flowers are identifiable without needing text alone.
- Living, fading, and pressed states are distinct but never alarming.
- Locked content appears aspirational rather than disabled or punitive.
- Home decoration uses fixed placements in V1 to control art and layout quality.

### 17.2 Writing tone

- Warm and specific.
- Never scolding.
- No phrases implying failure for missing a day.
- No exaggerated health claims.
- No claim that a generated flower was physically observed at the player's exact location.

### 17.3 Accessibility

- Do not rely on color alone for flower state, selection, or errors.
- Support Dynamic Type where practical.
- Provide VoiceOver labels for species, time remaining, vase position, action, and confirmation consequences.
- Respect Reduce Motion.
- Minimum touch targets follow current platform guidance.
- Flower choices remain available without requiring fast reaction.

### 17.4 Notifications

V1 notifications, if implemented, are optional and informational:

- Wander threshold reached.
- A displayed flower is approaching its natural fade.

No streak, guilt, scarcity, or generic return-engagement notifications.

### 17.5 Live Activity

V1 includes a Live Activity that appears on the lock screen and in the Dynamic Island while a Wander is active. It is the persistent companion to the optional threshold notifications.

The Live Activity shows:

- Elapsed time since the Wander started, counting up automatically.
- A progress bar filling toward the 30-minute reward threshold.
- Three milestone indicators (10 min, 20 min, 30 min) that fill in as each tier is awarded.
- The Wander mode (verified, manual, or offline) is encoded in the data but not prominently displayed; the experience is the same regardless of mode.

Behaviour rules:

- The activity starts when a Wander session begins, including offline Wanders.
- The activity updates automatically when a tier reward is awarded.
- The activity ends with the system's default dismissal delay when the Wander ends normally or syncs.
- The activity is dismissed immediately on discard or sign-out.
- If the app is terminated and relaunched while a Wander is active, the existing activity is reclaimed and updated rather than replaced.
- The activity requires no additional permission beyond the system Live Activities toggle in Settings.
- The activity does not expose precise location, Health data, or exact park information.

The Live Activity timer and progress bar update without requiring app wake-ups, using the platform's built-in timer interval rendering.

---

## 18. Business Model

### 18.1 Recommended rollout

**Private beta / TestFlight:** Free, no purchases.

Purpose:

- Validate motivation and retention.
- Measure step and sale income.
- Tune vase-slot prices.
- Observe early-press behavior.
- Test permission trust and fallback use.

**Public V1:** Free core product plus optional one-time permanent cosmetics.

Potential paid items:

- Cosmetic vase sets.
- Shelf themes.
- Home seasonal visual themes.

Recommended price hypothesis for testing: approximately **$1.99–$4.99** per cosmetic pack, subject to storefront pricing and willingness-to-pay research.

### 18.2 What should remain free

- Starting and completing Wanders.
- All flower species needed for the core collection.
- Pocket and Pressbook.
- Starter vase.
- Earning glow from steps and sales.
- Early pressing.
- Hibernate.
- Location, Health, and manual fallbacks.

### 18.3 V2 AI monetization

A V2 AI subscription may be tested at approximately **$2.99–$4.99 per month** only if it provides recurring, visible value such as personal collection reflections, arrangement help, and ongoing seasonal context.

The subscription must not become necessary for the flower loop. Read-only MCP access can be evaluated separately from built-in hosted AI because its cost and value profile may differ.

### 18.4 Monetization to avoid

- Advertising.
- Paid streak protection.
- Paying to start a Wander.
- Selling required flower species.
- Competitive advantages.
- Paid glow in V1.
- Loot boxes or randomized paid flowers.
- Charging for Health or location functionality supplied by the device.

### 18.5 Cost model

Primary variable or recurring costs:

- Supabase database, Auth, functions, and network usage.
- Apple Maps Server API requests within the included daily quota.
- Artwork and seasonal content production.
- Apple developer and distribution costs.
- V2 AI inference, if launched.

V1 cost controls:

- Make one Apple Maps eligibility search when Start Wander is tapped, not continuous requests during the session.
- Do not query Apple Maps for manual starts.
- Keep provider credentials server-side and discard provider results after the eligibility decision.
- Keep V1 AI-free.
- Store aggregate step and verification data rather than high-volume raw samples or location trails.

Initial infrastructure operating target, excluding labor and art: **no more than $100 per month during beta**, with usage alerts before public growth.

---

## 19. Validation and Metrics

### 19.1 North-star behavior

**Weekly meaningful Wanders:** Number and percentage of users who complete at least one 10-minute Wander in a week.

This measures the behavior the product exists to create without rewarding excessive screen time.

### 19.2 Activation funnel

Measure:

1. Account created.
2. Daily daisy received.
3. Daisy displayed.
4. Start Wander tapped.
5. Wander successfully started by Apple Maps verification or manual mode.
6. First 10-minute threshold reached.
7. First Wander flower chosen.
8. First flower displayed, sold, or pressed.
9. First natural press observed.

### 19.3 Retention and habit metrics

- Wander completion by week.
- Wanders per active user per week.
- Percentage returning for a second Wander within seven days.
- Percentage active in weeks 3 and 4 after activation.
- Median outdoor session duration.
- Percentage using Hibernate and later returning.

### 19.4 Collection and economy metrics

- Flowers acquired by source.
- Choice distribution at each threshold.
- Natural press, early press, and sale rates.
- Time from acquisition to early press.
- Percentage of players who press nearly every flower immediately.
- Vase assignment and rearrangement frequency.
- Sunshine purchase and use rate.
- Glow earned from Health, fallback steps, and sales.
- Time to slot 2 and slot 3 at proposed prices.
- Pocket overflow frequency.

### 19.5 Trust and fallback metrics

- Location permission acceptance.
- Health permission acceptance.
- Apple Maps-verified versus manual Wander starts.
- Reason for manual fallback.
- Health, Wander-step, and time-only session share.
- Offline session synchronization success.

These events must describe product state and mode, not contain exact coordinates, routes, or raw Health samples.

### 19.6 Beta design

Recommended first study:

- 30–50 target users.
- Four to six weeks.
- Mix of office, hybrid, and remote workers.
- Weekly short survey and end-of-study interviews.

Initial success hypotheses, treated as product targets rather than industry benchmarks:

- At least 60% of enrolled testers complete a first 10-minute Wander within 72 hours.
- At least 40% of activated testers complete a Wander in both weeks 3 and 4.
- Active testers complete a median of at least two Wanders per week.
- At least half of activated testers use both display and preservation actions.
- At least 30% say the product helped them leave the building on a day they otherwise might not have.
- Trust or permission confusion is not a top-three reason for abandonment.

The V1 loop advances to broader launch only if behavior and interviews support the central motivation claim.

---

## 20. Privacy, Safety, and Platform Trust

### 20.1 Data-minimization rules

Store:

- Account and game ownership identifiers.
- Flower, vase, Pressbook, glow, and session state.
- UTC timestamps, local dates, and device time-zone identifiers.
- Aggregate daily step totals needed for glow.
- Wander verification mode.
- Product analytics events without precise location or raw Health data.

Do not store:

- GPS routes.
- Exact collection coordinates.
- Park names or Apple Maps place records in V1.
- Raw Health samples.
- Health source-device names.
- Contacts.
- Advertising identifiers tied to Health or location behavior.

### 20.2 Permission timing

- Ask for location only in the context of starting a Wander.
- Ask for Health only after explaining glow.
- Ask for motion only if Health fallback becomes necessary.
- A declined permission always leads to a usable alternative.
- Do not repeatedly prompt after denial.

### 20.3 Walking safety

- The active Wander screen uses large controls and minimal interaction.
- Reward choices can wait until the player stops or reopens the app.
- No flower requires immediate selection.
- Copy reminds players to stay aware of their surroundings where appropriate.
- The app must not encourage trespassing or imply that a mapped place is publicly accessible.

### 20.4 Children

The initial target is adults. V1 should not be marketed as a child-directed product, and V3 social design must be reviewed separately before any broader-age positioning.

---

## 21. Backend and Data Requirements

### 21.1 Architecture boundary

V1 uses the dedicated Supabase project:

`https://aaajakflsjcwemcxjqhq.supabase.co`

The project URL is not a secret. Publishable client credentials may be used by the app as intended, while secret or service-role credentials must exist only in controlled server environments.

The preferred boundary is:

> iOS app → authenticated API/domain operation → Supabase data

The client may read player-owned state through an intentionally exposed API surface. Economy mutations, lifecycle transitions, daily grants, reward awards, and conflict resolution must be server-authoritative domain operations.

### 21.2 Conceptual entities

| Entity | Purpose | Key requirements |
|---|---|---|
| Player profile | App identity and settings | One row per authenticated user; provider-independent |
| Player settings | Time zone, Hibernate, permission-derived mode | No raw Health or location permission payloads |
| Species catalog | Flower content and tuning | Season, climate grouping, bloom duration, active status |
| Flower instance | Unique acquired flower | Owner, source, acquisition time, deadline, state, terminal reason |
| Flower event | Auditable lifecycle/economy action | Acquire, display, remove, sunshine, sell, early press, natural press |
| Daily grant | Daily daisy idempotency | Unique per player and local date |
| Wander session | Session timing and verification | Unique client/server ID, thresholds, max duration, verification mode |
| Wander offer | Three persisted seasonal offers | Stable across backgrounding, reopening, and retry |
| Wander award | Threshold reward idempotency | One accepted outcome per session tier |
| Vase ownership | Unlocked slots and patterns | One active vase per slot; capacity server-validated |
| Shelf assignment | Pressed-flower display | Preset slot and player ownership |
| Glow ledger | Every credit and debit | Immutable entries and resulting balance checks |
| Daily step credit | Aggregate step-to-glow state | Local date, source mode, accepted total, glow already credited |
| Hibernate interval | Frozen-time and step exclusion | Start, end, remaining-duration snapshot or equivalent calculation |
| Product event | Privacy-safe analytics | No raw coordinates or raw Health samples |

### 21.3 Flower state model

Allowed primary states:

- `living`
- `pressed`
- `sold`

Allowed terminal reasons:

- `natural_fade`
- `pressed_early`
- `sold`

Required invariants:

- A living flower belongs to exactly one player.
- A living flower is always in the Pocket even when displayed.
- A flower has at most one vase assignment.
- A pressed or sold flower has no vase assignment.
- A sold flower never appears in the Pressbook.
- A pressed flower remains permanently owned unless the account is deleted.
- A terminal transition occurs once.

### 21.4 Economy invariants

- Glow balance derives from an immutable ledger or equally auditable transaction model.
- Credits and debits cannot be duplicated on retry.
- The server calculates sale value and Health-step deltas.
- The client cannot submit an authoritative price, balance, bloom deadline, or daily count.
- A glow debit and the purchased result commit together.
- Daily rewards and session thresholds use unique idempotency constraints.

### 21.5 Authorization and database security

- Every player-owned row is tied to the authenticated Supabase user ID.
- All tables reachable through the Data API require explicit grants and Row Level Security.
- Player policies restrict reads and permitted writes to owned rows.
- Authentication alone is not authorization; ownership predicates are required.
- Internal tables and privileged operations should remain in non-exposed schemas where practical.
- Views exposed to clients must preserve caller permissions.
- Secret and service-role keys are never shipped in the app.
- Privileged functions are not placed in an exposed schema unless their execute grants, ownership checks, and behavior are deliberately reviewed.
- Authorization decisions never depend on user-editable profile metadata.
- Security and performance advisors are required before release.

### 21.6 Data deletion

Account deletion removes or irreversibly anonymizes:

- Player profile and settings.
- Flower and display state.
- Glow and step-credit data.
- Wander sessions and offers.
- Product events tied to the player.
- V2 MCP grants and V3 relationships when those releases exist.

Deletion behavior and retention exceptions must be documented before public launch.

### 21.7 Server authority

The server is authoritative for:

- Daily daisy eligibility.
- Daily Wander flower capacity.
- Persisted Wander offers and awards.
- Flower acquisition and terminal transitions.
- Bloom deadlines and Hibernate freezing.
- Vase capacity and ownership.
- Sale pricing.
- Sunshine purchase and application.
- Step-to-glow credit.
- Glow balance.

The client is responsible for:

- Rendering and local interaction.
- Permission requests.
- Obtaining the one-time location used for a verified start.
- Reading Health or fallback device-step data with consent.
- Maintaining offline pending operations.
- Displaying provisional state clearly until synchronization.

---

## 22. V2 AI and MCP Requirements

### 22.1 Built-in AI role

The built-in AI is a quiet resident, not a coach or autonomous manager.

Candidate behaviors:

- Introduce a newly discovered flower.
- Notice a favorite arrangement.
- Summarize a week or season of collecting.
- Suggest a species missing from the Pressbook that is currently in season.
- Mention a displayed flower approaching its natural fade.

The AI must not make health claims, pressure the player to walk, invent location memories, or claim a real species was present at the player's park.

### 22.2 MCP authorization

The V2 HTTP MCP server uses the current MCP authorization model based on OAuth 2.1 concepts.

Requirements:

- Publish protected-resource metadata.
- Use Authorization Code with PKCE where applicable.
- Bind access tokens to the MCP server resource/audience.
- Validate token issuer, expiry, audience, and scopes.
- Use HTTPS.
- Derive the player identity from the validated authorization context.
- Do not accept a caller-supplied `player_id` as authority.
- Support revocation from app Settings.
- Use least-privilege scopes.
- Do not pass MCP access tokens through to upstream services.

Invitation codes are reserved for V3 friend discovery and are not the V2 MCP authorization mechanism.

### 22.3 Initial read-only MCP surface

Candidate tools:

| Tool | Returns |
|---|---|
| `get_home_snapshot` | Unlocked vase slots, displayed flowers, and shelf assignments |
| `get_pocket` | Living flowers, remaining time, and display assignments |
| `get_pressbook` | Species, pressed counts, and first-discovery dates |
| `get_glow_summary` | Glow balance and categorized game-economy totals, excluding raw Health data |
| `get_season_info` | Current season and currently available species |
| `get_collection_history` | Flower acquisitions and terminal actions by date, without precise location |

### 22.4 MCP exclusions

V2 does not expose:

- Raw Health samples or step-source details.
- Exact or coarse current location.
- Park history.
- Email address or authentication-provider tokens.
- Write operations.
- Sell, press, sunshine, purchase, or arrangement actions.
- V3 social data before V3 exists and separate consent is designed.

---

## 23. V3 Social Requirements

### 23.1 Philosophy

Social interactions share homes, not performance. There are no leaderboards, public follower counts, or public step totals.

### 23.2 Friend connection

- A player generates a short-lived invitation code.
- Another authenticated player enters the code to create or request a connection.
- Codes are single-purpose, revocable, rate-limited, and expire.
- Contacts are not uploaded.
- Game Center is not used.

### 23.3 Home visits

Friends may view an asynchronous snapshot containing:

- Vase arrangement.
- Shelf arrangement.
- Chosen public display name.

Friends may not view:

- Pocket contents.
- Glow balance.
- Step totals.
- Wander history.
- Hibernate history.
- Location information.

### 23.4 Interactions

- Like a friend's Home.
- Send one of six preset warm messages.
- Gift one sunshine for 20 glow.
- View a visitor log.

Initial preset messages:

- “Your flowers look lovely today.”
- “I like your arrangement.”
- “Hope you had a nice wander.”
- “Stopped by to say hi!”
- “Brought you a little something.”
- “Your home feels like you.”

### 23.5 Initial rate limits

| Action | Limit |
|---|---|
| Like | One per friend per local day |
| Preset message | One per friend per local day |
| Gift sunshine | One per friend per local day |
| Logged snapshot visit | One per friend per rolling six hours |

All limits are server-enforced. V3 must include unfriend, block, report, and invitation-revocation flows before public release.

---

## 24. Risks and Mitigations

| Risk | Why it matters | V1 mitigation | Evidence to watch |
|---|---|---|---|
| The app does not meaningfully motivate outdoor walks | The business premise fails | Focus V1 on the flower loop and run a 4–6 week target-user beta | First Wander and week 3–4 Wander behavior; interviews |
| Early pressing removes emotional lifecycle tension | Players may press every flower immediately | Keep the requested option, make the consequence clear, and measure early-press timing and share | Percentage pressed in first hour/day; natural fade rate |
| Health glow overwhelms the economy | All-day multi-device steps may create large balances | Do not finalize vase prices before beta; track source and daily earnings | Glow distribution and time to upgrades |
| Permission requests reduce trust | Location and Health are sensitive | Contextual prompts, manual alternatives, minimal storage | Permission acceptance and abandonment reasons |
| Apple Maps park results are incomplete or inaccurate | A valid outdoor walk may be blocked | 805 m tolerance and immediate manual fallback | Manual fallback rate and user reports |
| Manual mode can be exploited | Rewards can be earned without park verification | Accept because there is no competition or paid glow; monitor only for economy tuning | Manual mode share and extreme sessions |
| Background timing is unreliable | Players may lose earned choices | Persist session start, thresholds, offers, and pending choices; 60-minute cap | Restored-session failures and support reports |
| Multi-device Health data causes duplicate glow | Currency integrity erodes | Daily aggregate high-water mark and idempotent credit ledger | Reconciliation corrections and duplicate attempts |
| Device time-zone changes allow extra daily rewards | Small economy inconsistency | Accept noncompetitive risk; maintain UTC/local-date audit and uniqueness | Unusual reward patterns |
| Pocket and flower actions become administrative | Calm experience becomes work | Soft cap, batch selection helpers, per-flower clarity, no blocking | Overflow frequency and action abandonment |
| V1 has a weak long-term goal after vase unlocks | Retention may flatten | Pressbook first-discovery history; defer larger museum progression until loop validation | Retention after slot unlocks |
| Scope grows before validation | Cost and learning become unclear | Enforce V1/V2/V3 boundaries | Scope changes and delayed beta date |

---

## 25. Launch Gates

### 25.1 Product gate

- Daily loop is understandable without a long tutorial.
- A first-time user can display the daisy and start a Wander.
- All permission denials have working alternatives.
- Early pressing, selling, and natural pressing have distinct consequences.

### 25.2 Reliability gate

- Threshold rewards survive backgrounding, termination, offline use, and retry.
- No duplicate daisy, Wander reward, sale credit, sunshine debit, or step credit occurs under repeat requests.
- Hibernate preserves remaining flower duration and excludes step credit.
- Account recovery restores authoritative state.

### 25.3 Privacy and security gate

- No route or exact location is retained.
- Only the approved Health aggregate is read and stored.
- Account deletion works end to end.
- All exposed tables have explicit grants and ownership-aware RLS.
- No secret credential is embedded in the client.
- Security advisors have no unresolved release-blocking finding.

### 25.4 Business gate

- Beta pricing remains disabled.
- Infrastructure usage alerts are active.
- Apple Maps usage is bounded to the intended start check and included daily quota.
- Product analytics can answer the V1 validation questions without sensitive data.

### 25.5 App distribution gate

- Google and Apple sign-in both work on a physical device.
- In-app account deletion is available.
- Permission-purpose strings match actual data use.
- Store copy describes the app as a game and outdoor-motivation product, not a medical or fitness service.
- Any future digital cosmetic purchase follows current App Store purchase requirements.

---

## 26. V1 Acceptance Criteria

### 26.1 Accounts

- A user can create and access one game account with Google or Apple.
- A restored session loads server-authoritative Pocket, Pressbook, Home, glow, and Hibernate state.
- Signing out does not delete game state.
- Account deletion removes the player's game data according to the documented policy.

### 26.2 Daily daisy

- Exactly one daisy is granted on the first eligible open of a device-local calendar day.
- The grant records UTC time, local date, and time-zone identifier.
- Reopening and repeated requests do not grant a second daisy for the same decided day.
- Missing a day does not create a later backlog.
- No daisy is granted during Hibernate.

### 26.3 Wander start

- A user with location and network can start when Apple Maps returns an accepted park-related place within 805 meters.
- The app says **near a park**, not **inside the park**.
- Exact coordinates and Apple Maps place results are not retained after the check.
- A user without location or network can start through manual confirmation.
- Manual and verified sessions use the same reward rules.
- Only one Wander is active at a time.

### 26.4 Wander timing and rewards

- A session below 10 minutes earns no flower.
- At 10 minutes, three persisted species are offered and one can be selected.
- At 20 minutes, the two remaining species are offered and one can be selected.
- At 30 minutes, the final species is awarded automatically.
- Backgrounded or closed apps preserve pending decisions.
- Reopening presents pending decisions in the correct order.
- A session ends at or before 60 minutes.
- No more than six Wander flowers are awarded per local day.
- The UI never promises more flowers than the day's remaining allowance.
- Repeated synchronization does not duplicate a session or reward.

### 26.5 Pocket and vases

- Every living flower appears in the Pocket whether displayed or not.
- Collection succeeds above the soft capacity of 12.
- Overflow prompts do not appear during the outdoor collection moment.
- A prompt can be dismissed.
- Display assignments respect vase capacity.
- Rearrangement does not change bloom time.
- At full progression, no more than six living flowers are displayed.

### 26.6 Lifecycle

- Bloom time begins at acquisition.
- Existing flower deadlines do not change when the catalog duration is retuned.
- A natural fade presses the flower and clears its vase assignment.
- Every living flower offers Press now.
- Early pressing requires confirmation, grants no glow, and adds the flower to Pressbook.
- Selling requires confirmation, grants the displayed server-calculated glow, and excludes the flower from Pressbook.
- A flower can transition to only one terminal state.
- Sunshine costs 20 glow and adds exactly one day to one displayed flower.
- Multiple sunshine applications stack.
- Sunshine is not refunded after selling or early pressing.

### 26.7 Pressbook

- Each species shows first discovery date and pressed count.
- Natural and early presses both increment the count.
- Sold flowers do not increment the count.
- No exact park or location is displayed or recoverable from V1 collection records.

### 26.8 Steps and glow

- With Health permission, glow is based on the accepted combined Health step total for the local day.
- Health mode can reflect steps contributed by iPhone, Apple Watch, and connected Health sources without double-summing raw samples.
- Only aggregate step data required for glow is stored.
- Without Health access, only active-Wander device steps earn step glow.
- Without Health or motion access, Wander time still earns flowers.
- Every completed block of 100 eligible steps grants one glow.
- Repeated synchronization does not duplicate glow.
- Switching from fallback to Health credits only a positive net difference for the day.
- Glow never expires.

### 26.9 Hibernate

- Hibernate is entered and exited manually.
- Flower timers freeze with remaining duration preserved.
- No Wander starts, daily daisy grants, or step glow occurs while active.
- Step activity during Hibernate is not credited after return.
- Existing glow remains spendable.
- On return, the current real-world seasonal pool is active.
- Missed daisies are not backfilled.
- The snowflake charm appears only during Hibernate and has no game action.

### 26.10 Privacy and security

- No exact coordinates, routes, park names, or Apple Maps place data are stored in V1 game records.
- No raw Health samples or unrelated Health categories are stored.
- Every exposed player row is ownership-protected.
- Privileged keys are absent from the shipped app.
- Economy and lifecycle mutations reject unauthorized player access.

---

## 27. Decisions and Remaining Business Questions

### 27.1 Fixed decisions

- V1 is flower-only.
- AI and MCP move to V2.
- Social moves to V3.
- Game Center is removed.
- Apple Maps Server API checks for an accepted park-related place within 0.5 miles at Wander start.
- Manual park confirmation is always available when verification is unavailable.
- Exact location and park memory are not retained.
- V1 remembers first discovery date only.
- Device time zone controls daily boundaries.
- Hibernate resumes flower timers but immediately adopts the current real-world season.
- Early pressing is available under every living flower.
- Health mode uses combined eligible steps from all sources available through Apple Health.
- If Health is unavailable, only active-Wander device steps count.
- Google and Apple are the V1 sign-in options.
- The dedicated Supabase project is the backend.
- V2 MCP uses standard OAuth-based authorization, not invitation-code tokens.
- V3 friends use invitation codes.

### 27.2 Questions to resolve through beta rather than pre-build debate

- Final slot 2 and slot 3 glow prices.
- Final cosmetic vase prices and visual families.
- Whether early pressing needs a presentation cost or cooldown if immediate pressing dominates behavior.
- Whether 100 steps per glow produces a healthy economy with all-day multi-device Health totals.
- Whether the 805-meter park tolerance feels motivating without feeling disconnected from green space.
- Whether 10–15 species per season is sufficient for early collection interest.
- Whether a four- to six-week beta demonstrates repeat outdoor behavior.

### 27.3 Later product decisions

- Hemisphere and regional season model for international release.
- Permanent cosmetic catalog and price points.
- Exact V2 AI entitlement and operating budget.
- Whether MCP remains free, paid, or bundled with AI.
- V3 invitation-code expiration and moderation operating process.
- Long-term museum progression after the flower loop is validated.

---

## 28. Current Primary References

Platform behavior and policy must be rechecked during implementation and before release.

### Apple

- [Apple Health step count](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/stepcount)
- [Apple Health statistics collection queries](https://developer.apple.com/documentation/healthkit/executing-statistics-collection-queries)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Sign in with Apple](https://developer.apple.com/documentation/signinwithapple)
- [Apple Maps Server API](https://developer.apple.com/documentation/applemapsserverapi)
- [Apple Maps Search](https://developer.apple.com/documentation/applemapsserverapi/-v1-search)
- [Apple Maps POI categories](https://developer.apple.com/documentation/applemapsserverapi/poicategory)
- [Apple Maps tokens](https://developer.apple.com/documentation/applemapsserverapi/creating-and-using-tokens-with-maps-server-api)

### Supabase

- [Supabase Google login](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Supabase Apple login](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Securing the Supabase Data API](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys)
- [Supabase breaking-change changelog](https://supabase.com/changelog?types=breaking-change)

### MCP

- [MCP authorization specification](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)
