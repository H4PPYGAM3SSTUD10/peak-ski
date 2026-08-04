## race_manager.gd
## Manages a race challenge: countdown → running timer → checkpoints → finish.
## Attach to the RaceChallenge scene root.  Emits signals consumed by HUD.

extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal countdown_tick(seconds_left: int)
signal race_started
signal checkpoint_passed(index: int, total: int)
signal race_finished(time: float, is_new_record: bool)
signal race_reset

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


func _ready() -> void:
	# Fall back to finding the gates by node name so the scene works without
	# hand-authored NodePath exports.
	if not start_gate:
		start_gate = get_node_or_null("StartGate")
	if not finish_gate:
		finish_gate = get_node_or_null("FinishGate")
	if checkpoints.is_empty():
		var i := 0
		while true:
			var cp := get_node_or_null("Checkpoint%d" % i) as Area3D
			if not cp:
				break
			checkpoints.append(cp)
			i += 1

	if start_gate:
		start_gate.body_entered.connect(_on_start_entered)
	if finish_gate:
		finish_gate.body_entered.connect(_on_finish_entered)
	for idx in checkpoints.size():
		checkpoints[idx].body_entered.connect(_on_checkpoint_entered.bind(idx))


func _process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			_countdown_elapsed += delta
			var ticks_left := countdown_secs - int(_countdown_elapsed)
			emit_signal("countdown_tick", max(ticks_left, 0))
			if _countdown_elapsed >= countdown_secs:
				_state   = State.RUNNING
				_elapsed = 0.0
				emit_signal("race_started")

		State.RUNNING:
			_elapsed += delta


# ── Gate callbacks ────────────────────────────────────────────────────────────

func _on_start_entered(body: Node3D) -> void:
	if body.is_in_group("skier") and _state == State.IDLE:
		_state             = State.COUNTDOWN
		_countdown_elapsed = 0.0
		_next_checkpoint   = 0


func _on_checkpoint_entered(body: Node3D, index: int) -> void:
	if body.is_in_group("skier") and _state == State.RUNNING:
		if index == _next_checkpoint:
			_next_checkpoint += 1
			emit_signal("checkpoint_passed", index, checkpoints.size())


func _on_finish_entered(body: Node3D) -> void:
	if body.is_in_group("skier") and _state == State.RUNNING:
		# Only accept finish if all checkpoints have been hit.
		if _next_checkpoint < checkpoints.size():
			return
		_state = State.FINISHED
		var is_record := GameState.submit_time(challenge_id, _elapsed)
		emit_signal("race_finished", _elapsed, is_record)


# ── Public ────────────────────────────────────────────────────────────────────

func reset_race() -> void:
	_state             = State.IDLE
	_elapsed           = 0.0
	_countdown_elapsed = 0.0
	_next_checkpoint   = 0
	emit_signal("race_reset")


func get_elapsed() -> float:
	return _elapsed if _state == State.RUNNING else 0.0
