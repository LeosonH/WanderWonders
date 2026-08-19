# Wander Wonders UI Redesign Execution

## Scope

- Use the supplied Home, Pocket, and Pressbook images as final static backgrounds.
- Preserve all existing data, state, actions, navigation, Supabase contracts, models, and progression logic.
- Reuse existing flower, vase, and pressed-flower assets. Do not redesign or regenerate art.
- Limit changes to the three screens, their visual assets, and the smallest shared UI support required.

## Implementation order

1. Find the current Home, Pocket, and Pressbook views. [codex done]
2. Find the existing flower, vase, and pressed-flower assets. [codex done]
3. Import and use the three supplied backgrounds. [codex done]
4. Display each background edge-to-edge without material cropping. [codex done]
5. Remove or hide old static UI that duplicates the backgrounds. [codex done]
6. Preserve dynamic UI, application state, and business behavior. [codex done]
7. Align Home vases and flowers to the three background slots. [codex done]
8. Align Pocket's six slots, statistics, and selected-flower preview. [codex done]
9. Align Pressbook's six slots and dynamic pagination. [codex done]
10. Correct flower/vase clipping and z-order so stems appear inserted. [codex done]
11. Build the app. [codex done]
12. Fix compilation errors. [codex done] (The first Debug build succeeded; no compiler errors remained.)
13. Inspect the layout on at least one representative iPhone simulator. [codex done]
14. Capture screenshots when available and compare the final UI with all three supplied references. [codex done]

## Acceptance criteria

- Backgrounds are not materially cropped; system status and app tab bars are not duplicated.
- Static titles and decorations are not redrawn over the backgrounds.
- Home vases are centered on the doilies and flowers do not show through vase bodies.
- Pocket's six slots and transparent hit targets align with the baked visuals; dynamic stats and preview remain functional.
- Pressed flowers fit within Pressbook slots; transparent page controls and dynamic pagination retain existing behavior.
- Existing game data and interactions remain intact, with no Supabase, schema, model, navigation, or unrelated-screen changes.

## Follow-up UI patch

- Apply the shared paper, card, button, and custom tab styling to Wander, Shop, and Settings. [codex done]
- Replace system alerts and confirmation dialogs with the shared `WonderModal` presentation. [codex done]
- Preserve the existing Press, Sell, Sunshine, purchase, Wander, settings, and account-deletion actions. [codex done]
- Show pressed species directly in Pressbook with six-item pagination. [codex done]
- Run the complete `WanderWondersTests` unit-test target. [codex done] (18 tests passed.)
