# Wander Wonders V1 Autumn art brief

Status: brief opened; commissioning and rights approval are pending owner action.

## Owner-approved contract fields

```text
ART_OWNER=PENDING_OWNER_INPUT
ARTIST=PENDING_OWNER_INPUT
ART_BUDGET_USD=PENDING_OWNER_INPUT
FIRST_STYLE_CHECKPOINT=2026-08-21
FLOWER_SET_CHECKPOINT=2026-09-18
FINAL_ASSET_DELIVERY=2026-10-02
REVISION_BUFFER_END=2026-10-09
RIGHTS_CONFIRMED=PENDING_OWNER_CONFIRMATION
```

## Fixed V1 contract

- Autumn only; no Spring, Summer, or Winter art.
- Transparent production exports with the approved color profile and documented canvas dimensions.
- Stable lowercase asset keys: `<slug>_living`, `<slug>_fading`, and `<slug>_pressed`.
- Three vase silhouette masks compose with three seamless textures; do not export nine duplicate combinations.
- Include safe zones for Dynamic Type, accessibility overlays, and iPhone display sizes.
- Include licensing/ownership documentation and two review rounds.
- Acceptance is against `Content/wonder_asset_manifest.v1.json` and the validator in `Scripts/validate_wonder_assets.swift` once Step 5 creates them.

Missing owner, budget, rights, contract, or production delivery blocks the Step 0 art gate and the Step 13 release archive.
