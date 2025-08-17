class_name Polyomino
extends Node2D

@onready var block_scene: PackedScene = preload("res://prefabs/Block.tscn")

var cell_size: int = 32
var grid_position: Vector2 = Vector2.ZERO
var block_offsets: Array[Vector2] = []
var block_color: Color = Color.WHITE
var origin_index: int = 0
var origin_marker: OriginMarker
var show_origin: bool = false

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
	_update_origin_marker()

func _draw() -> void:
	if block_offsets.is_empty(): return
	var o := get_origin_offset()
	var center := (o * cell_size) + Vector2(cell_size, cell_size) * 0.5
	var r := float(cell_size) * 0.22
	draw_circle(center, r, Color(1,1,1,0.85))
	draw_circle(center, r * 0.65, Color(0,0,0,0.85))

func get_origin_offset() -> Vector2:
	if block_offsets.is_empty(): return Vector2.ZERO
	return block_offsets[clamp(origin_index, 0, block_offsets.size() - 1)]

func cycle_origin() -> void:
	if block_offsets.is_empty(): return
	origin_index = (origin_index + 1) % block_offsets.size()
	_update_origin_marker()

func _ensure_origin_marker() -> void:
	if origin_marker == null:
		origin_marker = OriginMarker.new()
		add_child(origin_marker)
	else:
		remove_child(origin_marker)
		add_child(origin_marker)

func _update_origin_marker() -> void:
	if not show_origin:
		if origin_marker != null:
			origin_marker.queue_free()
			origin_marker = null
		return
	if block_offsets.is_empty():
		return
	_ensure_origin_marker()
	var o := get_origin_offset()
	origin_marker.position = (o * cell_size) + Vector2(cell_size, cell_size) * 0.5
	origin_marker.radius = float(cell_size) * 0.22
	origin_marker.queue_redraw()

func set_cell_size(new_size: int) -> void:
	cell_size = new_size
	_update_position()
	_redraw_blocks()
	queue_redraw()
	_update_origin_marker()

func set_shape(new_offsets: Array[Vector2], new_color: Color) -> void:
	block_offsets = new_offsets
	block_color = new_color
	_redraw_blocks()
	queue_redraw()
	_update_origin_marker()

func _update_position() -> void:
	position = (grid_position * cell_size).floor()

func _redraw_blocks() -> void:
	for child in get_children():
		if child != origin_marker:
			child.queue_free()
	for off in block_offsets:
		var block = block_scene.instantiate()
		add_child(block)
		block.position = off * cell_size
		block.set_visual(cell_size, block_color)
	if origin_marker != null:
		remove_child(origin_marker)
		add_child(origin_marker)

func is_polyomino() -> bool:
	return true

func get_block_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for off in block_offsets:
		var ox := int(off.x)
		var oy := int(off.y)
		cells.append(Vector2i(ox, oy))
	return cells

func preview_rotate_clockwise() -> Array[Vector2]:
	var o := get_origin_offset()
	var out: Array[Vector2] = []
	out.resize(block_offsets.size())
	for i in block_offsets.size():
		var rel: Vector2 = block_offsets[i] - o
		out[i] = Vector2(rel.y, -rel.x) + o
	return out

func preview_rotate_counterclockwise() -> Array[Vector2]:
	var o := get_origin_offset()
	var out: Array[Vector2] = []
	out.resize(block_offsets.size())
	for i in block_offsets.size():
		var rel: Vector2 = block_offsets[i] - o
		out[i] = Vector2(-rel.y, rel.x) + o
	return out
	
func preview_flip_horizontal() -> Array[Vector2]:
	var o := get_origin_offset()
	var out: Array[Vector2] = []
	out.resize(block_offsets.size())
	for i in block_offsets.size():
		var rel: Vector2 = block_offsets[i] - o
		out[i] = Vector2(-rel.x, rel.y) + o
	return out

func apply_offsets(new_offsets: Array[Vector2]) -> void:
	block_offsets = new_offsets
	_redraw_blocks()
	queue_redraw()
	_update_origin_marker()
