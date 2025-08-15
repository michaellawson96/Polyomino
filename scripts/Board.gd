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

# ⬇️ NEW: single authoritative speed (cells per second). Positive=down, Negative=up, Zero=stop.
@export_range(-10.0, 10.0, 0.1) var fall_rate: float = 1.0

# === Internal References ===
@onready var grid_overlay := $GridOverlay
@onready var polyomino_container := $PolyominoContainer

# === Tick state ===
var _accum_cells: float = 0.0	# accumulated cells (can be negative)

# === Initialization ===
func _ready():
	_spawn_test_polyomino()
	_refresh_overlay()

func _process(delta: float) -> void:
	if fall_rate == 0.0:
		return

	# accumulate cells directly (delta * cells/sec)
	_accum_cells += delta * fall_rate

	# Move down for each whole positive cell
	while _accum_cells >= 1.0:
		_accum_cells -= 1.0
		_step_fall(1)

	# Move up for each whole negative cell
	while _accum_cells <= -1.0:
		_accum_cells += 1.0
		_step_fall(-1)

func _step_fall(dir: int) -> void:
	for piece in get_polyomino_children():
		_move_piece(piece, dir)

func _move_piece(piece: Polyomino, dir: int) -> void:
	piece.grid_position.y += dir
	piece.position = (piece.grid_position * piece.cell_size).floor()

func get_polyomino_children() -> Array[Polyomino]:
	var pieces: Array[Polyomino] = []
	for c in polyomino_container.get_children():
		var p := c as Polyomino
		if p != null:
			pieces.append(p)
	return pieces

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

# === Input ===
func _unhandled_input(event: InputEvent) -> void:
	# Single-step per key press (no autorepeat here).
	if event.is_action_pressed("ui_left"):
		_nudge_active_piece(-1)
	elif event.is_action_pressed("ui_right"):
		_nudge_active_piece(1)

# Move the current falling piece horizontally by dir (-1 left, +1 right)
func _nudge_active_piece(dir: int) -> void:
	var piece := _get_active_polyomino()
	if piece == null:
		return
	# Only move if it stays within bounds
	if _can_move_within_bounds(piece, Vector2i(dir, 0)):
		piece.grid_position.x += dir
		piece.position = (piece.grid_position * piece.cell_size).floor()

# Returns the current active piece (first child in the container).
# If you later track "active" explicitly, update this method.
func _get_active_polyomino() -> Polyomino:
	# Prefer the last added child to feel like “topmost” is active
	var count := polyomino_container.get_child_count()
	for i in range(count - 1, -1, -1):
		var p := polyomino_container.get_child(i) as Polyomino
		if p != null:
			return p
	return null

# Returns true if moving by delta (in cells) keeps the piece within horizontal bounds
func _can_move_within_bounds(piece: Polyomino, delta: Vector2i) -> bool:
	var base_x := int(piece.grid_position.x)
	var base_y := int(piece.grid_position.y) # not used yet, but handy for future
	var dx := delta.x
	# Use piece.get_block_cells() if you added it; else iterate piece.block_offsets
	if piece.has_method("get_block_cells"):
		for cell in piece.get_block_cells():
			var nx := base_x + cell.x + dx
			if nx < 0 or nx >= board_width:
				return false
	else:
		for off in piece.block_offsets:
			var nx := base_x + int(off.x) + dx
			if nx < 0 or nx >= board_width:
				return false
	return true
