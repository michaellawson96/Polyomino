extends Node2D

@export var board_node_path: NodePath = ".."  # default to parent
@onready var board: Node = get_node(board_node_path)

func _draw():
	if board == null:
		return
	var color = Color(0.5, 0.5, 0.5)
	var width = 1.0
	var w = board.board_width
	var h = board.board_height
	var cs = board.cell_size

	for x in range(w + 1):
		var x_pos = float(x * cs) + 0.5
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, h * cs), color, width)

	for y in range(h + 1):
		var y_pos = float(y * cs) + 0.5
		draw_line(Vector2(0, y_pos), Vector2(w * cs, y_pos), color, width)

func refresh():
	queue_redraw()
