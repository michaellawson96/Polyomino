extends Node2D

@export var board_width: int = 10:
	set(value):
		board_width = value
		_call_deferred_refresh()

@export var board_height: int = 20:
	set(value):
		board_height = value
		_call_deferred_refresh()

@export var cell_size: int = 32:
	set(value):
		cell_size = value
		_propagate_cell_size()
		_call_deferred_refresh()

func _call_deferred_refresh():
	call_deferred("_refresh_overlay")

func _refresh_overlay():
	if has_node("GridOverlay"):
		$GridOverlay.refresh()

func _propagate_cell_size():
	if not has_node("PolyominoContainer"):
		return

	var container = $PolyominoContainer
	for child in container.get_children():
		if child.has_method("set_cell_size"):
			child.set_cell_size(cell_size)

			if child.has_method("set_shape") and "blocks" in child and "color" in child:
				child.set_shape(child.blocks, child.color)

	if has_node("GridOverlay"):
		$GridOverlay.refresh()
# TEST_CODE ONLY! REMOVE!
@export var polyomino_scene: PackedScene = preload("res://prefabs/Polyomino.tscn")

func _ready():
	var shape_data = PolyominoData.get_shape("I")
	var polyomino = polyomino_scene.instantiate()
	$PolyominoContainer.add_child(polyomino)

	polyomino.set_cell_size(cell_size)
	polyomino.set_grid_position(Vector2(3, 2))
	polyomino.set_shape(shape_data.blocks, Color.GREEN)


	$GridOverlay.refresh()
# TEST_CODE ONLY! REMOVE!

	var color = Color(0.5, 0.5, 0.5)
	var width = 1.0  # line thickness

	# Draw vertical lines
	for x in range(board_width + 1):
		var x_pos = float(x * cell_size) + 0.5
		draw_line(
			Vector2(x_pos, 0),
			Vector2(x_pos, board_height * cell_size),
			color,
			width
		)

	# Draw horizontal lines
	for y in range(board_height + 1):
		var y_pos = float(y * cell_size) + 0.5
		draw_line(
			Vector2(0, y_pos),
			Vector2(board_width * cell_size, y_pos),
			color,
			width
		)


