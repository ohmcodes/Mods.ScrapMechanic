# Corn Seed Update

## Added

- Added `obj_seed_corn` with a new UUID.
- Added `hvs_growing_corn` and `hvs_mature_corn` with new UUIDs.
- Added cultivated corn to the normal soil planting lifecycle.
- Added the existing world corn mesh and textures as both the growing and mature crop visual.
- Added corn to the Planter, Vacuum, watering list, crop collection list, and seed container seed list.
- Harvesting cultivated corn gives one corn item and one corn seed through `MatureHarvestable`.
- Harvesting wild corn now also drops one corn seed, while preserving its existing corn drops and regrowth behavior.
- Added corn as a possible Seedbot type and added Seedbot hit/death loot tables.
- Added the English inventory label `Corn Seed`.
- Added the corn seed UUID to `Survival/Gui/IconMapSurvival.xml` and assigned it the custom atlas cell at `2688 2496`.
- Added a dedicated corn Seedbot crate effect with `8b475b` renderable color and the edited corn seedbag diffuse texture.
- Added `/spawncornseedbot` for deterministic corn Seedbot testing.
- Corn now uses the broken world-corn mesh while growing and grows in about 6 real minutes before fertilizer acceleration.
- Fertilizer now starts the growth timer immediately when applied to any growing crop.

## Current asset state

The normal corn seedbag uses the standard seedbag mesh with a dedicated corn diffuse texture and the burgundy item color `8b475b`. Holding, dropping, and force-placing the item all resolve to the same corn renderable.

The Seedbot uses a separate crate02 mesh and a separate corn crate renderable/effect. Its color is defined in `totebot_seedbot.effectset` as RGB values equivalent to `8b475b`:

```text
R 0.545098, G 0.278431, B 0.356863, A 1.0
```

The shared `seed_tag` submesh is separate from the bag body. A potato-shaped overlay or mask must therefore be investigated in the diffuse/ASG texture assigned to the relevant submesh; `loot.effectset` only supplies the generic loot glow and shape-renderable wrapper.

## Asset files to edit later

- Corn seedbag diffuse texture: `Survival/Objects/Textures/consumable/obj_consumable_seedbag_corn_dif.tga`
- Editable Photoshop source: `Survival/Objects/Textures/consumable/obj_consumable_seedbag_corn_dif.psd`
- Seed bag renderable: `Survival/Objects/Renderable/Consumable/obj_consumable_seedbag_corn.rend`
- Hotbar/inventory icon map: `Survival/Gui/IconMapSurvival.xml` (corn seed uses the custom atlas cell at `2688 2496`)
- The corn seedbag renderable now uses `obj_consumable_seedbag_corn_dif.tga` for all LODs and keeps the shared seedbag ASG/normal textures.
- Shared seedbag ASG mask/shading: `Survival/Objects/Textures/consumable/obj_consumable_seedbag_asg.tga`
- Shared seedbag normal map: `Survival/Objects/Textures/consumable/obj_consumable_seedbag_nor.tga`
- Shared circular seed tag: `Survival/Objects/Textures/consumable/obj_seed_tag_dif.tga`
- Growing corn renderable: `Survival/Harvestables/Renderable/Plantables/hvs_plantables_corn_growing.rend`
- Mature corn renderable: `Survival/Harvestables/Renderable/Plantables/hvs_plantables_corn.rend`
- Existing corn source mesh: `Survival/Harvestables/Mesh/Farmables/hvs_farmables_cornplant.fbx`
- Existing smaller/broken corn source mesh: `Survival/Harvestables/Mesh/Farmables/hvs_farmables_cornplant_broken.fbx`
- Seedbot corn renderable: `Survival/Effects/Renderable/totebot_seedbot/eff_char_seedbot_corncrate.rend`
- Seedbot effect set: `Survival/Effects/Database/EffectSets/totebot_seedbot.effectset`
- Seedbot crate mesh: `Survival/Effects/Meshes/totebot_seedbot/eff_char_seedbot_crate02.fbx`
- Seedbot crate texture source: `Survival/Objects/Textures/containers/obj_containers_corncrate_dif.tga`

The current growing and mature renderables use the existing world-corn mesh family. To create a proper crop with visible soil, make a Blender mesh containing the corn plant and a soil/base submesh, then map both submeshes in the corresponding `.rend` file. A useful template is the existing potato pair:

- `Survival/Harvestables/Renderable/Plantables/hvs_plantables_potato_growing.rend`
- `Survival/Harvestables/Renderable/Plantables/hvs_plantables_potato.rend`

Keep the submesh names `Soil` and the plant name consistent with the Blender export, or update the `subMeshMap` names to match.

## Files changed

- `Scripts/game/survival_items.lua`
- `Scripts/game/survival_harvestable.lua`
- `Scripts/game/tools/Planter.lua`
- `Scripts/game/interactables/Vacuum.lua`
- `Scripts/game/interactables/MountedWaterGun.lua`
- `Scripts/game/survival_collections.lua`
- `Scripts/game/worlds/BaseWorld.lua`
- `Scripts/game/survival_spawns.lua`
- `Scripts/game/characters/SeedbotCharacter.lua`
- `Scripts/game/harvestable/CornPlant.lua`
- `Scripts/game/loot/lootsources/seedbot/lootsource_seedbot.lua`
- `Gui/Language/English/inventoryDescriptions.json`
- `Gui/IconMapSurvival.xml`
- `Effects/Renderable/totebot_seedbot/eff_char_seedbot_corncrate.rend`
- `Effects/Database/EffectSets/totebot_seedbot.effectset`
- `Objects/Renderable/Consumable/obj_consumable_seedbag_corn.rend`
- `Objects/Textures/consumable/obj_consumable_seedbag_corn_dif.tga` (user-created asset)
- `Objects/Textures/containers/obj_containers_corncrate_dif.tga` (user-created asset)
- `Objects/Database/ShapeSets/plantables.shapeset`
- `Harvestables/Database/HarvestableSets/plantables.harvestableset`
- `Harvestables/Renderable/Plantables/hvs_plantables_corn_growing.rend`
- `Harvestables/Renderable/Plantables/hvs_plantables_corn.rend`

## Testing checklist

1. Start or reload a Survival world after making a backup of the Survival data folder.
2. Give yourself `obj_seed_corn` using the existing item-give/debug path.
3. Equip the Planter, target placed soil, and plant the seed.
4. Water the crop and confirm the corn visual grows through the normal crop timer.
5. Harvest the mature crop and confirm corn plus a seed are collected and soil returns.
6. Destroy a wild corn plant and confirm corn, a seed, and the normal regrowing plant appear.
7. Find or spawn a Seedbot and confirm its hit/death loot can provide corn seeds.

## Cache note

Scrap Mechanic compiles source assets into cache files. After replacing a TGA or renderable, fully exit the game and confirm no Scrap Mechanic process remains. The known corn texture cache is:

```text
Cache/Textures/obj_consumable_seedbag_corn_dif_3B363F5E5DBE4879.tco
```

Do not edit cache files manually. Delete only the matching generated cache file if a full restart does not reload the changed texture. The Seedbot crate mesh may also have generated `.mco` files under `Cache/Mesh`; those are generated files and should not be edited.

The original world corn UUID, scripts, and terrain placements were retained; the new cultivated crop uses separate UUIDs.
