## ski_physics.gd
## Handles all skiing physics: slope acceleration, carving, air drag,
## snow friction, jump force, and g-force / wipeout detection.
## Applied each physics frame by SkierController.

class_name SkiPhysics

# ── Tuning constants ──────────────────────────────────────────────────────────

## Gravity scale along the slope (m/s² effective, not world gravity).
## Lower than real physics = more forgiving, arcade feel.
const SLOPE_GRAVITY       := 14.0

## Maximum speed in m/s when tucked on a steep slope.
const MAX_SPEED           := 40.0

## Base snow friction deceleration (m/s²). Applied when grounded.
const SNOW_FRICTION       := 3.5

## Extra friction when the player edges (hold S).
const EDGE_FRICTION       := 10.0

## How sharply the skier can carve (rotation rate, rad/s).
const CARVE_RATE          := 2.8

## Speed at which carving becomes less effective (encourages tuck at speed).
const CARVE_SPEED_DAMPEN  := 0.55

## Air drag coefficient — applied as v² force opposite velocity.
const AIR_DRAG            := 0.012

## Upward impulse applied when the player presses Jump while grounded.
const JUMP_IMPULSE        := 7.5

## Landing g-force threshold above which the skier wipes out (m/s vertical).
## Keep generous so only truly bad landings punish.
const WIPEOUT_THRESHOLD   := 18.0

## How quickly the skier aligns to the terrain normal (lerp factor per frame).
const GROUND_ALIGN_SPEED  := 8.0

# ── State ─────────────────────────────────────────────────────────────────────

## Instantaneous velocity in world space (m/s).
var velocity      := Vector3.ZERO
var is_airborne   := false
var airborne_time := 0.0   # seconds since last ground contact
var prev_y_vel    := 0.0   # used to detect landing g-force

# ── Public API ────────────────────────────────────────────────────────────────

## Call each PhysicsProcess. Returns true if the skier just wiped out.
func update(
		delta: float,
		ground_normal: Vector3,   # surface normal at skier's feet (Vector3.UP if airborne)
		is_on_floor: bool,
		steer_input: float,       # -1 left … +1 right
		is_tucking: bool,
		is_edging: bool,
		wants_jump: bool
) -> bool:
	var wiped_out := false

	if is_on_floor:
		# ── Landing detection ────────────────────────────────────────────────
		if is_airborne:
			var impact := abs(prev_y_vel)
			if impact > WIPEOUT_THRESHOLD:
				wiped_out = true
			is_airborne   = false
			airborne_time = 0.0

		# ── Slope gravity ────────────────────────────────────────────────────
		# Project gravity onto the slope plane so the skier slides downhill.
		var down       := Vector3.DOWN
		var slope_down := down - ground_normal * down.dot(ground_normal)
		velocity += slope_down * SLOPE_GRAVITY * delta

		# ── Carving / steering ───────────────────────────────────────────────
		if steer_input != 0.0 and velocity.length() > 0.5:
			var speed_factor := 1.0 - clamp(velocity.length() / MAX_SPEED, 0.0, 1.0) * CARVE_SPEED_DAMPEN
			var carve        := steer_input * CARVE_RATE * speed_factor * delta
			# Rotate the velocity vector horizontally around the up-axis.
			velocity = velocity.rotated(ground_normal, -carve)

		# ── Friction ─────────────────────────────────────────────────────────
		var friction := SNOW_FRICTION + (EDGE_FRICTION if is_edging else 0.0)
		var speed    := velocity.length()
		if speed > 0.0:
			var decel := min(friction * delta, speed)
			velocity  -= velocity.normalized() * decel

		# ── Jump ─────────────────────────────────────────────────────────────
		if wants_jump:
			velocity.y   += JUMP_IMPULSE
			is_airborne   = true
			airborne_time = 0.0

	else:
		# ── Airborne ─────────────────────────────────────────────────────────
		is_airborne    = true
		airborne_time += delta
		# World gravity applied by CharacterBody3D; just track y velocity.

	# ── Air drag (always) ────────────────────────────────────────────────────
	var speed_sq := velocity.length_squared()
	if speed_sq > 0.0:
		velocity -= velocity.normalized() * AIR_DRAG * speed_sq * delta

	# ── Speed cap ────────────────────────────────────────────────────────────
	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED

	prev_y_vel = velocity.y
	return wiped_out


## Returns desired skier transform basis aligned to ground normal.
func ground_aligned_basis(current_basis: Basis, ground_normal: Vector3, delta: float) -> Basis:
	if ground_normal.is_equal_approx(Vector3.UP):
		return current_basis
	var new_up := current_basis.y.lerp(ground_normal, GROUND_ALIGN_SPEED * delta).normalized()
	var new_z  := current_basis.z
	var new_x  := new_up.cross(new_z).normalized()
	new_z      = new_x.cross(new_up).normalized()
	return Basis(new_x, new_up, new_z)


## Instantaneous speed in km/h for the HUD display.
func speed_kmh() -> float:
	return velocity.length() * 3.6
