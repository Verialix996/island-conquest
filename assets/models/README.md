# Low-poly model asset pass

This folder contains lightweight Godot 4 text-scene model assets built from primitive meshes only. They are intended for top-down readability and quick iteration without Blender-exported binaries.

## Units

- `units/low_poly_soldier_player.tscn`: green player soldier with boxed torso, helmet, pack, and rifle silhouette.
- `units/low_poly_infantry_melee.tscn`: melee infantry with broad machete silhouette.
- `units/low_poly_infantry_ranged.tscn`: ranged infantry with long rifle silhouette.

Each unit scene exposes a `FactionTintTorso` MeshInstance3D in the `faction_tint` group. Runtime scenes duplicate this material before recoloring or hit-flashing so multiple spawned units do not share mutable material state.

## Weapons

- `weapons/weapon_pistol_model.tscn`
- `weapons/weapon_rifle_model.tscn`
- `weapons/weapon_shotgun_model.tscn`

Weapon scenes are small box-mesh silhouettes with dark metal, brown grip, and a warm muzzle marker. The live weapon scenes under `scenes/weapons/` instance these models while preserving existing RayCast3D, particles, audio, and script nodes.

## Props and buildings

- `props/cover_sandbag_wall.tscn`: staggered low wall with StaticBody3D collision.
- `props/cover_crate_stack.tscn`: asymmetrical crate stack with StaticBody3D collision.
- `buildings/wall_segment_low_poly.tscn`: concrete wall segment with StaticBody3D collision.

Collision is intentionally simple box coverage to stay navigation-friendly and cheap. The battle generator now uses these prop scenes for chunk/random cover by default, while keeping the old procedural box cover as a fallback if prop instancing is disabled or unavailable.

## Integration notes

- `scenes/player/player.tscn` now instances `low_poly_soldier_player.tscn` in place of the capsule visual while preserving the existing capsule collision.
- `scenes/units/enemy_base.tscn` now instances the melee infantry model in place of the capsule visual while preserving collision/navigation nodes.
- `scenes/units/enemy_ranged.tscn` hides the inherited melee model and adds the ranged infantry model.
- `scenes/weapons/weapon_base.tscn`, `weapon_rifle.tscn`, and `weapon_shotgun.tscn` now instance the corresponding weapon model scenes.
- `scenes/battle/world_generator.gd` now picks low-poly sandbag/crate cover props for chunk cover slots and uses the wall segment model for wall-building defenses.
- `scenes/units/enemy_base.tscn` reuses the existing `grunt.ogg` placeholder as a quiet, pitch-varied melee attack bark; weapon gunshots and death sounds remain unchanged.

Scale assumption: the character root remains a `CharacterBody3D` with capsule collision centered near the original placeholder. Visual models are roughly 2 Godot units tall with clear +Z/-Z weapon direction silhouettes for the existing top-down camera.
