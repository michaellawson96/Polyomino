extends Control

@export var board_path: NodePath = ".."
@onready var board: Node = get_node(board_path)

func _ready() -> void:
	refresh()

func _draw() -> void:
	if board == null:
		return

	var color := Color(0.5, 0.5, 0.5)
	var width := 1.0
	var cols: int = board.board_width
	var rows: int = board.board_height
	var cell: int = board.cell_size

	# Draw vertical lines
	for x in range(cols + 1):
		var x_pos := float(x * cell) + 0.5
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, rows * cell), color, width)

	# Draw horizontal lines
	for y in range(rows + 1):
		var y_pos := float(y * cell) + 0.5
		draw_line(Vector2(0, y_pos), Vector2(cols * cell, y_pos), color, width)

func refresh() -> void:
	if board == null:
		return
	_update_size()
	queue_redraw()

func _update_size() -> void:
	size = Vector2(board.board_width, board.board_height) * board.cell_size
