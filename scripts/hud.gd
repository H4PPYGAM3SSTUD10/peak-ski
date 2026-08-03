## hud.gd
## Heads-up display: speed, timer, checkpoint count, countdown overlay,
## wipeout banner, finish banner, best-time display.

extends CanvasLayer

# ── Wired in scene ────────────────────────────────────────────────────────────
@onready var speed_label      : Label = $SpeedLabel
@onready var timer_label      : Label = $TimerLabel
@onready var checkpoint_label : Label = $CheckpointLabel
@onready var countdown_label  : Label = $CountdownLabel
@onready var banner           : Label = $Banner
@onready var best_time_label  : Label = $BestTimeLabel

var _race_running   := false
var _elapsed        := 0.0
var _total_checks   := 0
var _checks_hit     := 0


func _ready() -> void:
	_hide_banner()
	if countdown_label:
		countdown_label.visible = false
	if checkpoint_label:
		checkpoint_label.text = ""


func _process(delta: float) -> void:
	if _race_running:
		_elapsed += delta
		_update_timer(_elapsed)


# ── Signal receivers (connect from scene or RaceManager) ──────────────────────

func on_speed_changed(kmh: float) -> void:
	if speed_label:
		speed_label.text = "%.0f km/h" % kmh


func on_wiped_out() -> void:
	_show_banner("💥 WIPEOUT! — respawning…", Color(1, 0.3, 0.1))
	await get_tree().create_timer(2.0).timeout
	_hide_banner()


func on_countdown_tick(seconds_left: int) -> void:
	if countdown_label:
		countdown_label.visible = true
		countdown_label.text    = str(seconds_left) if seconds_left > 0 else "GO!"


func on_race_started() -> void:
	_race_running = true
	_elapsed      = 0.0
	_checks_hit   = 0
	if countdown_label:
		await get_tree().create_timer(0.6).timeout
		countdown_label.visible = false
	_update_checkpoint_display()
	if best_time_label:
		var best := GameState.get_best_time("mountain_run_01")
		best_time_label.text = ("Best: " + _fmt(best)) if best != INF else "Best: --:--"


func on_checkpoint_passed(index: int, total: int) -> void:
	_checks_hit   = index + 1
	_total_checks = total
	_update_checkpoint_display()


func on_race_finished(time: float, is_new_record: bool) -> void:
	_race_running = false
	var msg := "🏁 FINISH!  %s" % _fmt(time)
	if is_new_record:
		msg += "  🏆 NEW RECORD!"
	_show_banner(msg, Color(0.2, 1, 0.4) if is_new_record else Color(1, 1, 1))
	if best_time_label:
		best_time_label.text = "Best: " + _fmt(GameState.get_best_time("mountain_run_01"))


func on_race_reset() -> void:
	_race_running = false
	_elapsed      = 0.0
	_hide_banner()
	_update_timer(0.0)
	if checkpoint_label:
		checkpoint_label.text = ""


# ── Helpers ───────────────────────────────────────────────────────────────────

func _update_timer(t: float) -> void:
	if timer_label:
		timer_label.text = _fmt(t)


func _fmt(t: float) -> String:
	var m  := int(t) / 60
	var s  := int(t) % 60
	var ms := int(fmod(t, 1.0) * 100)
	return "%d:%02d.%02d" % [m, s, ms]


func _update_checkpoint_display() -> void:
	if checkpoint_label:
		checkpoint_label.text = "Checkpoints: %d / %d" % [_checks_hit, _total_checks]


func _show_banner(text: String, color: Color = Color.WHITE) -> void:
	if banner:
		banner.text            = text
		banner.modulate        = color
		banner.visible         = true


func _hide_banner() -> void:
	if banner:
		banner.visible = false
