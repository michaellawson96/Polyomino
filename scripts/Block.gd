extends Node2D

func set_visual(cell_size: int, block_color: Color) -> void:
	var rect = $Rect
	rect.size = Vector2(cell_size, cell_size).floor()
	rect.position = Vector2.ZERO
	rect.color = block_color
