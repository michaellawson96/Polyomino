extends Node2D

# === Configuration ===
@export_range(1, 100) var board_width: int = 10:
	set(value):
		board_width = clamp(value, 1, 100)
		call_deferred("_coerce_all_pieces_into_bounds")  # <-- add this
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
	# Keep everything inside after visual/shape changes
	_coerce_all_pieces_into_bounds()  # <-- optional but nice
	_refresh_overlay()


# === Test Code Only ===
@export var polyomino_scene: PackedScene = preload("res://prefabs/Polyomino.tscn")

func _spawn_test_polyomino() -> void:
	var shape_data = PolyominoData.get_shape("I")
	var poly = polyomino_scene.instantiate()
	polyomino_container.add_child(poly)
	poly.initialize(cell_size, Vector2(3, 2), shape_data.blocks, Color.GREEN)
	_coerce_piece_into_horizontal_bounds(poly)  # <-- add this
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

# Compute allowed grid_position.x range for a piece so all blocks fit horizontally.
func _allowed_x_range_for_piece(piece: Polyomino) -> Vector2i:
	# Determine min/max horizontal offsets of the shape
	var off_min := 0
	var off_max := 0
	if piece.has_method("get_block_cells"):
		var first := true
		for cell in piece.get_block_cells():
			var x := int(cell.x)
			if first:
				off_min = x
				off_max = x
				first = false
			else:
				if x < off_min: off_min = x
				if x > off_max: off_max = x
	else:
		var first2 := true
		for off in piece.block_offsets:
			var x2 := int(off.x)
			if first2:
				off_min = x2
				off_max = x2
				first2 = false
			else:
				if x2 < off_min: off_min = x2
				if x2 > off_max: off_max = x2

	# To keep all blocks within [0, board_width-1]:
	# grid_x + off_min >= 0     -> grid_x >= -off_min
	# grid_x + off_max <= W-1   -> grid_x <= (W-1) - off_max
	var lower := -off_min
	var upper := (board_width - 1) - off_max
	return Vector2i(lower, upper)

# Shift the piece horizontally (if needed) so it fully fits in the board.
func _coerce_piece_into_horizontal_bounds(piece: Polyomino) -> void:
	var range := _allowed_x_range_for_piece(piece)
	var lower := range.x
	var upper := range.y

	# If the piece is wider than the board (no valid range), place it as far left as possible.
	if lower > upper:
		piece.grid_position.x = lower
	else:
		piece.grid_position.x = clamp(int(piece.grid_position.x), lower, upper)

	# Apply the visual position update
	piece.position = (piece.grid_position * piece.cell_size).floor()

# Apply coercion to every polyomino in the container (useful after a resize).
func _coerce_all_pieces_into_bounds() -> void:
	for p in get_polyomino_children():
		_coerce_piece_into_horizontal_bounds(p)
