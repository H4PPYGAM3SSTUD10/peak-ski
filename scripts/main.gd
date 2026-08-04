## main.gd
## Wires the scene together: connects the skier and the race manager to the HUD.
##
## Done in code rather than as editor-authored connections in Main.tscn so the
## wiring is visible, reviewable, and cannot be silently lost when the scene is
## re-saved.

extends Node3D

@onready var skier : Node = $Skier
@onready var race  : Node = $RaceChallenge
@onready var hud   : Node = $HUD


func _ready() -> void:
	_connect(skier, "speed_changed",     hud, "on_speed_changed")
	_connect(skier, "wiped_out",         hud, "on_wiped_out")

	_connect(race,  "countdown_tick",    hud, "on_countdown_tick")
	_connect(race,  "race_started",      hud, "on_race_started")
	_connect(race,  "checkpoint_passed", hud, "on_checkpoint_passed")
	_connect(race,  "race_finished",     hud, "on_race_finished")
	_connect(race,  "race_missed_gates", hud, "on_race_missed_gates")
	_connect(race,  "race_reset",        hud, "on_race_reset")


## Connect one signal, complaining loudly if either end is missing rather than
## failing silently the way an unwired editor connection does.
func _connect(from: Node, signal_name: String, to: Node, method: String) -> void:
	if not from or not to:
		push_error("Cannot wire %s: missing node" % signal_name)
		return
	if not from.has_signal(signal_name):
		push_error("%s has no signal '%s'" % [from.name, signal_name])
		return
	if not to.has_method(method):
		push_error("%s has no method '%s'" % [to.name, method])
		return
	from.connect(signal_name, Callable(to, method))
