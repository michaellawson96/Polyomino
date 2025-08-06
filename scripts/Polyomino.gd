extends Node2D

@onready var block_scene: PackedScene = preload("res://prefabs/Block.tscn")

var cell_size: int = 32
var grid_position: Vector2 = Vector2.ZERO
var block_offsets: Array = []
var block_color: Color = Color.WHITE

func initialize(
	new_cell_size: int,
	new_grid_position: Vector2,
	new_block_offsets: Array,
	new_color: Color
) -> void:
	cell_size = new_cell_size
	grid_position = new_grid_position
	block_offsets = new_block_offsets
	block_color = new_color

	_update_position()
	_redraw_blocks()

func set_cell_size(new_size: int) -> void:
	cell_size = new_size
	_update_position()
	_redraw_blocks()

func set_shape(new_offsets: Array, new_color: Color) -> void:
	block_offsets = new_offsets
	block_color = new_color
	_redraw_blocks()

func _update_position() -> void:
	position = (grid_position * cell_size).floor()

func _redraw_blocks() -> void:
	# Clear old blocks
	for child in get_children():
		child.queue_free()

	# Spawn new blocks
	for offset in block_offsets:
		var block = block_scene.instantiate()
		add_child(block)
		block.position = offset * cell_size
		block.set_visual(cell_size, block_color)
