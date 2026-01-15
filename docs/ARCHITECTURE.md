# oneseventwo – expansion-ready architecture notes

This repo is being structured to support a Katana Zero–style action game: fast restart loop, tight combat, lots of enemy variants, and many attack/projectile types.

## Global systems (autoloads)

Configured in `project.godot`:

- `GameEnums` – shared enums (combat style/stance).
- `Events` – global event bus (player died, restart requested, etc.).
- `GameTime` – hitstop + slowmo controller (uses real-time ticks, so hitstop resolves even when `Engine.time_scale == 0`).
- `SceneRouter` – fade transitions + the instant-retry loop.
- `Game` – lightweight session state (currently counts deaths).

### Instant retry loop
- Player dies ➜ emits `Events.player_died` and `Events.request_restart`
- `SceneRouter` listens and executes: fade out → clear time scale → `reload_current_scene()` → fade in.

## Combat data flow (current)

### Unified rule
All attacks (melee + projectiles) route through:

1. **Hitbox** (or Projectile) builds a `DamageInfo`
2. `Hurtbox.apply_hit(DamageInfo, attacker)`
3. The Hurtbox's owner handles it in `receive_hit(damage_info, attacker)`

### Projectile → Player
- Enemy spawns `ProjectileBase` and calls `initialize(def, origin, dir, shooter, target)`.
- `ProjectileBase` checks `area.is_in_group(def.hurtbox_group)` and calls `area.apply_hit(dmg, shooter)`.
- Player (an `Actor`) uses stance/parry logic inside `_filter_hit()` and takes damage via its `HealthComponent`.

### Player → Enemy
- Player sword uses `Hitbox` with `hurtbox_group = "enemy_hurtbox"`.
- Enemy hurtbox forwards to `EnemyShooter.receive_hit(...)`, which applies damage via `HealthComponent` and dies when HP reaches 0.


## Adding a new projectile type

1. Duplicate an existing definition in `scenes/projectiles/defs/*.tres`.
2. Adjust:
   - `attack_style`, `damage`
   - `speed`, `lifetime_seconds`, `pierce_count`
   - `texture`, `sprite_scale`, `modulate`
   - `hurtbox_group` (e.g. `player_hurtbox`)
   - `movement` (Straight, Homing, Wavy, or add your own)
3. Assign the new definition to an enemy shooter (or future attack pattern system).

## Planned next structural upgrades (safe to add now)

- Combat system now routes **all** damage through `Hurtbox.apply_hit()` → `owner.receive_hit(DamageInfo, attacker)`.
- (Deprecated) `take_damage()` and `take_sword_damage()` are no longer used by the core pipeline.
- Add `HealthComponent` + shared reactions (hit flash, knockback, stun) for most actors
- Add a small FSM for the player (idle/run/jump/dash/attack/hurt/dead)
- Add level/checkpoint routing (spawn points, checkpoint restart vs full reload)
- Add dialogue/cutscene scaffolding (Katana Zero’s hallmark)
