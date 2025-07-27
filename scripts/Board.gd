extends Node2D

@export var board_width: int = 10:
	set(value):
		board_width = value
		queue_redraw()
@export var board_height: int = 20:
	set(value):
		board_height = value
		queue_redraw()
@export var cell_size: int = 32:
	set(value):
		cell_size = value
		queue_redraw()

func _draw() -> void:
	var color = Color(0.5, 0.5, 0.5)
	for x in range(board_width):
		for y in range(board_height):
			var rect = Rect2(Vector2(x * cell_size, y * cell_size), Vector2(cell_size, cell_size))
			draw_rect(rect, color, false)

