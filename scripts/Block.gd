class_name Block
extends Node2D

@onready var color_rect: ColorRect = $Rect

func set_visual(cell_size: int, color: Color) -> void:
	if color_rect == null:
		push_error("Block node is missing a ColorRect child named 'Rect'")
		return
	color_rect.size = Vector2(cell_size, cell_size).floor()
	color_rect.position = Vector2.ZERO
	color_rect.color = color
