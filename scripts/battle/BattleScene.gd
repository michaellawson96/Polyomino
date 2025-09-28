extends Node2D
class_name BattleScene

const POLY_DATA := preload("res://scripts/PolyominoData.gd")

@export var battle_config: BattleConfig

var _board: Node = null
var _effects: Node = null
var _audio: Node = null
var _menu_root: Control = null
var _menu_open: bool = false
var _menu_mode: String = "" # "toggle" or "hold"
var _hold_active: bool = false
var _points_per_cell: int = 1
var _combo_cap: int = 3
var _in_chain: bool = false

@onready var enemy_bar: Control = $UIRoot/HUDRoot/RightHUD/EnemyRail/EnemyRailBar
@onready var enemy_label: Label = $UIRoot/HUDRoot/RightHUD/EnemyRail/EnemyLabel
@onready var player_bar: Control = $UIRoot/HUDRoot/RightHUD/PlayerRail/PlayerRailBar
@onready var player_label: Label = $UIRoot/HUDRoot/RightHUD/PlayerRail/PlayerLabel
@onready var ap_bar: Control = $UIRoot/HUDRoot/RightHUD/APArea/APBar
@onready var ap_label: Label = $UIRoot/HUDRoot/RightHUD/APArea/APLabel

var _hp_player: int = 20
var _hp_player_max: int = 20
var _hp_enemy: int = 20
var _hp_enemy_max: int = 20
var _ap: int = 0
var _ap_max: int = 500
var _combo: int = 0
var _combo_timer: Timer = null
var _gap_px: int = 8
var _bar_w: int = 0



func _ready() -> void:
	_board = $Board
	_effects = $Managers/EffectsManager
	_audio = $Managers/AudioManager
	_menu_root = $UIRoot/HUDRoot/MenuRoot
	_menu_set_visible(false)
	_ensure_menu_actions()
	if _effects != null and _effects.has_method("attach_board"):
		_effects.attach_board(_board)
	if _audio != null and _audio.has_method("attach_board"):
		_audio.attach_board(_board)
	if battle_config == null:
		var res: Resource = load("res://resources/default_battle_config.tres")
		if res is BattleConfig:
			battle_config = res
	var ids_pre: Array[String] = []
	for d in POLY_DATA.get_all():
		ids_pre.append(String(d["id"]))
	_apply_battle_palette_overrides_with_ids(ids_pre)
	_setup_board_via_mask()
	_apply_battle_palette_overrides()
	_load_points_config()
	call_deferred("_position_enemy_placeholder")
	_setup_combo_timer()
	_connect_board_hud_signals()
	_update_bars_geometry()
	_update_bars_values()

func _load_points_config() -> void:
	if battle_config != null:
		if "points_per_cell" in battle_config:
			_points_per_cell = max(1, int(battle_config.points_per_cell))
		if "combo_cap" in battle_config:
			_combo_cap = max(1, int(battle_config.combo_cap))


func _ensure_menu_actions() -> void:
	if not InputMap.has_action("battle_menu_toggle"):
		InputMap.add_action("battle_menu_toggle")
	if not InputMap.has_action("battle_menu_hold"):
		InputMap.add_action("battle_menu_hold")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	InputMap.action_erase_events("battle_menu_toggle")
	InputMap.action_add_event("battle_menu_toggle", esc)
	InputMap.action_erase_events("battle_menu_hold")
	var sh := InputEventKey.new()
	sh.physical_keycode = KEY_SHIFT
	InputMap.action_add_event("battle_menu_hold", sh)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("battle_menu_toggle"):
		if _menu_open:
			if _menu_mode == "toggle":
				_close_menu()
		else:
			if not _hold_active:
				_open_menu("toggle")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("battle_menu_hold"):
		_hold_active = true
		if not _menu_open:
			_open_menu("hold")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("battle_menu_hold"):
		_hold_active = false
		if _menu_open and _menu_mode == "hold":
			_close_menu()
		get_viewport().set_input_as_handled()
		return
	if _menu_open:
		get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
	if _menu_open:
		get_viewport().set_input_as_handled()

func _open_menu(mode: String) -> void:
	if _board != null and _board.has_method("is_line_clearing"):
		var lc : bool = _board.call("is_line_clearing")
		if lc == true:
			return
	_menu_mode = mode
	_menu_set_visible(true)
	_release_all_actions()
	if _board != null and _board.has_method("set_visuals_hidden"):
		_board.call("set_visuals_hidden", true)
	_set_board_paused(true)
	_menu_open = true
	print("[BATTLE] menu_open=true mode=", mode)

func _close_menu() -> void:
	_menu_set_visible(false)
	_release_all_actions()
	if _board != null and _board.has_method("set_visuals_hidden"):
		_board.call("set_visuals_hidden", false)
	_set_board_paused(false)
	_menu_open = false
	_menu_mode = ""
	print("[BATTLE] menu_open=false")

func _menu_set_visible(v: bool) -> void:
	if _menu_root != null:
		_menu_root.visible = v
		if v:
			_menu_root.grab_focus()
		else:
			_menu_root.release_focus()

