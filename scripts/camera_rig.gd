## camera_rig.gd
## Spring-arm chase camera that follows the skier, orbits with mouse/right-stick,
## and auto-resets behind the skier after a short idle period.

extends Node3D

# ── Export params (editable in the Godot editor) ──────────────────────────────
@export var target         : NodePath          ## Path to the SkierController node
@export var arm_length     := 8.0              ## Default camera distance (m)
@export var arm_length_min := 3.0
@export var arm_length_max := 14.0
@export var follow_speed   := 6.0              ## Position follow lerp
@export var rotation_speed := 0.004            ## Mouse sensitivity (rad/px)
@export var auto_reset_delay := 3.0            ## Seconds idle before snapping behind skier
@export var fov            := 75.0

# ── Internal ──────────────────────────────────────────────────────────────────
@onready var spring_arm : SpringArm3D = $SpringArm3D
@onready var camera     : Camera3D    = $SpringArm3D/Camera3D

var _target_node : Node3D
var _yaw         := 0.0    # horizontal orbit angle (rad)
var _pitch       := -0.3   # vertical orbit angle (rad); negative = looking down
var _idle_timer  := 0.0
var _last_input  := Vector2.ZERO

const PITCH_MIN := -1.2
const PITCH_MAX :=  0.3


func _ready() -> void:
	_target_node = get_node_or_null(target)
	if camera:
		camera.fov = fov
	if spring_arm:
		spring_arm.spring_length = arm_length
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw   -= event.relative.x * rotation_speed
		_pitch  = clampf(_pitch - event.relative.y * rotation_speed, PITCH_MIN, PITCH_MAX)
		_idle_timer = 0.0


func _process(delta: float) -> void:
	if not _target_node:
		return

	# ── Gamepad right-stick orbit ─────────────────────────────────────────────
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > 0.15:
		_yaw   -= stick.x * rotation_speed * 60.0 * delta
		_pitch  = clampf(_pitch - stick.y * rotation_speed * 60.0 * delta, PITCH_MIN, PITCH_MAX)
		_idle_timer = 0.0
	else:
		_idle_timer += delta

	# ── Scroll wheel zoom ─────────────────────────────────────────────────────
	if Input.is_action_just_pressed("ui_scroll_up"):
		arm_length = clampf(arm_length - 1.0, arm_length_min, arm_length_max)
	elif Input.is_action_just_pressed("ui_scroll_down"):
		arm_length = clampf(arm_length + 1.0, arm_length_min, arm_length_max)
	if spring_arm:
		spring_arm.spring_length = lerp(spring_arm.spring_length, arm_length, 5.0 * delta)

	# ── Auto-reset behind skier ───────────────────────────────────────────────
	if _idle_timer >= auto_reset_delay and _target_node.velocity.length() > 2.0:
		var target_yaw := atan2(
			-_target_node.velocity.x,
			-_target_node.velocity.z
		)
		_yaw = lerp_angle(_yaw, target_yaw, 2.0 * delta)

	# ── Position follow ───────────────────────────────────────────────────────
	global_position = global_position.lerp(_target_node.global_position, follow_speed * delta)

	# ── Apply orbit rotation ──────────────────────────────────────────────────
	var rot := Basis.IDENTITY
	rot = rot.rotated(Vector3.UP, _yaw)
	rot = rot.rotated(rot.x, _pitch)
	global_transform.basis = rot
