## race_manager.gd
## Manages a race challenge: countdown → running timer → checkpoints → finish.
## Attach to the RaceChallenge scene root.  Emits signals consumed by HUD.

extends Node3D

# ── Signals ───────────────────────────────────────────────────────────────────
signal countdown_tick(seconds_left: int)
signal race_started
signal checkpoint_passed(passed: int, total: int)
signal race_finished(time: float, is_new_record: bool)
signal race_missed_gates(missed: int, time: float)
signal race_reset(total_checkpoints: int)

# ── Exports ───────────────────────────────────────────────────────────────────
@export var challenge_id    := "mountain_run_01"
@export var countdown_secs  := 3

# ── References (set from scene) ───────────────────────────────────────────────
@export var start_gate       : Area3D
@export var finish_gate      : Area3D
@export var checkpoints      : Array[Area3D] = []

# ── State ─────────────────────────────────────────────────────────────────────
enum State { IDLE, COUNTDOWN, RUNNING, FINISHED }
var _state             : State = State.IDLE
var _elapsed           := 0.0
var _countdown_elapsed := 0.0
var _next_checkpoint   := 0
var _passed_count      := 0
var _needs_gate_snap   := true

## How far above the snow a gate's centre sits.
const GATE_HEIGHT := 3.5


func _ready() -> void:
	# Fall back to finding the gates by node name so the scene works without
	# hand-authored NodePath exports.
	if not start_gate:
		start_gate = get_node_or_null("StartGate") as Area3D
	if not finish_gate:
		finish_gate = get_node_or_null("FinishGate") as Area3D
	if checkpoints.is_empty():
		var i := 0
		while true:
			var cp := get_node_or_null("Checkpoint%d" % i) as Area3D
			if not cp:
				break
			checkpoints.append(cp)
			i += 1

	# The start gate is the visual start line only. The run is started by holding
	# the skier there and counting down (see _begin_countdown) rather than by
	# driving through it: a lateral drift past the gate, or a previous run left
	# in the FINISHED state, used to mean the timer simply never started and
	# there was no way to get it back.
	if finish_gate:
		finish_gate.body_entered.connect(_on_finish_entered)
	for idx in checkpoints.size():
		checkpoints[idx].body_entered.connect(_on_checkpoint_entered.bind(idx))


## Drop every gate onto the terrain on the first physics frame, so gate heights
## never have to be hand-authored to match the mountain.
func _snap_gates_to_ground() -> void:
	var space := get_world_3d().direct_space_state
	var gates : Array[Area3D] = []
	if start_gate:
		gates.append(start_gate)
	gates.append_array(checkpoints)
	if finish_gate:
		gates.append(finish_gate)

	for gate in gates:
		var from := Vector3(gate.global_position.x, 500.0, gate.global_position.z)
		var to   := Vector3(gate.global_position.x, -1000.0, gate.global_position.z)
		var hit  := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		if hit:
			gate.global_position = hit.position + Vector3.UP * GATE_HEIGHT


func _physics_process(_delta: float) -> void:
	if _needs_gate_snap:
		_needs_gate_snap = false
		_snap_gates_to_ground()
		# Gates are placed and the skier has settled — start the run.
		_begin_countdown()


## The skier, found by group so no scene wiring is needed.
func _skier() -> Node:
	return get_tree().get_first_node_in_group("skier")


## Put the run back to the start: hold the skier, reset counters, count down.
func _begin_countdown() -> void:
	_state             = State.COUNTDOWN
	_countdown_elapsed = 0.0
	_elapsed           = 0.0
	_next_checkpoint   = 0
	_passed_count      = 0
	var s := _skier()
	if s and s.has_method("set_frozen"):
		s.set_frozen(true)
	emit_signal("race_reset", checkpoints.size())


## Called when the skier respawns (R, or after a wipeout) so a fresh run always
## gets a fresh timer, whatever state the previous run ended in.
func restart_run() -> void:
	_begin_countdown()


func _process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			_countdown_elapsed += delta
			var ticks_left := countdown_secs - int(_countdown_elapsed)
			emit_signal("countdown_tick", max(ticks_left, 0))
			if _countdown_elapsed >= countdown_secs:
				_state   = State.RUNNING
				_elapsed = 0.0
				var s := _skier()
				if s and s.has_method("set_frozen"):
					s.set_frozen(false)
				emit_signal("race_started")

		State.RUNNING:
			_elapsed += delta


# ── Gate callbacks ────────────────────────────────────────────────────────────

func _on_checkpoint_entered(body: Node3D, index: int) -> void:
	if body.is_in_group("skier") and _state == State.RUNNING:
		# Accept any checkpoint at or ahead of the expected one. Requiring an
		# exact match meant a single missed gate silently ignored every gate
		# after it, with no feedback, and made the finish unreachable.
		if index >= _next_checkpoint:
			_next_checkpoint = index + 1
			_passed_count   += 1
			# Report how many gates were actually taken, not the gate's index —
			# the two differ as soon as a gate is skipped.
			emit_signal("checkpoint_passed", _passed_count, checkpoints.size())


func _on_finish_entered(body: Node3D) -> void:
	if body.is_in_group("skier") and _state == State.RUNNING:
		_state = State.FINISHED
		# A run that skipped gates still ends — it just doesn't set a time.
		# Silently ignoring the finish line left the player with no idea why
		# nothing happened.
		var missed := checkpoints.size() - _passed_count
		if missed > 0:
			emit_signal("race_missed_gates", missed, _elapsed)
			return
		var is_record := GameState.submit_time(challenge_id, _elapsed)
		emit_signal("race_finished", _elapsed, is_record)


# ── Public ────────────────────────────────────────────────────────────────────

func reset_race() -> void:
	_state             = State.IDLE
	_elapsed           = 0.0
	_countdown_elapsed = 0.0
	_next_checkpoint   = 0
	_passed_count      = 0
	emit_signal("race_reset", checkpoints.size())


func get_elapsed() -> float:
	return _elapsed if _state == State.RUNNING else 0.0
