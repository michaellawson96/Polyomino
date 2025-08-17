@tool
extends Node2D

enum GameState { PRECONTROL_AUTOSLIDE, ACTIVE_CONTROLLED, LINE_CLEAR }

const POLY_DATA := preload("res://scripts/PolyominoData.gd")

@export_range(1, 100) var board_width: int = 10:
	set(value):
		board_width = clamp(value, 1, 100)
		call_deferred("_coerce_all_pieces_into_bounds")
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
@export_range(-10.0, 10.0, 0.1) var fall_rate: float = 1.0
@export_range(1.0, 20.0, 0.5) var soft_drop_multiplier: float = 5.0
@export var polyomino_scene: PackedScene = preload("res://prefabs/Polyomino.tscn")
@export var conveyor_step_ms: int = 150
@export var spawn_top_row: int = 0
@export var hold_start_delay_ms: int = 200
@export var hold_repeat_interval_ms: int = 40
@export var most_recent_press_wins: bool = true


@onready var inactive_container := $InactiveContainer
@onready var grid_overlay := $GridOverlay
@onready var polyomino_container := $PolyominoContainer

var _occupied: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var default_spawn_id: String = "I3"
var _accum_cells: float = 0.0
var _state: int = GameState.ACTIVE_CONTROLLED
var _conveyor_accum_ms: int = 0
var _fully_on_grid_once: bool = false
var _precreated_next_id: String = ""
var _hold_left: bool = false
var _hold_right: bool = false
var _hold_dir: int = 0
var _hold_timer_ms: int = -1


func _ready():
	if Engine.is_editor_hint():
		return
	if inactive_container == null:
		inactive_container = Node2D.new()
		inactive_container.name = "InactiveContainer"
		add_child(inactive_container)
	_rng.randomize()
	_spawn_from_id(_pick_random_id())
	_refresh_overlay()

func _process(delta: float) -> void:
	if _state == GameState.PRECONTROL_AUTOSLIDE:
		_update_precontrol(delta)
		return
	if _state == GameState.ACTIVE_CONTROLLED and _hold_dir != 0 and (_hold_left or _hold_right):
		_hold_timer_ms -= int(delta * 1000.0)
		while _hold_timer_ms <= 0:
			_try_nudge_active(_hold_dir)
			_hold_timer_ms += hold_repeat_interval_ms
	if fall_rate == 0.0:
		return
	var rate := fall_rate
	if _state == GameState.ACTIVE_CONTROLLED and Input.is_action_pressed("ui_down"):
		rate *= soft_drop_multiplier
	_accum_cells += delta * rate
	while _accum_cells >= 1.0:
		_accum_cells -= 1.0
		_step_fall(1)
	while _accum_cells <= -1.0:
		_accum_cells += 1.0
		_step_fall(-1)

func _unhandled_input(event: InputEvent) -> void:
	if _state != GameState.ACTIVE_CONTROLLED:
		return
	if event.is_action_pressed("hard_drop"):
		_hard_drop_active()
		return
	if event.is_action_pressed("ui_left"):
		_hold_left = true
		if most_recent_press_wins or _hold_dir == 0:
			_hold_dir = -1
		_try_nudge_active(-1)
		_hold_timer_ms = hold_start_delay_ms
	if event.is_action_pressed("ui_right"):
		_hold_right = true
		if most_recent_press_wins or _hold_dir == 0:
			_hold_dir = 1
		_try_nudge_active(1)
		_hold_timer_ms = hold_start_delay_ms
	if event.is_action_released("ui_left"):
		_hold_left = false
		if _hold_right:
			_hold_dir = 1
			if _hold_timer_ms < 0:
				_hold_timer_ms = hold_repeat_interval_ms
		else:
			_hold_dir = 0
			_hold_timer_ms = -1
	if event.is_action_released("ui_right"):
		_hold_right = false
		if _hold_left:
			_hold_dir = -1
			if _hold_timer_ms < 0:
				_hold_timer_ms = hold_repeat_interval_ms
		else:
			_hold_dir = 0
			_hold_timer_ms = -1
	if event.is_action_pressed("rotate_cw"):
		_rotate_active_piece_cw_no_kick()
	elif event.is_action_pressed("rotate_ccw"):
		_rotate_active_piece_ccw_no_kick()
	elif event.is_action_pressed("flip_h"):
		_flip_active_piece_horizontal_no_kick()
	elif event.is_action_pressed("origin_next"):
		var p := _get_active_polyomino()
		if p != null:
			p.cycle_origin()

