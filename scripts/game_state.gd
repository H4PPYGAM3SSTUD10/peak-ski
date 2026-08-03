## game_state.gd
## Global singleton for persistent data (best times, settings).
## Add to AutoLoad as "GameState" in Project Settings.

extends Node

const SAVE_PATH := "user://peak_ski_save.cfg"

var best_times : Dictionary = {}   # challenge_id (String) -> best time (float seconds)


func _ready() -> void:
	load_data()


# ── Persistence ───────────────────────────────────────────────────────────────

func save_data() -> void:
	var cfg := ConfigFile.new()
	for id in best_times:
		cfg.set_value("best_times", id, best_times[id])
	cfg.save(SAVE_PATH)


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for id in cfg.get_section_keys("best_times"):
		best_times[id] = cfg.get_value("best_times", id)


# ── Best-time helpers ─────────────────────────────────────────────────────────

## Returns the best time for a challenge, or INF if not yet set.
func get_best_time(challenge_id: String) -> float:
	return best_times.get(challenge_id, INF)


## Updates the best time if new_time is better. Returns true if a new record.
func submit_time(challenge_id: String, new_time: float) -> bool:
	var current := get_best_time(challenge_id)
	if new_time < current:
		best_times[challenge_id] = new_time
		save_data()
		return true
	return false