func _set_board_paused(p: bool) -> void:
	if _board == null:
		return
	if _board.has_method("set_paused"):
		_board.call("set_paused", p)

func _release_all_actions() -> void:
	var acts := InputMap.get_actions()
	for a in acts:
		Input.action_release(a)
	var keys: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_UP, KEY_A, KEY_D, KEY_S, KEY_W]
	for k in keys:
		if Input.is_physical_key_pressed(k):
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			ev.pressed = false
			Input.parse_input_event(ev)

func _apply_battle_palette_overrides() -> void:
	var ids: Array[String] = []
	if _board != null and _board.has_method("get_bag_ids"):
		var v: Variant = _board.call("get_bag_ids")
		if v is Array:
			for x in v:
				ids.append(String(x))
	if ids.is_empty():
		for d in POLY_DATA.get_all():
			ids.append(String(d["id"]))
	_apply_battle_palette_overrides_with_ids(ids)

func _apply_battle_palette_overrides_with_ids(ids: Array[String]) -> void:
	var min_v: float = 0.35
	var max_v: float = 0.85
	var hue: Color = Color(0.20, 0.65, 0.95, 1.0)
	var forced: Dictionary = {}
	if battle_config != null:
		hue = battle_config.piece_base_color
		min_v = clamp(battle_config.shade_min, 0.0, 1.0)
		max_v = clamp(battle_config.shade_max, 0.0, 1.0)
		forced = battle_config.forced_piece_colors
	if max_v < min_v:
		var t: float = min_v
		min_v = max_v
		max_v = t
	var count: int = ids.size()
	if count < 1:
		count = 1
	var levels: Array[float] = _equidistant_shades(min_v, max_v, count)
	if typeof(Palette) != TYPE_NIL:
		Palette.set_runtime_piece_base_color(hue)
		Palette.set_runtime_shades(levels)
		Palette.set_runtime_shade_index_map(ids)
		if forced.size() > 0:
			Palette.set_runtime_forced_colors(forced)

func _setup_board_via_mask() -> void:
	if _board == null:
		return
	var ids: Array[String] = []
	for d in POLY_DATA.get_all():
		ids.append(String(d["id"]))
	var cell_size: int = 26
	var padding_cells: int = _compute_top_padding_cells()
	_board.position = Vector2(0, float(padding_cells * cell_size))
	var ok: bool = _board.setup_with_mask("res://masks/10x20.png", cell_size, ids, 0)
	if not ok:
		push_error("Board setup_with_mask failed")

func _compute_top_padding_cells() -> int:
	var max_y: int = 0
	for s in POLY_DATA.get_all():
		for off in s["blocks"]:
			max_y = max(max_y, int(off.y))
	return max_y + 1

func _equidistant_shades(min_v: float, max_v: float, n: int) -> Array[float]:
	var out: Array[float] = []
	if n <= 1:
		out.append(clamp((min_v + max_v) * 0.5, 0.0, 1.0))
		return out
	var step: float = (max_v - min_v) / float(n - 1)
	for i in range(n):
		out.append(clamp(min_v + step * float(i), 0.0, 1.0))
	return out

func _position_enemy_placeholder() -> void:
	var layer := $EnemyLayer as Node2D
	var sprite := $EnemyLayer/EnemySprite as Sprite2D
	if layer == null or sprite == null or _board == null:
		return
	var cell: int = 26
	if "cell_size" in _board:
		cell = int(_board.cell_size)
	var cols: int = 10
	if "board_width" in _board:
		cols = int(_board.board_width)
	var rows: int = 20
	if "board_height" in _board:
		rows = int(_board.board_height)

	var minx: int = cols
	var maxx: int = -1
	var miny: int = rows
	var maxy: int = -1
	if "board_mask" in _board and _board.board_mask != null:
		var bm = _board.board_mask
		for y in range(rows):
			for x in range(cols):
				if bm.is_playable(x, y):
					minx = min(minx, x)
					maxx = max(maxx, x)
					miny = min(miny, y)
					maxy = max(maxy, y)
	if maxx < minx or maxy < miny:
		minx = 0
		miny = 0
		maxx = cols - 1
		maxy = rows - 1

	var cx: float = (float(minx + maxx + 1) * 0.5) * float(cell)
	var cy: float = (float(miny + maxy + 1) * 0.5) * float(cell)
	layer.position = _board.position + Vector2(cx, cy)
	sprite.centered = true
	sprite.position = Vector2.ZERO

func _exit_tree() -> void:
	if typeof(Palette) != TYPE_NIL:
		Palette.clear_runtime_overrides()