func _update_precontrol(delta: float) -> void:
	var piece := _get_active_polyomino()
	if piece == null:
		return
	if Input.is_action_just_pressed("ui_down"):
		_grant_control()
		return
	_conveyor_accum_ms += int(delta * 1000.0)
	while _conveyor_accum_ms >= conveyor_step_ms:
		_conveyor_accum_ms -= conveyor_step_ms
		if not _is_fully_inside_left_wall(piece):
			piece.grid_position.x += 1
			piece.position = (piece.grid_position * piece.cell_size).floor()
			if _is_fully_inside_left_wall(piece) and not _fully_on_grid_once:
				_snap_piece_to_top_lane(piece)
				_fully_on_grid_once = true
				if _precreated_next_id == "":
					_precreated_next_id = _pick_random_id()
			return
		if _can_step_right_in_top_lane(piece):
			piece.grid_position.x += 1
			piece.position = (piece.grid_position * piece.cell_size).floor()
		else:
			_grant_control()
			return

func _grant_control() -> void:
	_state = GameState.ACTIVE_CONTROLLED
	_hold_left = false
	_hold_right = false
	_hold_dir = 0
	_hold_timer_ms = -1
	if _precreated_next_id == "":
		_precreated_next_id = _pick_random_id()


func _step_fall(dir: int) -> void:
	for piece in get_polyomino_children():
		if dir > 0:
			if _would_collide(piece, Vector2i(0, 1)):
				_lock_piece(piece)
			else:
				_move_piece(piece, 1)
		elif dir < 0:
			if not _would_collide(piece, Vector2i(0, -1)):
				_move_piece(piece, -1)

func _move_piece(piece: Polyomino, dir: int) -> void:
	piece.grid_position.y += dir
	piece.position = (piece.grid_position * piece.cell_size).floor()

func _nudge_active_piece(dir: int) -> void:
	var piece := _get_active_polyomino()
	if piece == null: return
	if not _would_collide(piece, Vector2i(dir, 0)):
		piece.grid_position.x += dir
		piece.position = (piece.grid_position * piece.cell_size).floor()

func _try_nudge_active(dir: int) -> bool:
	var piece := _get_active_polyomino()
	if piece == null:
		return false
	if _would_collide(piece, Vector2i(dir, 0)):
		return false
	piece.grid_position.x += dir
	piece.position = (piece.grid_position * piece.cell_size).floor()
	return true


func _get_active_polyomino() -> Polyomino:
	var count := polyomino_container.get_child_count()
	for i in range(count - 1, -1, -1):
		var p := polyomino_container.get_child(i) as Polyomino
		if p != null:
			return p
	return null

func get_polyomino_children() -> Array[Polyomino]:
	var pieces: Array[Polyomino] = []
	for c in polyomino_container.get_children():
		var p := c as Polyomino
		if p != null:
			pieces.append(p)
	return pieces

func _rotate_active_piece_cw_no_kick() -> void:
	var p := _get_active_polyomino()
	if p == null:
		return
	var preview: Array[Vector2] = p.preview_rotate_clockwise()
	if _can_place_orientation(p, preview):
		p.apply_offsets(preview)

func _rotate_active_piece_ccw_no_kick() -> void:
	var p := _get_active_polyomino()
	if p == null:
		return
	var preview: Array[Vector2] = p.preview_rotate_counterclockwise()
	if _can_place_orientation(p, preview):
		p.apply_offsets(preview)

func _flip_active_piece_horizontal_no_kick() -> void:
	var p := _get_active_polyomino()
	if p == null:
		return
	var preview: Array[Vector2] = p.preview_flip_horizontal()
	if _can_place_orientation(p, preview):
		p.apply_offsets(preview)

func _can_place_orientation(piece: Polyomino, offsets: Array[Vector2]) -> bool:
	var base_x := int(piece.grid_position.x)
	var base_y := int(piece.grid_position.y)
	for off in offsets:
		var nx := base_x + int(off.x)
		var ny := base_y + int(off.y)
		if nx < 0 or nx >= board_width:
			return false
		if ny < 0 or ny >= board_height:
			return false
		if _occupied.has(Vector2i(nx, ny)):
			return false
	return true


func _piece_cells(piece: Polyomino) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var base := Vector2i(int(piece.grid_position.x), int(piece.grid_position.y))
	for off in piece.block_offsets:
		cells.append(base + Vector2i(int(off.x), int(off.y)))
	return cells

func _allowed_x_range_for_piece(piece: Polyomino) -> Vector2i:
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
	var lower := -off_min
	var upper := (board_width - 1) - off_max
	return Vector2i(lower, upper)

func _coerce_piece_into_horizontal_bounds(piece: Polyomino) -> void:
	var allowed_range := _allowed_x_range_for_piece(piece)
	var lower := allowed_range.x
	var upper := allowed_range.y
	if lower > upper:
		piece.grid_position.x = lower
	else:
		piece.grid_position.x = clamp(int(piece.grid_position.x), lower, upper)
	piece.position = (piece.grid_position * piece.cell_size).floor()

func _coerce_all_pieces_into_bounds() -> void:
	for p in get_polyomino_children():
		_coerce_piece_into_horizontal_bounds(p)

