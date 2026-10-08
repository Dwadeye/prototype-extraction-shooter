# Draft Pack — procedural low-poly models for prototype-extraction-shooter

21 GLB models generated to match the KayKit City / Kenney kit style already in
the project (flat colors, chunky silhouettes, no textures). All are plain
glTF 2.0 binary — Godot imports them on project open, no plugins needed.

Open `scenes/draft_pack_showcase.tscn` to see everything at once.

## Conventions

| Category | Origin | Facing | Notes |
|---|---|---|---|
| `char_*` | feet | +Z | drop-in for `enemy.gd` (its `rotation.y = PI` matches) |
| `beast_*` | feet (body center) | +Z | quadrupeds; shrink capsule or `model_height` when used as enemies |
| `wep_*` | grip | muzzle at **-Z** | weapon manager normalizes size itself |
| `tile_*` | tile center, top y=0.1 | — | same 2x2 m footprint as `kaykit_city/road_*`; `_prop(..., 6.0)` puts them on the 6 m grid |
| `bld_*` | base center | door/front at +Z | roughly KayKit building scale |

## What's here

- **Players / NPCs**: `char_ranger` (olive + cap + backpack), `char_hunter`
  (brim hat, beard), `char_raider` (red hood + mask — enemy look)
- **Beasts**: `beast_wolf`, `beast_boar` (tusks, mane)
- **Weapons**: `wep_ar`, `wep_smg`, `wep_shotgun`, `wep_sniper` (scope +
  bipod), `wep_pistol`, `wep_machete`
- **Ground**: `tile_grass`, `tile_dirt`, `tile_floor_concrete` (indoor),
  `tile_sidewalk`, `tile_road_straight`, `tile_road_crossing`
- **Buildings**: `bld_house`, `bld_warehouse` (roller door), `bld_ruined`
  (broken corner + rubble), `bld_watchtower` (extraction-zone landmark)

## Integration examples

Enemy variant (in `scripts/enemy.gd`):

```gdscript
const ENEMY_MODELS := [
    preload("res://assets/draft_pack/char_raider.glb"),
    preload("res://assets/draft_pack/char_hunter.glb"),
]
```

New weapon entry (in `scripts/weapon_defs.gd`):

```gdscript
const WEP_AR := preload("res://assets/draft_pack/wep_ar.glb")
# ...
{
    "kind": "gun", "slot": "primary", "name": "Draft AR",
    "model": WEP_AR,
    "damage": 24.0, "fire_interval": 0.09, "magazine": 30, "reload": 2.1,
    "automatic": true, "bullet_speed": 95.0, "spread": 1.1, "pellets": 1,
    "gravity": 5.0, "ads_fov": 45.0,
    "view_pos": Vector3(0.12, -0.44, -0.12), "view_rot": Vector3.ZERO, "view_size": 0.72,
},
```

Tiles / buildings in `scripts/map_builder.gd`:

```gdscript
const TILE_ROAD := preload("res://assets/draft_pack/tile_road_straight.glb")
const BLD_RUINED := preload("res://assets/draft_pack/bld_ruined.glb")
# ...
_prop(arena, TILE_ROAD, Vector3(offset, -0.24, 0), 90.0, 6.0, false)
_prop(arena, BLD_RUINED, Vector3(slot, 0, -lane), 180.0, 6.0)
```

## Regenerating / tweaking

The generator sources live outside the Godot project
(`asset_pack/` in the Kimi workspace): `modelkit.py` (box/wedge/cylinder/
pyramid/prism -> GLB), plus `characters.py`, `weapons.py`, `tiles.py`,
`buildings.py`. Run any module to rebuild the GLBs, or edit a recipe and
re-run — sizes and colors are plain numbers at the top of each builder.