func _update_bars_geometry() -> void:
	if _board == null:
		return
	var cell: int = 26
	if "cell_size" in _board:
		cell = int(_board.cell_size)
	var cols: int = 10
	if "board_width" in _board:
		cols = int(_board.board_width)
	var rows: int = 20
	if "board_height" in _board:
		rows = int(_board.board_height)
	_bar_w = max(12, cell)
	var board_px_w: int = cols * cell
	var board_px_h: int = rows * cell

	# Shift board right to make room for left rail + label
	var desired_left_margin: int = _bar_w * 5
	var current_left := int(_board.position.x)
	if current_left < desired_left_margin:
		_board.position.x = float(desired_left_margin)

	# Enemy rail (left of board), label to its left
	if enemy_bar and enemy_label:
		var ex: float = _board.position.x - float(_gap_px) - float(_bar_w)
		var ey: float = _board.position.y
		var label_w: float = float(enemy_label.size.x)
		enemy_label.position = Vector2(0, 0)
		enemy_bar.position = Vector2(label_w + 4.0, 0.0)
		var enemy_root := enemy_bar.get_parent() as Control
		if enemy_root:
			enemy_root.position = Vector2(ex - label_w - 4.0, ey)
		enemy_bar.custom_minimum_size = Vector2(float(_bar_w), float(board_px_h))
		enemy_bar.size = enemy_bar.custom_minimum_size

	# Player rail (right of board), label to its right
	if player_bar and player_label:
		var px: float = _board.position.x + float(board_px_w) + float(_gap_px)
		var py: float = _board.position.y
		player_bar.position = Vector2(0, 0)
		var player_root := player_bar.get_parent() as Control
		if player_root:
			player_root.position = Vector2(px, py)
		player_bar.custom_minimum_size = Vector2(float(_bar_w), float(board_px_h))
		player_bar.size = player_bar.custom_minimum_size
		player_label.position = Vector2(float(_bar_w) + 4.0, 0.0)

	# AP bar (bottom of board)
	if ap_bar and ap_label:
		var ax: float = _board.position.x
		var ay: float = _board.position.y + float(board_px_h) + float(_gap_px)
		var ap_root := ap_bar.get_parent() as Control
		if ap_root:
			ap_root.position = Vector2(ax, ay)
		ap_bar.position = Vector2(0, 0)
		ap_bar.custom_minimum_size = Vector2(float(board_px_w), float(max(10, int(cell * 0.5))))
		ap_bar.size = ap_bar.custom_minimum_size
		ap_label.position = Vector2(0.0, float(ap_bar.size.y + 4.0))

func _update_bars_values() -> void:
	if enemy_bar:
		enemy_bar.set("max_value", _hp_enemy_max)
		enemy_bar.set("segment_unit", 1)
		enemy_bar.set("value", _hp_enemy)
	if player_bar:
		player_bar.set("max_value", _hp_player_max)
		player_bar.set("segment_unit", 1)
		player_bar.set("value", _hp_player)
	if ap_bar:
		ap_bar.set("max_value", _ap_max)
		ap_bar.set("segment_unit", 10) # must divide _ap_max; adjust as needed
		ap_bar.set("value", _ap)
	if ap_label:
		ap_label.text = "ACTION POINTS " + str(_ap) + "/" + str(_ap_max)


func _connect_board_hud_signals() -> void:
	if _board == null:
		return
	if _board.has_signal("rows_cleared_blocks"):
		_board.connect("rows_cleared_blocks", Callable(self, "_on_rows_cleared_blocks"))
	if _board.has_signal("spawn_autoslide_started"):
		_board.connect("spawn_autoslide_started", Callable(self, "_on_spawn_autoslide_started"))


func _setup_combo_timer() -> void:
	_combo_timer = Timer.new()
	_combo_timer.one_shot = true
	_combo_timer.autostart = false
	_combo_timer.wait_time = 1.2
	add_child(_combo_timer)
	_combo_timer.connect("timeout", Callable(self, "_on_combo_timeout"))

func _on_combo_timeout() -> void:
	_combo = 0

func _increment_combo() -> void:
	if _combo <= 0:
		_combo = 1
	else:
		_combo += 1

func _reset_combo_timer() -> void:
	if _combo_timer != null:
		_combo_timer.start()

func _on_rows_cleared_blocks(_y: int, block_count: int, _span_count: int) -> void:
	_increment_combo()
	var award: int = max(0, block_count) * max(1, _combo)
	_ap = clamp(_ap + award, 0, _ap_max)
	_update_bars_values()
	_reset_combo_timer()

func _on_rows_cleared_blocks_points(_y: int, block_count: int, _span_count: int) -> void:
	if not _in_chain:
		_combo = 1
		_in_chain = true
	else:
		_combo = min(_combo + 1, _combo_cap)
	var blocks: int = max(0, block_count)
	var award: int = blocks * _points_per_cell * max(1, _combo)
	_add_points(award)

func _on_spawn_autoslide_started() -> void:
	_combo = 0
	_in_chain = false

func _add_points(delta: int) -> void:
	if delta == 0:
		return
	var before: int = _ap
	_ap = clamp(_ap + delta, 0, _ap_max)
	var applied: int = _ap - before
	if applied != 0:
		emit_signal("points_changed", _ap, applied)
		_update_bars_values()

func get_points() -> int:
	return _ap

func can_afford(cost: int) -> bool:
	return cost <= _ap

func spend(cost: int) -> bool:
	if cost <= 0:
		return true
	if cost > _ap:
		return false
	_ap -= cost
	emit_signal("points_changed", _ap, -cost)
	_update_bars_values()
	return true
