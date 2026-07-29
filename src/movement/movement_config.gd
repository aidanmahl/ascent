class_name MovementConfig
extends Resource

## All values are in pixels and frames (60 physics ticks/sec), never
## seconds or meters, per CLAUDE.md. Starting values from SPEC.md section 4 -
## tuning knobs, not final numbers.

@export_group("Run")
@export var max_run_speed: float = 2.125
@export var ground_acceleration: float = 0.10625
@export var ground_friction: float = 0.40
@export var air_acceleration: float = 0.0765
@export var air_friction: float = 0.10

@export_group("Gravity & Jump")
@export var gravity: float = 0.405
@export var max_fall_speed: float = 5.5
@export var jump_velocity: float = -6.5
## Velocity multiplier applied to an upward jump on early release.
@export var jump_cut_multiplier: float = 0.45
## Gravity multiplier applied while |vy| is below apex_hang_threshold.
@export var apex_hang_gravity_multiplier: float = 0.60
@export var apex_hang_threshold: float = 1.0
@export var coyote_frames: int = 6
@export var jump_buffer_frames: int = 8
## Vertical launch, same pattern as jump_velocity/wall_jump_velocity - a
## hard assignment, unaffected by held direction.
@export var double_jump_velocity: float = -5.8
## Horizontal component of a double jump's redirect - ADDED to (not
## replacing) whatever velocity.x already is, in the held direction; 0
## when no direction is held (movement feel overhaul, rule 3). Additive
## rather than a hard assignment specifically so a double jump can never
## reverse a dash's direction outright (see the dash_speed clamp in
## PlayerMovement.process) - it can only fight momentum, same spirit as
## rule 2's air control.
@export var double_jump_horizontal_impulse: float = 3.5

@export_group("Dash")
## Nominal duration - no longer "how long dash owns the frame" (movement
## feel overhaul, rule 4a: dash is a decaying impulse subject to normal
## gravity/accel/friction from the moment it launches). Now purely a
## gating window: how long rule 1's instant ground turnaround stays
## suppressed in favor of rule 2-style gradual fighting (4c), how long
## before dash_cooldown starts counting, and how long the same-frame jump
## suppression (4d) can matter.
@export var dash_duration_frames: int = 12
@export var dash_speed: float = 7.0
## Frames after a dash's nominal duration ends before another can start,
## on top of needing dash_available (refilled separately by ground/wall
## contact).
@export var dash_cooldown_frames: int = 6
## Multiplier applied to the Y component only of a diagonal (nonzero X)
## upward dash's launch velocity - compensates for gravity now applying
## throughout the dash (rule 4a) so diagonal-up dashes retain their
## intended reach. Straight-up dashes (zero X) are NOT boosted - they were
## already strong enough before gravity applied continuously; gravity
## applying now is their correction, not something to compensate for.
@export var dash_diagonal_up_vertical_boost: float = 1.4

@export_group("Wall")
@export var wall_slide_max_fall_speed: float = 1.5
## Frames of zero gravity when first pressing into a touched wall, before
## it settles into a slide capped at wall_slide_max_fall_speed.
@export var wall_cling_frames: int = 13
## Max magnitude of velocity.y carried into a cling on entry - only
## relevant while falling or at rest (attached + rising uses normal
## gravity with no cling freeze at all, see _apply_gravity). Bounds how
## hard a fast downward catch gets held; entry speeds under the cap are
## untouched.
@export var wall_cling_entry_speed_cap: float = 4.0
## Wall jump while holding away from the wall - the strong one (more
## distance). Sign is resolved at jump time from which wall is touched.
@export var wall_jump_velocity: Vector2 = Vector2(4.0, -6.0)
## Wall jump with no directional input held - the middle tier: more
## distance than toward, less than away.
@export var wall_jump_neutral_velocity: Vector2 = Vector2(3.0, -6.5)
## Wall jump while holding INTO the wall - the weakest tier (movement feel
## overhaul, rule 5). Regrabbing the same wall afterward is intended to be
## possible with this one, just not instant - rules 2/3 (air control,
## double jump) govern how fast the player can actually turn around and
## drift back, not special-cased wall logic.
@export var wall_jump_toward_velocity: Vector2 = Vector2(1.5, -6.0)
## Frames of holding away (or neutral) before cling actually releases -
## the player stays attached (zero/capped gravity per the cling/slide
## rules) and a wall jump remains available throughout. Without this,
## letting go of "into the wall" drops attachment on the very next frame
## (on_wall_* only reads true while still actively moving into the wall -
## see TileCollision), making a wall-jump-away input frame-perfect.
@export var wall_detach_grace: int = 14
## Frames after actually losing wall contact during which a wall jump
## still fires - the wall-contact analogue of coyote_frames.
@export var wall_coyote_time: int = 6

@export_group("Collider")
@export var collider_size: Vector2 = Vector2(10, 16)
@export var tile_size: int = 16
## Milestone 4 tuning iteration 3: replaced the old corner-correction
## nudge system (see TileCollision) with this - the actual collision width
## is collider_size.x minus this margin on each side, narrower than the
## visual sprite. A few pixels of visual overlap on a jump-up corner or a
## ledge edge never registers as contact at all, so near-misses just pass
## through instead of needing a special-case nudge. Horizontal only;
## vertical collision uses the full collider_size.y unchanged.
@export var collision_width_margin_px: float = 2.0