func _spawn_from_id(id: String, use_precontrol: bool = true) -> void:
	var s: Dictionary = POLY_DATA.get_shape_with_color(id)
	if s.is_empty():
		push_warning("Unknown shape id: %s" % id)
		return
	var poly: Polyomino = polyomino_scene.instantiate()
	polyomino_container.add_child(poly)
	var blocks: Array[Vector2] = POLY_DATA.get_blocks(id)
	var color: Color = s["color"]
	var min_x := 999999
	var max_y := -999999
	for off in blocks:
		min_x = min(min_x, int(off.x))
		max_y = max(max_y, int(off.y))
	var start_x := -min_x - 1
	var start_y := -max_y - 1
	poly.initialize(cell_size, Vector2(start_x, start_y), blocks, color)
	poly.show_origin = true
	poly._update_origin_marker()
	_update_cell_size_for_children()
	if use_precontrol:
		_state = GameState.PRECONTROL_AUTOSLIDE
		_conveyor_accum_ms = 0
		_fully_on_grid_once = false
		_precreated_next_id = ""
		_hold_left = false
		_hold_right = false
		_hold_dir = 0
		_hold_timer_ms = -1
	else:
		_state = GameState.ACTIVE_CONTROLLED

func _get_property_list() -> Array:
	var list: Array = []
	var ids: Array[String] = []
	var shapes: Array = POLY_DATA.get_all()
	for s in shapes:
		if s.has("id"):
			ids.append(String(s["id"]))
	ids.sort()
	if ids.is_empty():
		ids = ["M1","D2","I3","L3","F5","X5","W5","T5","U5","V5","P5","N5","Y5","Z5","L5","I5"]
	list.append({
		"name": "default_spawn_id",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(ids)
	})
	return list

func _all_shape_ids() -> Array[String]:
	var ids: Array[String] = []
	for s in POLY_DATA.get_all():
		if s.has("id"):
			ids.append(String(s["id"]))
	return ids

func _pick_random_id() -> String:
	var ids := _all_shape_ids()
	if ids.is_empty():
		return default_spawn_id
	return ids[_rng.randi_range(0, ids.size() - 1)]

func _would_collide(piece: Polyomino, delta: Vector2i) -> bool:
	var base_x := int(piece.grid_position.x)
	var base_y := int(piece.grid_position.y)
	for off in piece.block_offsets:
		var nx := base_x + int(off.x) + delta.x
		var ny := base_y + int(off.y) + delta.y
		if nx < 0 or nx >= board_width:
			return true
		if ny >= board_height:
			return true
		if ny >= 0 and _occupied.has(Vector2i(nx, ny)):
			return true
	return false

func _is_fully_inside_left_wall(piece: Polyomino) -> bool:
	var base_x := int(piece.grid_position.x)
	for off in piece.block_offsets:
		if base_x + int(off.x) < 0:
			return false
	return true

func _snap_piece_to_top_lane(piece: Polyomino) -> void:
	var min_local_y := 999999
	for off in piece.block_offsets:
		min_local_y = min(min_local_y, int(off.y))
	piece.grid_position.y = spawn_top_row - min_local_y
	piece.position = (piece.grid_position * piece.cell_size).floor()
	
func _can_step_right_in_top_lane(piece: Polyomino) -> bool:
	var base_x := int(piece.grid_position.x)
	for off in piece.block_offsets:
		var nx := base_x + 1 + int(off.x)
		if nx >= board_width:
			return false
	return true

func _compute_hard_drop_delta(piece: Polyomino) -> int:
	var dy := 0
	while not _would_collide(piece, Vector2i(0, dy + 1)):
		dy += 1
	return dy

func _hard_drop_active() -> void:
	if _state != GameState.ACTIVE_CONTROLLED:
		return
	var p := _get_active_polyomino()
	if p == null:
		return
	var dy := _compute_hard_drop_delta(p)
	if dy > 0:
		p.grid_position.y += dy
		p.position = (p.grid_position * p.cell_size).floor()
	_lock_piece(p)


func _lock_piece(piece: Polyomino) -> void:
	for c in _piece_cells(piece):
		_occupied[c] = true
	piece.show_origin = false
	piece._update_origin_marker()
	if piece.get_parent() != inactive_container:
		piece.get_parent().remove_child(piece)
		inactive_container.add_child(piece)
	var next_id := _precreated_next_id if _precreated_next_id != "" else _pick_random_id()
	_precreated_next_id = ""
	_spawn_from_id(next_id, true)

func _refresh_deferred() -> void:
	call_deferred("_refresh_overlay")

func _refresh_overlay() -> void:
	if is_instance_valid(grid_overlay):
		grid_overlay.refresh()

func _update_cell_size_for_children() -> void:
	if not is_instance_valid(polyomino_container):
		return
	for poly in polyomino_container.get_children():
		if poly.has_method("set_cell_size"):
			poly.set_cell_size(cell_size)
			if poly.has_method("set_shape") and "blocks" in poly and "color" in poly:
				poly.set_shape(poly.blocks, poly.color)
	_coerce_all_pieces_into_bounds()
	_refresh_overlay()
