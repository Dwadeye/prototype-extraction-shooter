# Placeholder asset library

Temporary CC0 models (Quaternius) mapped to the features in
`full_plan.md`. Swap for bespoke/Kimi models when they land.

| Category | Models | Planned use |
|---|---|---|
| `armor/` | Armor_Leather, Armor_Metal, Armor_Metal2, Helmet1-3 | **2.1** armor chest + helmet |
| `attachments/` | Scope_1, Scope_2, Sight_1, Grip_AR_1, Magazine_AR | **2.3** optic / grip / mag (suppressor = Kenney `silencer-small`) |
| `consumables/` | Bandages, FirstAidKit, FirstAidKit_Hard, FlareGun, GasCan | **P0-3/2.1** bandage & medkit, **2.5** flare extract |
| `loot/` | Bone, Skull, Coin, Gold_Ingots, Mineral, Crystal1, Scroll, Parchment, Book1_Closed, Key1, Padlock, Bag, Backpack, Chest_Closed/Open | **P1.7** drops (fang=Bone, pelt=Bag), **3.1** stash, **4.3** loot cache, intel documents |
| `props/` | Tent, Bonfire_Fire, WoodLog, BearTrap_Open, PropaneTank, Radio, MarketStand_1, Cart, Barrel, Crate, Well, Bell_Tower, Gazebo, Hay, Smoke, Shelf_Large, Kitchen_Fridge | **4.1** POIs (camp, market, church, gas station, loading yard, server room), **4.4** airdrop smoke |
| `buildings/` | House_1/2, Inn, Blacksmith, Mill, Building1_Large, House1 | **4.1** map expansion / POIs |
| `animals/` | Wolf, Fox, Deer, Stag, Bull, Rat, Spider | **4.3** Alpha Wolf (scale `Wolf`), wildlife, critters |
| `characters/` | Suit_Man, Worker_Man, Suit_Woman, Humanoid_Unarmed, Humanoid_Gun, **Cyber_Character (22 clips), Cyber_Bot (7 clips)** — all rigged + animated | **3.2** trader NPCs; **animated enemies** |

## Notes
- GLB with embedded materials; Godot imports on project open (`--import`).
- Origins/scales are not normalized — fit with the existing `_aabb_in*` helpers
  (see `scripts/enemy.gd`) or a shared `model_fit.gd` when wiring.
- Re-fetch / extend: edit the manifest in `tools/fetch_placeholders.ps1` and rerun.
