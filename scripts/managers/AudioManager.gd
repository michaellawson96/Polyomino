extends Node
class_name AudioManager

signal bgm_state_changed(state: String)

@export var audio_set: BattleAudioSet
var _bgm_state: String = "none"

func _ready() -> void:
	if audio_set == null:
		var res := ResourceLoader.load("res://resources/audio/default_battle_audio.tres")
		if res != null and res is BattleAudioSet:
			audio_set = res

func attach_board(board: Node) -> void:
	if board == null or not is_instance_valid(board):
		return
	if board.has_signal("hard_drop"):
		board.connect("hard_drop", Callable(self, "_on_hard_drop"))
	if board.has_signal("piece_locked"):
		board.connect("piece_locked", Callable(self, "_on_piece_locked"))
	if board.has_signal("rows_cleared"):
		board.connect("rows_cleared", Callable(self, "_on_rows_cleared"))
	if board.has_signal("rubble_spawned"):
		board.connect("rubble_spawned", Callable(self, "_on_rubble_spawned"))
	if board.has_signal("critical_started"):
		board.connect("critical_started", Callable(self, "_on_critical_started"))

func _on_hard_drop(_dy: int) -> void:
	_play_sfx("move") # use move as a stand-in for hard drop

func _on_piece_locked(_pid: int, _lost: int) -> void:
	_play_sfx("lock")

func _on_rows_cleared(_y: int, _spans: int) -> void:
	_play_sfx("clear")

func _on_rubble_spawned(_count: int) -> void:
	# optional; keep a distinct log so we know it fired
	print("[AUDIO] play SFX: rubble")

func _on_critical_started(active: bool) -> void:
	if active:
		_switch_bgm("critical")
	else:
		_switch_bgm("battle")

func _play_sfx(kind: String) -> void:
	match kind:
		"move": print("[AUDIO] play SFX: move")
		"lock": print("[AUDIO] play SFX: lock")
		"clear": print("[AUDIO] play SFX: clear")
		"player_hit": print("[AUDIO] play SFX: player_hit")
		"enemy_hit": print("[AUDIO] play SFX: enemy_hit")
		"menu_enter": print("[AUDIO] play SFX: menu_enter")
		"menu_exit": print("[AUDIO] play SFX: menu_exit")
		"menu_select": print("[AUDIO] play SFX: menu_select")
		_: print("[AUDIO] play SFX: ", kind)

func _switch_bgm(state: String) -> void:
	if _bgm_state == state:
		return
	_bgm_state = state
	match state:
		"battle": print("[AUDIO] switch BGM: battle")
		"critical": print("[AUDIO] switch BGM: critical")
		"victory": print("[AUDIO] switch BGM: victory")
		"defeat": print("[AUDIO] switch BGM: defeat")
		_: print("[AUDIO] switch BGM: none")
	emit_signal("bgm_state_changed", _bgm_state)
