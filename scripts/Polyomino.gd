extends Node2D

@export var block_scene: PackedScene = preload("res://prefabs/Block.tscn")
var cell_size: int = 32

var grid_position: Vector2 = Vector2.ZERO

func set_grid_position(pos: Vector2) -> void:
	grid_position = pos
	position = (grid_position * cell_size).floor()


func set_cell_size(value: int) -> void:
	cell_size = value
	position = (grid_position * cell_size).floor()


var blocks: Array = []
var color: Color = Color.WHITE

func set_shape(block_offsets: Array, block_color: Color) -> void:
	blocks = block_offsets
	color = block_color

	# Remove old blocks
	for child in get_children():
		child.queue_free()

	for offset in blocks:
		var block = block_scene.instantiate()
		add_child(block)
		block.position = offset * cell_size
		block.set_visual(cell_size, color)
