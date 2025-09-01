extends Control

@export var board_path: NodePath = ".."
@export var inner_line_width: float = 1.0
@export var border_line_width: float = 3.0
@export var grid_color: Color = Color(0.5, 0.5, 0.5)

@onready var board: Node = get_node(board_path)

var _contrast: float = 0.35
var _grid_line: Color = Color(1,1,1,0.18)

func _ready() -> void:
	refresh()
	if typeof(Settings) != TYPE_NIL:
		Settings.connect("reloaded", Callable(self, "_on_settings_reloaded"))
		Settings.connect("changed", Callable(self, "_on_settings_changed"))
	if typeof(Palette) != TYPE_NIL:
		Palette.connect("palette_changed", Callable(self, "_on_palette_changed"))
		_on_palette_changed(Palette.current())

func _draw() -> void:
	if board == null:
		return
	var cell: int = board.cell_size
	var cols: int = board.board_width
	var rows: int = board.board_height
	var color: Color = grid_color

	if "board_mask" in board and board.board_mask != null:
		_draw_masked_grid(cols, rows, cell, color)
	else:
		for x in range(cols + 1):
			var x_pos: float = float(x * cell) + 0.5
			draw_line(Vector2(x_pos, 0), Vector2(x_pos, rows * cell), color, inner_line_width)
		for y in range(rows + 1):
			var y_pos: float = float(y * cell) + 0.5
			draw_line(Vector2(0, y_pos), Vector2(cols * cell, y_pos), color, inner_line_width)

func _draw_masked_grid(cols: int, rows: int, cell: int, color: Color) -> void:
	# Vertical boundaries: iterate each boundary segment between row y and y+1 at column boundary x
	for x in range(cols + 1):
		var x_pos: float = float(x * cell) + 0.5
		for y in range(rows):
			var left_playable: bool = false
			var right_playable: bool = false
			if x == 0:
				right_playable = board.board_mask.is_playable(0, y)
			elif x == cols:
				left_playable = board.board_mask.is_playable(cols - 1, y)
			else:
				left_playable = board.board_mask.is_playable(x - 1, y)
				right_playable = board.board_mask.is_playable(x, y)
			if not (left_playable or right_playable):
				continue
			var y0: float = float(y * cell) + 0.5
			var y1: float = float((y + 1) * cell) + 0.5
			var w: float = border_line_width if (left_playable != right_playable) else inner_line_width
			draw_line(Vector2(x_pos, y0), Vector2(x_pos, y1), color, w)

	# Horizontal boundaries: iterate each boundary segment between col x and x+1 at row boundary y
	for y in range(rows + 1):
		var y_pos: float = float(y * cell) + 0.5
		for x in range(cols):
			var up_playable: bool = false
			var down_playable: bool = false
			if y == 0:
				down_playable = board.board_mask.is_playable(x, 0)
			elif y == rows:
				up_playable = board.board_mask.is_playable(x, rows - 1)
			else:
				up_playable = board.board_mask.is_playable(x, y - 1)
				down_playable = board.board_mask.is_playable(x, y)
			if not (up_playable or down_playable):
				continue
			var x0: float = float(x * cell) + 0.5
			var x1: float = float((x + 1) * cell) + 0.5
			var w2: float = border_line_width if (up_playable != down_playable) else inner_line_width
			draw_line(Vector2(x0, y_pos), Vector2(x1, y_pos), color, w2)

func refresh() -> void:
	if board == null:
		return
	_update_size()
	queue_redraw()

func _update_size() -> void:
	size = Vector2(board.board_width, board.board_height) * board.cell_size

func _on_settings_reloaded(_cfg) -> void:
	_apply_palette_and_settings()

func _on_settings_changed(_k: String, _v) -> void:
	_apply_palette_and_settings()

func _on_palette_changed(_p) -> void:
	_apply_palette_and_settings()

func _apply_palette_and_settings() -> void:
	if typeof(Palette) != TYPE_NIL and Palette.current() != null:
		_grid_line = Palette.current().grid_line
	else:
		_grid_line = grid_color

	if typeof(Settings) != TYPE_NIL and Settings.get_cfg() != null:
		_contrast = clamp(Settings.get_cfg().grid_contrast, 0.0, 1.0)
	else:
		_contrast = 1.0

	var c := _grid_line
	c.a = _contrast * _grid_line.a
	grid_color = c
	refresh()


