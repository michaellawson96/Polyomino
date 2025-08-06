extends Node2D

# === Configuration ===
@export_range(1, 100) var board_width: int = 10:
	set(value):
		board_width = clamp(value, 1, 100)
		_refresh_deferred()

@export_range(1, 100) var board_height: int = 20:
	set(value):
		board_height = clamp(value, 1, 100)
		_refresh_deferred()

@export_range(1, 100) var cell_size: int = 32:
	set(value):
		cell_size = clamp(value, 1, 100)
		_update_cell_size_for_children()
		_refresh_deferred()

# === Internal References ===
@onready var grid_overlay := $GridOverlay
@onready var polyomino_container := $PolyominoContainer

# === Initialization ===
func _ready():
	_spawn_test_polyomino()
	_refresh_overlay()

# === Overlay Refresh ===
func _refresh_deferred() -> void:
	call_deferred("_refresh_overlay")

func _refresh_overlay() -> void:
	if is_instance_valid(grid_overlay):
		grid_overlay.refresh()

# === Propagation ===
func _update_cell_size_for_children() -> void:
	if not is_instance_valid(polyomino_container):
		return

	for poly in polyomino_container.get_children():
		if poly.has_method("set_cell_size"):
			poly.set_cell_size(cell_size)

			if poly.has_method("set_shape") and "blocks" in poly and "color" in poly:
				poly.set_shape(poly.blocks, poly.color)

	_refresh_overlay()

# === Test Code Only ===
@export var polyomino_scene: PackedScene = preload("res://prefabs/Polyomino.tscn")

func _spawn_test_polyomino() -> void:
	var shape_data = PolyominoData.get_shape("I")
	var poly = polyomino_scene.instantiate()
	polyomino_container.add_child(poly)
	poly.initialize(cell_size, Vector2(3, 2), shape_data.blocks, Color.GREEN)
	_update_cell_size_for_children()
# === End Test Code ===
