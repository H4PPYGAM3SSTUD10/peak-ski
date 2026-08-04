## ski_physics.gd
## Handles all skiing physics: slope acceleration, carving, air drag,
## snow friction, jump force, and g-force / wipeout detection.
## Applied each physics frame by SkierController.

class_name SkiPhysics

# ── Tuning constants ──────────────────────────────────────────────────────────

## Gravity scale along the slope (m/s² effective, not world gravity).
## Exaggerated well past real physics — on the 20° piste this gives a pull of
## ~7.5 m/s², which combined with the drag below settles at a terminal speed of
## roughly 35 m/s (~125 km/h). Tuned for fun, not realism.
const SLOPE_GRAVITY       := 22.0

## Hard ceiling on speed, m/s.
const MAX_SPEED           := 42.0

## Base snow friction deceleration (m/s²). Applied when grounded.
## Kept low: friction is a constant decel, so a large value simply stops the
## skier dead at the bottom of the speed range instead of feeling like snow.
const SNOW_FRICTION       := 1.2

## Extra friction when the player edges (hold S).
const EDGE_FRICTION       := 12.0

## Drag multipliers while tucked (hold W) — less air resistance, less scrub.
const TUCK_DRAG_SCALE     := 0.45
const TUCK_FRICTION_SCALE := 0.8

## How sharply the skier can carve (rotation rate, rad/s).
const CARVE_RATE          := 2.8

## Speed at which carving becomes less effective (encourages tuck at speed).
const CARVE_SPEED_DAMPEN  := 0.55

## Air drag coefficient — applied as v² force opposite velocity. This is what
## actually caps the speed; see SLOPE_GRAVITY for the resulting terminal velocity.
const AIR_DRAG            := 0.005

## Impulse applied off the surface when the player presses Jump while grounded.
const JUMP_IMPULSE        := 6.5

## Landing threshold, in m/s measured PERPENDICULAR to the surface being landed
## on. Because it's perpendicular rather than vertical, a fast landing onto a
## matching slope is survivable and only genuinely flat-on impacts punish.
const WIPEOUT_THRESHOLD   := 22.0

## How quickly the skier aligns to the terrain normal (lerp factor per frame).
const GROUND_ALIGN_SPEED  := 8.0

# ── State ─────────────────────────────────────────────────────────────────────

## Instantaneous velocity in world space (m/s).
var velocity      := Vector3.ZERO
var is_airborne   := false
var airborne_time := 0.0        # seconds since last ground contact
var prev_velocity := Vector3.ZERO  # pre-collision velocity, for landing g-force

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
		# Impact is the closing speed PERPENDICULAR to the surface, taken from
		# the pre-collision velocity. Landing onto a slope that matches your
		# flight path is gentle; slamming flat from height is not.
		if is_airborne:
			var impact := absf(prev_velocity.dot(ground_normal))
			if impact > WIPEOUT_THRESHOLD:
				wiped_out = true
			is_airborne   = false
			airborne_time = 0.0

		# ── Stay on the snow ─────────────────────────────────────────────────
		# Remove any velocity heading through the surface. Without this, ground
		# that rises into your path (the valley walls, a terrain facet) acts as
		# a ramp and flings the skier into the air on an ordinary turn.
		velocity -= ground_normal * velocity.dot(ground_normal)

		# ── Slope gravity ────────────────────────────────────────────────────
		# Project gravity onto the slope plane so the skier slides downhill.
		var down       := Vector3.DOWN
		var slope_down := down - ground_normal * down.dot(ground_normal)
		velocity += slope_down * SLOPE_GRAVITY * delta

		# ── Carving / steering ───────────────────────────────────────────────
		if steer_input != 0.0 and velocity.length() > 0.5:
			var speed_factor := 1.0 - clampf(velocity.length() / MAX_SPEED, 0.0, 1.0) * CARVE_SPEED_DAMPEN
			var carve        := steer_input * CARVE_RATE * speed_factor * delta
			# Rotate the velocity vector horizontally around the up-axis.
			velocity = velocity.rotated(ground_normal, -carve)

		# ── Friction ─────────────────────────────────────────────────────────
		var friction := SNOW_FRICTION + (EDGE_FRICTION if is_edging else 0.0)
		if is_tucking:
			friction *= TUCK_FRICTION_SCALE
		var speed    := velocity.length()
		if speed > 0.0:
			var decel := minf(friction * delta, speed)
			velocity  -= velocity.normalized() * decel

		# ── Jump ─────────────────────────────────────────────────────────────
		# Applied after the projection above, off the surface you're standing on.
		if wants_jump:
			velocity     += ground_normal * JUMP_IMPULSE
			is_airborne   = true
			airborne_time = 0.0

	else:
		# ── Airborne ─────────────────────────────────────────────────────────
		is_airborne    = true
		airborne_time += delta
		velocity.y    -= 9.8 * delta

	# ── Air drag (always) ────────────────────────────────────────────────────
	var drag := AIR_DRAG * (TUCK_DRAG_SCALE if is_tucking else 1.0)
	var speed_sq := velocity.length_squared()
	if speed_sq > 0.0:
		velocity -= velocity.normalized() * drag * speed_sq * delta

	# ── Speed cap ────────────────────────────────────────────────────────────
	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED

	# Kept for the next frame's landing test: this is the velocity BEFORE
	# move_and_slide resolves the collision and cancels the normal component.
	prev_velocity = velocity
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
