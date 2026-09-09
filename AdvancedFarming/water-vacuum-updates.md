# Water Vacuum Updates

## Scope

These changes apply to normal harvestable soil, planted survival crops, and growbeds.

## Updated Files

### `game/interactables/MountedWaterGun.lua`

- Loads `survival_harvestable.lua` so soil and crop harvestable UUIDs are available.
- Checks the same local `+Z` direction used by the mounted gun projectile.
- Raycasts using the harvestable filter so the mounted gun body and other shapes do not hide the target.
- Allows water on bare soil only when `publicData.watered` is not `true`.
- Allows water on growing crops only when their retained water has expired.
- Blocks water on mature crops.
- Does the check before the water transaction, so blocked shots do not spend water.
- Removed the temporary `[MountedWaterGun]` debug print.

### `game/harvestable/HarvestableSoil.lua`

- Adds server-side `harvestable.publicData` containing:
  - `fertilized`
  - `watered`
  - `seeded`
- Calculates `watered` from `waterTick` and the normal `DAYCYCLE_TIME_TICKS * 1.5` retention period.
- Updates public data when soil is created, saved, watered, fertilized, or affected by rain.
- Records direct water projectile hits immediately.
- Keeps the existing splash event behavior intact.

### `game/harvestable/GrowingHarvestable.lua`

- Publishes `harvestable.publicData.watered` for planted crops.
- Publishes `harvestable.publicData.fertilized` for planted crops.
- Uses the crop's existing server-side `waterTick` state.
- Refreshes public data when the crop is created or its saved state changes.

### `game/interactables/Growbed.lua`

- Publishes `watered`, `fertilized`, and `seeded` state through the growbed interactable.
- Refreshes that state after water is consumed by the growbed timer.
- Keeps the public data available instead of clearing it at the end of each update.
- Allows the mounted water gun to reject already-watered growbed soil.

## Watering Rules

| Target | Result |
|---|---|
| Bare soil, not watered | Water is allowed |
| Bare soil, still watered | Water is blocked |
| Growing crop, not watered | Water is allowed |
| Growing crop, still watered | Water is blocked |
| Mature crop | Water is blocked |
| No harvestable hit | Water is allowed, preserving normal gun behavior |

## Applying the Changes

1. Fully exit Scrap Mechanic.
2. Start the game again so the Lua scripts reload.
3. Reload the world.
4. Test bare soil, a freshly planted crop, an already-watered crop, and a mature crop.

No water gun rebuild or blueprint rebuild is required for these Lua changes.
