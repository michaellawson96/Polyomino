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
	_position_enemy_placeholder()

func _setup_board_via_mask() -> void:
	if _board == null:
		return
	var ids: Array[String] = []
	for d in POLY_DATA.get_all():
		ids.append(String(d["id"]))
	var cell_size: int = 26
	var padding_cells := _compute_top_padding_cells()
	_board.position = Vector2(0, padding_cells * cell_size)
	var ok: bool = _board.setup_with_mask("res://masks/10x20.png", cell_size, ids, 0)
	if not ok:
		push_error("Board setup_with_mask failed")

func _compute_top_padding_cells() -> int:
	var max_y := 0
	for s in POLY_DATA.get_all():
		for off in s["blocks"]:
			max_y = max(max_y, int(off.y))
	return max_y + 1

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
	var cx: float = (float(minx + maxx + 1) * 0.5) * cell
	var cy: float = (float(miny + maxy + 1) * 0.5) * cell
	layer.position = _board.position + Vector2(cx, cy)
	sprite.position = Vector2.ZERO
