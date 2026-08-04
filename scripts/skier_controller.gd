## skier_controller.gd
## Drives the Skier scene: reads input, applies SkiPhysics, manages wipeout
## respawn, and emits signals consumed by HUD and RaceManager.

extends CharacterBody3D

# ── Signals ───────────────────────────────────────────────────────────────────
signal speed_changed(kmh: float)
signal wiped_out
signal landed(airborne_seconds: float)

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

const WIPEOUT_RECOVER_TIME := 2.5     # seconds before auto-respawn

## Below this world Y the skier has left the map — respawn instead of falling forever.
## The run-out sits at y ≈ -106, so -250 is safely clear of all real geometry.
const FALL_LIMIT_Y := -250.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_spawn_pos   = global_position
	_spawn_basis = global_transform.basis
	# Apply world gravity through CharacterBody3D's built-in handling.
	up_direction = Vector3.UP
	floor_stop_on_slope = false
	floor_max_angle     = deg_to_rad(70.0)


func _physics_process(delta: float) -> void:
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
	velocity = physics.velocity
	move_and_slide()
	physics.velocity = velocity   # sync back after collision response

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
	physics.velocity  = Vector3.ZERO
	physics.is_airborne = false
	if mesh:
		mesh.rotation = Vector3.ZERO


# ── Public helpers ────────────────────────────────────────────────────────────

## Set a new spawn point (called by RaceManager when hitting a checkpoint).
func set_spawn(pos: Vector3, basis: Basis) -> void:
	_spawn_pos   = pos
	_spawn_basis = basis
