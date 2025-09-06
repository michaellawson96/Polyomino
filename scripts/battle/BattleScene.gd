extends Node2D
class_name BattleScene

const POLY_DATA := preload("res://scripts/PolyominoData.gd")

@export var battle_config: BattleConfig

var _board: Node = null
var _effects: Node = null
var _audio: Node = null

func _ready() -> void:
	_board = $Board
	_effects = $Managers/EffectsManager
	_audio = $Managers/AudioManager
	if _effects != null and _effects.has_method("attach_board"):
		_effects.attach_board(_board)
	if _audio != null and _audio.has_method("attach_board"):
		_audio.attach_board(_board)
	_setup_board_via_mask()
	_apply_battle_palette_overrides()
	call_deferred("_position_enemy_placeholder")

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

func _apply_battle_palette_overrides() -> void:
	if _board == null:
		return
	var ids: Array[String] = []
	if _board.has_method("get_bag_ids"):
		var v: Variant = _board.call("get_bag_ids")
		if v is Array:
			for x in v:
				ids.append(String(x))
	if ids.is_empty():
		for d in POLY_DATA.get_all():
			ids.append(String(d["id"]))
	var min_v: float = 0.35
	var max_v: float = 0.85
	if battle_config != null:
		min_v = clamp(battle_config.shade_min, 0.0, 1.0)
		max_v = clamp(battle_config.shade_max, 0.0, 1.0)
	if max_v < min_v:
		var t: float = min_v
		min_v = max_v
		max_v = t
	var count: int = max(1, ids.size())
	var levels: Array[float] = _equidistant_shades(min_v, max_v, count)
	if battle_config != null:
		Palette.set_runtime_piece_base_color(battle_config.piece_base_color)
	else:
		Palette.set_runtime_piece_base_color(Color(0.20, 0.65, 0.95, 1.0))
	Palette.set_runtime_shades(levels)
	Palette.set_runtime_shade_index_map(ids)

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
