class_name Block
extends Node2D

@onready var color_rect: ColorRect = $Rect

var grid_cell: Vector2i = Vector2i.ZERO
var piece_id: int = 0 
var rubble: bool = false
var rubble_node: Node2D
var rubble_seed: int = 0
var rubble_jitter_px: float = 3.0
var rubble_opacity: float = 0.95
var rubble_color: Color = Color.WHITE
var _cell_size: int = 32
var shape_key: String = ""
var base_color: Color = Color.WHITE


func set_visual(cell_size: int, color: Color) -> void:
	_cell_size = cell_size
	if color_rect == null:
		push_error("Block node is missing a ColorRect child named 'Rect'")
		return
	base_color = color
	color_rect.size = Vector2(cell_size, cell_size).floor()
	color_rect.position = Vector2.ZERO
	color_rect.color = color
	if rubble and rubble_node != null:
		_build_rubble()

func set_grid_cell(v: Vector2i) -> void:
	grid_cell = v

func set_piece_id(v: int) -> void:
	piece_id = v

func set_rubble(enabled: bool, jitter_px: float, seed: int, opacity: float, color: Color) -> void:
	rubble = enabled
	rubble_jitter_px = jitter_px
	rubble_seed = seed
	rubble_opacity = opacity
	rubble_color = color
	if rubble:
		if rubble_node == null:
			rubble_node = Node2D.new()
			add_child(rubble_node)
		color_rect.visible = false
		_build_rubble()
	else:
		if rubble_node != null:
			rubble_node.queue_free()
			rubble_node = null
		color_rect.visible = true

func get_shrink_target() -> Node:
	if rubble and rubble_node != null:
		return rubble_node
	return color_rect

func _build_rubble() -> void:
	if rubble_node == null:
		return
	for c in rubble_node.get_children():
		c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rubble_seed)
	var cs := float(_cell_size)
	var j := rubble_jitter_px
	var center := Vector2(cs * 0.5, cs * 0.5)
	rubble_node.position = center
	var p1 := Polygon2D.new()
	var p2 := Polygon2D.new()
	var flip := ((grid_cell.x + grid_cell.y) & 1) == 0
	var a := Vector2(-cs*0.5, -cs*0.5)
	var b := Vector2( cs*0.5, -cs*0.5)
	var c := Vector2(-cs*0.5,  cs*0.5)
	var d := Vector2( cs*0.5,  cs*0.5)
	var j1 := Vector2(rng.randf_range(-j, j), rng.randf_range(-j, j))
	var j2 := Vector2(rng.randf_range(-j, j), rng.randf_range(-j, j))
	var mid := Vector2(rng.randf_range(-cs*0.08, cs*0.08), rng.randf_range(-cs*0.08, cs*0.08))
	var col := rubble_color
	col.a = rubble_opacity
	if flip:
		p1.polygon = PackedVector2Array([a, b, mid + j1])
		p2.polygon = PackedVector2Array([c, d, mid + j2])
	else:
		p1.polygon = PackedVector2Array([a, c, mid + j1])
		p2.polygon = PackedVector2Array([b, d, mid + j2])
	p1.color = col
	p2.color = col
	rubble_node.add_child(p1)
	rubble_node.add_child(p2)

func set_shape_key(key: String) -> void:
	shape_key = key

func apply_palette_color(color: Color) -> void:
	base_color = color
	if color_rect != null and not rubble:
		color_rect.color = color

func apply_rubble_opacity(a: float) -> void:
	if not rubble:
		return
	rubble_opacity = a
	_build_rubble()

