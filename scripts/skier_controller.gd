## skier_controller.gd
## Drives the Skier scene: reads input, applies SkiPhysics, manages wipeout
## respawn, and emits signals consumed by HUD and RaceManager.

extends CharacterBody3D

# ── Signals ───────────────────────────────────────────────────────────────────
signal speed_changed(kmh: float)
signal wiped_out
signal landed(airborne_seconds: float)
signal respawned

# ── References ────────────────────────────────────────────────────────────────
@onready var mesh         : MeshInstance3D  = $SkierMesh
@onready var snow_spray   : GPUParticles3D  = $SnowSpray
@onready var audio        : AudioStreamPlayer3D = $AudioPlayer

# ── State ─────────────────────────────────────────────────────────────────────
var physics       := SkiPhysics.new()
var _spawn_pos    := Vector3.ZERO
var _spawn_basis  := Basis.IDENTITY
var _wipeout          := false
var _wipeout_timer    := 0.0
var _was_space_pressed := false
var _was_r_pressed     := false
var _needs_ground_snap := true

## While held at the start line during the countdown, the skier ignores input
## and stays put. RaceManager drives this.
var _frozen := false

const WIPEOUT_RECOVER_TIME := 2.5     # seconds before auto-respawn

## Below this world Y the skier has left the map — respawn instead of falling
## forever. Must stay well clear of the lowest real ground: the run-out sits at
## about y = -355, so anything above roughly -400 would teleport a skier who is
## simply doing the run properly.
const FALL_LIMIT_Y := -600.0

## How far above the snow the skier starts. Small enough that the landing never
## trips the g-force wipeout.
const SPAWN_HEIGHT := 0.5

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_spawn_basis = global_transform.basis
	# Apply world gravity through CharacterBody3D's built-in handling.
	up_direction = Vector3.UP
	floor_stop_on_slope = false
	floor_max_angle     = deg_to_rad(70.0)
	# Keep the skis glued to the snow over the terrain's facets and small rolls.
	# Without this the skier skips into the air on every bump, loses slope
	# gravity, and never builds speed. Still short enough that the jump kicker
	# (a ~5 m drop past the lip) launches properly.
	floor_snap_length   = 2.0


## Drop the skier onto whatever snow is directly below the spawn node, so the
## start is never a long fall regardless of where the node was placed in the
## scene. Runs once, on the first physics frame (the space state isn't
## queryable yet during _ready).
func _snap_to_ground() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 20.0,
		global_position + Vector3.DOWN * 2000.0
	)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit:
		global_position = hit.position + Vector3.UP * SPAWN_HEIGHT
	_spawn_pos = global_position


func _physics_process(delta: float) -> void:
	if _needs_ground_snap:
		_needs_ground_snap = false
		_snap_to_ground()
		return

	# Held at the start line: stay put, ignore input, but keep resting on the
	# snow so the release is from a settled position.
	if _frozen:
		velocity         = Vector3.ZERO
		physics.velocity = Vector3.ZERO
		move_and_slide()
		return

	if _wipeout:
		_handle_wipeout(delta)
		return

	# ── Read input (direct key checks — no input map required) ───────────────
	var steer      := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var is_tucking := Input.is_physical_key_pressed(KEY_W)
	var is_edging  := Input.is_physical_key_pressed(KEY_S)
	var wants_jump := Input.is_key_pressed(KEY_SPACE) and not _was_space_pressed and is_on_floor()
	_was_space_pressed = Input.is_key_pressed(KEY_SPACE)

	if Input.is_key_pressed(KEY_R) and not _was_r_pressed:
		respawn()
	_was_r_pressed = Input.is_key_pressed(KEY_R)
	if _wipeout:
		return

	# ── Fell off the world? Put the skier back at the top. ───────────────────
	if global_position.y < FALL_LIMIT_Y:
		respawn()
		return

	# ── Compute ground normal ─────────────────────────────────────────────────
	var ground_normal := get_floor_normal() if is_on_floor() else Vector3.UP

	# ── Update physics ────────────────────────────────────────────────────────
	var was_airborne := physics.is_airborne
	var air_time     := physics.airborne_time

	var wiped := physics.update(
		delta, ground_normal, is_on_floor(),
		steer, is_tucking, is_edging, wants_jump
	)

	if wiped:
		_start_wipeout()
		return

	if was_airborne and not physics.is_airborne:
		emit_signal("landed", air_time)

	# ── Move ──────────────────────────────────────────────────────────────────
	# SkiPhysics owns the velocity; move_and_slide is used to move the body and
	# resolve collisions. We deliberately do NOT take its velocity back on a
	# normal descent: it re-zeroes the into-floor component every frame, which
	# on a descending slope bleeds off ~2 m/s² and cancels out slope gravity.
	# Keeping the skis tangent to the snow is already handled by SkiPhysics.
	# A wall hit is real, though, so accept the result in that case.
	velocity = physics.velocity
	move_and_slide()
	if is_on_wall():
		physics.velocity = velocity

	# ── Orient skier to slope ─────────────────────────────────────────────────
	var new_basis := physics.ground_aligned_basis(global_transform.basis, ground_normal, delta)
	# Face the direction of travel.
	if velocity.length() > 0.2:
		var travel_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
		if travel_dir.length() > 0.01:
			new_basis = new_basis.looking_at(travel_dir) if false else new_basis
			# Simple yaw alignment:
			var angle := atan2(travel_dir.x, travel_dir.z)
			new_basis = Basis(Vector3.UP, angle)
	global_transform.basis = new_basis

	# ── Particles & audio ─────────────────────────────────────────────────────
	if snow_spray:
		snow_spray.emitting = is_on_floor() and velocity.length() > 2.0
	emit_signal("speed_changed", physics.speed_kmh())


# ── Wipeout ───────────────────────────────────────────────────────────────────

func _start_wipeout() -> void:
	_wipeout       = true
	_wipeout_timer = 0.0
	emit_signal("wiped_out")
	# Tumble the mesh visually (quick rotation).
	if mesh:
		mesh.rotate_z(PI * 0.5)


func _handle_wipeout(delta: float) -> void:
	_wipeout_timer += delta
	if _wipeout_timer >= WIPEOUT_RECOVER_TIME or Input.is_key_pressed(KEY_R):
		respawn()


func respawn() -> void:
	_wipeout = false
	global_position   = _spawn_pos
	global_transform.basis = _spawn_basis
	velocity          = Vector3.ZERO
	physics.velocity  = Vector3.ZERO
	physics.is_airborne = false
	physics.prev_velocity = Vector3.ZERO
	if mesh:
		mesh.rotation = Vector3.ZERO
	# Lets RaceManager put the run back to the start line and count down again.
	emit_signal("respawned")


## Hold / release the skier at the start line.
func set_frozen(value: bool) -> void:
	_frozen = value
	if value:
		velocity          = Vector3.ZERO
		physics.velocity  = Vector3.ZERO
		physics.is_airborne = false


# ── Public helpers ────────────────────────────────────────────────────────────

## Set a new spawn point (called by RaceManager when hitting a checkpoint).
func set_spawn(pos: Vector3, basis: Basis) -> void:
	_spawn_pos   = pos
	_spawn_basis = basis
