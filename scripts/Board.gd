@tool
extends Node2D

enum GameState { PRECONTROL_AUTOSLIDE, ACTIVE_CONTROLLED, LINE_CLEAR, PAUSED }

const POLY_DATA := preload("res://scripts/PolyominoData.gd")
const GhostOutlineScript := preload("res://scripts/GhostOutline.gd")
const BagServiceScript:=preload("res://scripts/BagService.gd")
const PROMOTE_QUEUED_SENTINEL := "__PROMOTE_QUEUED__"
const BoardMaskScript:=preload("res://scripts/BoardMask.gd")
const ClearCollapseMod:=preload("res://scripts/logic/ClearCollapse.gd")
const PlacementRulesMod:=preload("res://scripts/logic/PlacementRules.gd")
const SpawnLaneMod:=preload("res://scripts/logic/SpawnLane.gd")

signal next_preview(ids: Array[String])
signal hard_drop(dy: int)
signal piece_locked(pid: int, lost_blocks: int)
signal rows_cleared(y: int, span_count: int)
signal rubble_spawned(count: int)
signal critical_started(active: bool)
signal bag_reconfig_ok(ids: Array[String])
signal bag_reconfig_fail(ids: Array[String])


@export_range(1, 100) var board_width: int = 10:
	set(value):
		board_width = clamp(value, 1, 100)
		_call_mask_resize()
		call_deferred("_coerce_all_pieces_into_bounds")
		_refresh_deferred()
@export_range(1, 100) var board_height: int = 20:
	set(value):
		board_height = clamp(value, 1, 100)
		_call_mask_resize()
		_refresh_deferred()
@export_range(1, 100) var cell_size: int = 32:
	set(value):
		cell_size = clamp(value, 1, 100)
		_update_cell_size_for_children()
		_refresh_deferred()
@export_range(-10.0, 10.0, 0.1) var fall_rate: float = 1.0
@export_range(1.0, 20.0, 0.5) var soft_drop_multiplier: float = 5.0
@export_range(0.01, 0.30, 0.005) var clear_block_duration: float = 0.06
@export_range(0.00, 0.20, 0.005) var clear_block_gap: float = 0.02 
@export_range(0.00, 0.20, 0.005) var clear_row_gap: float = 0.04
@export var polyomino_scene: PackedScene = preload("res://prefabs/Polyomino.tscn")
@export var conveyor_step_ms: int = 150
@export var spawn_top_row: int = 0
@export var hold_start_delay_ms: int = 200
@export var hold_repeat_interval_ms: int = 40
@export var most_recent_press_wins: bool = true
@export var board_mask:BoardMaskScript


@onready var inactive_container := $InactiveContainer
@onready var grid_overlay := $GridOverlay
@onready var polyomino_container := $PolyominoContainer
@onready var queued_container := $QueuedContainer
@onready var block_scene: PackedScene = preload("res://prefabs/Block.tscn")

var _occupied: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var default_spawn_id: String = "I3"
var _accum_cells: float = 0.0
var _state: int = GameState.ACTIVE_CONTROLLED
var _prev_state: int = GameState.ACTIVE_CONTROLLED
var _conveyor_accum_ms: int = 0
var _fully_on_grid_once: bool = false
var _precreated_next_id: String = ""
var _hold_left: bool = false
var _hold_right: bool = false
var _hold_dir: int = 0
var _hold_timer_ms: int = -1
var _next_piece_id: int = 1
var bag:BagServiceScript
var _pending_bag_ids:Array[String]=[]
var _pending_bag_seed:int=0
var _queued_piece: Polyomino = null
var _queued_conveyor_accum_ms: int = 0
var _queued_fully_on_grid_once: bool = false
var _active_fully_in_grid_once: bool = false
var _preview_updating: bool = false
var ghost_overlay: GhostOutlineScript
var _mask_top_rows:PackedInt32Array=PackedInt32Array()
var _row_mask_counts:PackedInt32Array=PackedInt32Array()
var rubble_jitter_px: int = 1
var rubble_opacity: float = 0.75
var _hard_drop_allowed: bool = true


func _ready():
	if Engine.is_editor_hint():
		return
	add_to_group("board")
	if inactive_container == null:
		inactive_container = Node2D.new()
		inactive_container.name = "InactiveContainer"
		add_child(inactive_container)
	_rng.randomize()
	_call_mask_resize()
	add_to_group("board")
	_refresh_overlay()
	ghost_overlay = GhostOutlineScript.new()
	add_child(ghost_overlay)
	ghost_overlay.visible = false
	if Engine.has_singleton("Settings") or true:
		if typeof(Settings) != TYPE_NIL:
			Settings.connect("reloaded", Callable(self, "_on_settings_reloaded"))
			Settings.connect("changed", Callable(self, "_on_settings_changed"))
			_on_settings_reloaded(Settings.get_cfg())
		if typeof(Palette) != TYPE_NIL:
			Palette.connect("palette_changed", Callable(self, "_on_palette_changed"))
			_on_palette_changed(Palette.current())



func _process(delta: float) -> void:
	if _state == GameState.PRECONTROL_AUTOSLIDE:
		_update_precontrol(delta)
		return
	_update_ghost()
	if _state == GameState.ACTIVE_CONTROLLED:
		var _p := _get_active_polyomino()
		if _p != null and not _active_fully_in_grid_once and _is_piece_fully_in_grid(_p):
			_active_fully_in_grid_once = true
			_spawn_queued_if_needed()
	if _state == GameState.ACTIVE_CONTROLLED and _hold_dir != 0 and (_hold_left or _hold_right):
		_hold_timer_ms -= int(delta * 1000.0)
		while _hold_timer_ms <= 0:
			_try_nudge_active(_hold_dir)
			_hold_timer_ms += hold_repeat_interval_ms
	if _state != GameState.ACTIVE_CONTROLLED:
		return
	if fall_rate == 0.0:
		return
	var rate := fall_rate
	if Input.is_action_pressed("ui_down"):
		rate *= soft_drop_multiplier
	_accum_cells += delta * rate
	while _accum_cells >= 1.0:
		_accum_cells -= 1.0
		_step_fall(1)
	while _accum_cells <= -1.0:
		_accum_cells += 1.0
		_step_fall(-1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_toggle"):
		if _state == GameState.PAUSED:
			_enter_state(_prev_state)
		else:
			_enter_state(GameState.PAUSED)
		return
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
	var piece:=_get_active_polyomino()
	if piece==null:
		return
	if Input.is_action_just_pressed("ui_down"):
		_grant_control()
		return
	_conveyor_accum_ms+=int(delta*1000.0)
	while _conveyor_accum_ms>=conveyor_step_ms:
		_conveyor_accum_ms-=conveyor_step_ms
		if not _is_fully_inside_left_wall(piece):
			piece.grid_position.x+=1
			_snap_piece_to_top_lane(piece)
			if _is_fully_inside_left_wall(piece) and not _fully_on_grid_once:
				_fully_on_grid_once=true
				if _precreated_next_id=="":
					_precreated_next_id=_bag_next()
			return
		if _can_step_right_in_top_lane(piece):
			piece.grid_position.x+=1
			_snap_piece_to_top_lane(piece)
		else:
			_grant_control()
			return


func _grant_control() -> void:
	_enter_state(GameState.ACTIVE_CONTROLLED)
	_hold_left = false
	_hold_right = false
	_hold_dir = 0
	_hold_timer_ms = -1
	if _precreated_next_id == "":
		_precreated_next_id = _bag_next()

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
	var base:=Vector2i(int(piece.grid_position.x), int(piece.grid_position.y))
	return PlacementRulesMod.can_place(board_mask, board_width, board_height, base, offsets, _occupied)

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
	poly.shape_key = id
	var blocks: Array[Vector2] = POLY_DATA.get_blocks(id)
	var color: Color = (Palette.color_for_shape_key(id) if typeof(Palette) != TYPE_NIL else s["color"])
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
		_enter_state(GameState.PRECONTROL_AUTOSLIDE)
		_conveyor_accum_ms = 0
		_fully_on_grid_once = false
		_precreated_next_id = ""
		_hold_left = false
		_hold_right = false
		_hold_dir = 0
		_hold_timer_ms = -1
		_active_fully_in_grid_once = false
		if ghost_overlay != null:
			ghost_overlay.visible = false
	else:
		_enter_state(GameState.ACTIVE_CONTROLLED)

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
	var base:=Vector2i(int(piece.grid_position.x), int(piece.grid_position.y))
	return PlacementRulesMod.would_collide(board_mask, board_width, board_height, base, piece.block_offsets, delta, _occupied)

func _is_fully_inside_left_wall(piece: Polyomino) -> bool:
	var base_x:=int(piece.grid_position.x)
	for off in piece.block_offsets:
		if base_x+int(off.x)<0:
			return false
	return true

func _snap_piece_to_top_lane(piece: Polyomino) -> void:
	var gx:=int(piece.grid_position.x)
	var y:=SpawnLaneMod.snap_y_for_lane(_mask_top_rows, board_width, gx, piece.block_offsets)
	piece.grid_position.y=y
	piece.position=(piece.grid_position*piece.cell_size).floor()
	
func _can_step_right_in_top_lane(piece: Polyomino) -> bool:
	var next_x:=int(piece.grid_position.x)+1
	return SpawnLaneMod.can_step_right_in_lane(_mask_top_rows, board_mask, board_width, board_height, next_x, piece.block_offsets)

func _compute_hard_drop_delta(piece: Polyomino) -> int:
	var base:=Vector2i(int(piece.grid_position.x), int(piece.grid_position.y))
	return PlacementRulesMod.hard_drop_delta(board_mask, board_width, board_height, base, piece.block_offsets, _occupied)


func _hard_drop_active() -> void:
	if typeof(Settings) != TYPE_NIL and Settings.get_cfg() != null:
		if not Settings.get_cfg().hard_drop_enabled:
			return
	elif not _hard_drop_allowed:
		return

	if _state != GameState.ACTIVE_CONTROLLED:
		return
	var p := _get_active_polyomino()
	if p == null:
		return
	var dy := _compute_hard_drop_delta(p)
	if dy > 0:
		p.grid_position.y += dy
		p.position = (p.grid_position * p.cell_size).floor()
		emit_signal("hard_drop", dy)
		Score.note_hard_drop(dy)
	_lock_piece(p)

func _lock_piece(piece: Polyomino) -> void:
	var pid := _next_piece_id
	_next_piece_id += 1
	var shape_key := piece.shape_key
	var color_to_use: Color = (Palette.color_for_shape_key(shape_key) if typeof(Palette) != TYPE_NIL else piece.block_color)
	for c in _piece_cells(piece):
		var b: Block = block_scene.instantiate()
		inactive_container.add_child(b)
		b.position = (Vector2(c) * cell_size).floor()
		b.set_shape_key(shape_key)
		b.set_visual(cell_size, color_to_use)
		b.set_grid_cell(c)
		b.set_piece_id(pid)
		_occupied[c] = b
	if is_instance_valid(piece):
		piece.queue_free()

	# Compute immediate lost blocks for this just-locked piece (spans that will clear now)
	var lost:int = 0
	var spans := _find_full_spans()
	if not spans.is_empty():
		for seg in spans:
			var y:int = seg["y"]
			var x0:int = seg["x0"]
			var x1:int = seg["x1"]
			for x in range(x0, x1 + 1):
				var cell := Vector2i(x, y)
				if _occupied.has(cell):
					var blk := _occupied[cell] as Block
					if blk != null and is_instance_valid(blk) and blk.piece_id == pid:
						lost += 1
	emit_signal("piece_locked", pid, lost)

	var next_choice: String
	if _pending_bag_ids.size() > 0:
		if _queued_piece != null:
			_queued_piece.queue_free()
			_queued_piece = null
		bag.setup(_pending_bag_ids, _pending_bag_seed)
		_pending_bag_ids = []
		_pending_bag_seed = 0
		_precreated_next_id = ""
		next_choice = _bag_next()
	else:
		if _queued_piece != null:
			next_choice = PROMOTE_QUEUED_SENTINEL
		else:
			next_choice = _precreated_next_id if _precreated_next_id != "" else _bag_next()
	_precreated_next_id = ""
	_start_line_clear_if_needed(next_choice)

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

func _update_ghost() -> void:
	if ghost_overlay == null:
		return
	if _state != GameState.ACTIVE_CONTROLLED:
		ghost_overlay.visible = false
		return
	var p := _get_active_polyomino()
	if p == null:
		ghost_overlay.visible = false
		return
	var dy := _compute_hard_drop_delta(p)
	var base := Vector2i(int(p.grid_position.x), int(p.grid_position.y + dy))
	ghost_overlay.visible = true
	ghost_overlay.set_style(p.cell_size, Color(1, 1, 1, 0.6))
	ghost_overlay.set_shape(p.block_offsets)
	ghost_overlay.set_base(base)

func _start_line_clear_if_needed(next_id: String) -> void:
	var spans := _find_full_spans()
	if spans.is_empty():
		Score.note_lock_no_clear()
		if next_id == PROMOTE_QUEUED_SENTINEL:
			_promote_queued_to_active()
			_enter_state(GameState.PRECONTROL_AUTOSLIDE)
			if ghost_overlay != null:
				ghost_overlay.visible = false
		else:
			_spawn_from_id(next_id, true)
		return
	_enter_state(GameState.LINE_CLEAR)
	call_deferred("_resolve_clears_then_spawn", next_id)

func _resolve_clears_then_spawn(next_id: String) -> void:
	while true:
		var spans := _find_full_spans()
		if spans.is_empty():
			break
		await _run_span_clear_cycle(spans)
	if next_id == PROMOTE_QUEUED_SENTINEL:
		_promote_queued_to_active()
	else:
		_spawn_from_id(next_id, true)
	_enter_state(GameState.PRECONTROL_AUTOSLIDE)
	if ghost_overlay != null:
		ghost_overlay.visible = false


func _find_full_rows() -> Array[int]:
	var counts:PackedInt32Array=PackedInt32Array()
	counts.resize(board_height)
	for y in board_height:
		counts[y]=0
	for cell in _occupied.keys():
		var y:=int(cell.y)
		if y>=0 and y<board_height:
			if board_mask.is_playable(cell.x,cell.y):
				counts[y]+=1
	var rows:Array[int]=[]
	for y in board_height:
		if _row_mask_counts[y]>0 and counts[y]==_row_mask_counts[y]:
			rows.append(y)
	rows.sort()
	rows.reverse()
	return rows

func _convert_survivors_to_rubble(cut_ids: Array[int]) -> void:
	if cut_ids.is_empty():
		return
	var pid_set := {}
	for id in cut_ids:
		pid_set[id] = true
	var spawned:int = 0
	for cell in _occupied.keys():
		var b := _occupied[cell] as Block
		if b == null or not is_instance_valid(b):
			continue
		if pid_set.has(b.piece_id) and not b.rubble:
			var rng_seed: int = abs(int(Time.get_ticks_msec()) + cell.x * 73856093 + cell.y * 19349663 + b.piece_id * 83492791)
			var col: Color
			if b.color_rect != null:
				col = b.color_rect.color
			else:
				col = Color.WHITE
			b.set_rubble(true, rubble_jitter_px, rng_seed, rubble_opacity, col)
			spawned += 1
	if spawned > 0:
		emit_signal("rubble_spawned", spawned)

func _clear_span_animate(y:int, x0:int, x1:int, cleared:Dictionary) -> Array[int]:
	var cut_ids := {}
	for x in range(x0, x1 + 1):
		var cell := Vector2i(x, y)
		if not _occupied.has(cell):
			continue
		var block := _occupied[cell] as Block
		if block != null and is_instance_valid(block):
			cut_ids[block.piece_id] = true
			var target: Node = block.get_shrink_target()
			if target is ColorRect:
				var rect: ColorRect = target as ColorRect
				rect.pivot_offset = rect.size * 0.5
				rect.scale = Vector2.ONE
				var tw: Tween = create_tween()
				tw.tween_property(rect, "scale", Vector2.ZERO, clear_block_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await tw.finished
			elif target is Node2D:
				var tn: Node2D = target as Node2D
				tn.scale = Vector2.ONE
				var tw2: Tween = create_tween()
				tw2.tween_property(tn, "scale", Vector2.ZERO, clear_block_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await tw2.finished
			_occupied.erase(cell)
			block.queue_free()
			cleared[cell]=true
		else:
			_occupied.erase(cell)
		if clear_block_gap > 0.0 and x < x1:
			await get_tree().create_timer(clear_block_gap).timeout
	var out: Array[int] = []
	for k in cut_ids.keys():
		out.append(int(k))
	return out

func _collapse_above(cleared_y: int, spans: Array) -> void:
	if cleared_y <= 0:
		return
	var colset: Dictionary = {}
	for span in spans:
		var s: Vector2i = span
		for x in range(s.x, s.y + 1):
			colset[x] = true
	if colset.is_empty():
		return
	var col_list: Array = colset.keys()
	col_list.sort()
	var moved_piece_ids: Dictionary = {}
	var moved_block_ids: Dictionary = {}
	while true:
		var reserved: Dictionary = {}
		var moves: Array = []
		var piece_cells: Dictionary = {}
		var piece_intact: Dictionary = {}
		var piece_has_col: Dictionary = {}
		var piece_all_above: Dictionary = {}
		for cell in _occupied.keys():
			var blk: Block = _occupied[cell]
			if blk == null or not is_instance_valid(blk):
				continue
			var pid: int = blk.piece_id
			if not piece_cells.has(pid):
				piece_cells[pid] = []
				piece_intact[pid] = true
				piece_has_col[pid] = false
				piece_all_above[pid] = true
			(piece_cells[pid] as Array).append(cell)
			if blk.rubble:
				piece_intact[pid] = false
			if colset.has(cell.x):
				piece_has_col[pid] = true
			if cell.y >= cleared_y:
				piece_all_above[pid] = false
		var decided_piece: Dictionary = {}
		for yy in range(cleared_y - 1, -1, -1):
			for i in range(col_list.size()):
				var x: int = int(col_list[i])
				var pos := Vector2i(x, yy)
				if not _occupied.has(pos):
					continue
				var b: Block = _occupied[pos]
				if b == null or not is_instance_valid(b):
					_occupied.erase(pos)
					continue
				if b.rubble:
					continue
				var pid: int = b.piece_id
				if moved_piece_ids.has(pid):
					continue
				if decided_piece.has(pid):
					continue
				if not piece_intact.get(pid, false):
					continue
				if not piece_has_col.get(pid, false):
					continue
				if not piece_all_above.get(pid, false):
					continue
				var cells: Array = piece_cells[pid]
				var can_move: bool = true
				for c in cells:
					var to := Vector2i(c.x, c.y + 1)
					if to.y >= board_height:
						can_move = false
						break
					if reserved.has(to):
						can_move = false
						break
					if _occupied.has(to):
						var ob: Block = _occupied[to]
						if ob == null or not is_instance_valid(ob) or ob.piece_id != pid:
							can_move = false
							break
				if can_move:
					for c in cells:
						var to2 := Vector2i(c.x, c.y + 1)
						moves.append({"from": c, "to": to2, "blk": _occupied[c]})
						reserved[to2] = true
					moved_piece_ids[pid] = true
					decided_piece[pid] = true
		for yy in range(cleared_y - 1, -1, -1):
			for i in range(col_list.size()):
				var x2: int = int(col_list[i])
				var from := Vector2i(x2, yy)
				if not _occupied.has(from):
					continue
				var rb: Block = _occupied[from]
				if rb == null or not is_instance_valid(rb):
					_occupied.erase(from)
					continue
				if moved_block_ids.has(rb.get_instance_id()):
					continue
				if not rb.rubble:
					continue
				var to3 := Vector2i(from.x, from.y + 1)
				if to3.y >= board_height:
					continue
				if reserved.has(to3):
					continue
				if _occupied.has(to3):
					continue
				moves.append({"from": from, "to": to3, "blk": rb})
				reserved[to3] = true
				moved_block_ids[rb.get_instance_id()] = true
		if moves.is_empty():
			break
		for m in moves:
			_occupied.erase(m["from"])
		for m in moves:
			var dest: Vector2i = m["to"]
			var bl: Block = m["blk"]
			_occupied[dest] = bl
			bl.position = (Vector2(dest) * cell_size).floor()
			bl.set_grid_cell(dest)

func _bag_next() -> String:
	var nxt: Variant = bag.next()
	if nxt == null:
		return default_spawn_id
	return String(nxt)

func reconfigure_bag(ids:Array[String],rng_seed:int=0)->bool:
	if not _validate_entryway_for_bag(ids):
		emit_signal("bag_reconfig_fail", ids.duplicate(true))
		return false
	_pending_bag_ids = ids.duplicate(true)
	_pending_bag_seed = rng_seed
	_update_next_preview()
	emit_signal("bag_reconfig_ok", ids.duplicate(true))
	return true


func _update_next_preview() -> void:
	if _preview_updating:
		return
	_preview_updating = true
	var next_id: String = ""
	if _pending_bag_ids.size() > 0:
		var temp := BagServiceScript.new()
		temp.setup(_pending_bag_ids, _pending_bag_seed)
		var v0: Variant = temp.next()
		if v0 != null:
			next_id = String(v0)
		else:
			next_id = default_spawn_id
	elif _precreated_next_id != "":
		next_id = _precreated_next_id
	elif bag != null:
		var peeked: Array = bag.peek(1)
		if peeked.size() > 0:
			var v1: Variant = peeked[0]
			next_id = String(v1)
		else:
			next_id = default_spawn_id
	else:
		next_id = default_spawn_id
	emit_signal("next_preview", [next_id])
	_preview_updating = false

func _spawn_queued_if_needed() -> void:
	if _queued_piece != null:
		return
	if _precreated_next_id == "":
		return
	var s: Dictionary = POLY_DATA.get_shape_with_color(_precreated_next_id)
	if s.is_empty():
		return
	var blocks: Array[Vector2] = POLY_DATA.get_blocks(_precreated_next_id)
	var color: Color = s["color"]
	var min_x := 999999
	var max_y := -999999
	for off in blocks:
		min_x = min(min_x, int(off.x))
		max_y = max(max_y, int(off.y))
	var start_x := -min_x
	var start_y := -max_y - 1
	var poly: Polyomino = polyomino_scene.instantiate()
	queued_container.add_child(poly)
	poly.initialize(cell_size, Vector2(start_x, start_y), blocks, color)
	poly.show_origin = true
	poly._update_origin_marker()
	_queued_piece = poly
	_queued_conveyor_accum_ms = 0
	_queued_fully_on_grid_once = false

func _promote_queued_to_active() -> void:
	if _queued_piece == null:
		_spawn_from_id(_bag_next(), true)
		return
	_active_fully_in_grid_once = false
	if _queued_piece.get_parent() == queued_container:
		queued_container.remove_child(_queued_piece)
		polyomino_container.add_child(_queued_piece)
	_enter_state(GameState.PRECONTROL_AUTOSLIDE)
	_conveyor_accum_ms = 0
	_fully_on_grid_once = false
	_queued_piece = null
	_update_next_preview()

func _is_piece_fully_in_grid(p: Polyomino) -> bool:
	var min_local_y := 999999
	for off in p.block_offsets:
		min_local_y = min(min_local_y, int(off.y))
	return int(p.grid_position.y) + min_local_y >= 0

func _enter_state(s:int)->void:
	_prev_state = _state
	_state = s
	print("[State] -> ", ["PRECONTROL_AUTOSLIDE","ACTIVE_CONTROLLED","LINE_CLEAR","PAUSED"][s])

func _call_mask_resize()->void:
	if board_mask==null:
		board_mask=BoardMaskScript.new()
	board_mask.set_size(board_width,board_height)
	_recompute_mask_caches()
	_refresh_mask_overlay()

func _recompute_mask_caches()->void:
	_mask_top_rows = SpawnLaneMod.compute_top_rows(board_mask, board_width)
	_row_mask_counts.resize(board_height)
	for y in board_height:
		_row_mask_counts[y]=board_mask.row_playable_count(y)


func _refresh_mask_overlay()->void:
	if not has_node("MaskOverlay"):
		return
	if is_instance_valid($MaskOverlay):
		$MaskOverlay.refresh()
	if is_instance_valid(grid_overlay):
		grid_overlay.refresh()

func import_mask_from_image(path:String, threshold:float=0.5) -> void:
	var img:Image = Image.new()
	var err:int = img.load(path)
	if err != OK:
		return
	if board_mask == null:
		board_mask = BoardMaskScript.new()
	board_mask.set_size(board_width, board_height)
	board_mask.from_image(img, threshold)
	_recompute_mask_caches()
	_refresh_mask_overlay()

func _compute_piece_width(id:String)->int:
	return SpawnLaneMod.compute_piece_width(POLY_DATA.get_blocks(id))

func _top_row_span_length()->int:
	return SpawnLaneMod.top_row_span_length(board_mask, board_width)

func _validate_entryway_for_bag(ids:Array[String])->bool:
	return SpawnLaneMod.validate_entryway_for_bag(board_mask, board_width, ids, POLY_DATA)

func setup_with_size(size:Vector2i, cs:int, bag_ids:Array[String], rng_seed:int=0)->bool:
	board_width=size.x
	board_height=size.y
	cell_size=cs
	_call_mask_resize()
	if bag==null:
		bag=BagServiceScript.new()
	bag.setup(bag_ids,rng_seed)
	if not _validate_entryway_for_bag(bag_ids):
		return false
	_precreated_next_id=""
	_spawn_from_id(_bag_next(),true)
	return true

func setup_with_mask(png_path:String, cs:int, bag_ids:Array[String], rng_seed:int=0)->bool:
	var low:=png_path.to_lower()
	if not low.ends_with(".png"):
		return false
	var img:Image=Image.new()
	var err:int=img.load(png_path)
	if err!=OK:
		return false
	board_width=img.get_width()
	board_height=img.get_height()
	cell_size=cs
	if board_mask==null:
		board_mask=BoardMaskScript.new()
	board_mask.set_size(board_width,board_height)
	board_mask.from_image(img,0.5)
	_recompute_mask_caches()
	_refresh_mask_overlay()
	if bag==null:
		bag=BagServiceScript.new()
	bag.setup(bag_ids,rng_seed)
	if not _validate_entryway_for_bag(bag_ids):
		return false
	_precreated_next_id=""
	_spawn_from_id(_bag_next(),true)
	return true

func _row_spans(y:int) -> Array[Vector2i]:
	return ClearCollapseMod.row_spans(board_mask, board_width, y)

func _find_full_spans() -> Array[Dictionary]:
	var occ:Dictionary={}
	for cell in _occupied.keys():
		occ[cell]=true
	return ClearCollapseMod.find_full_spans(board_mask, board_width, board_height, occ)


func _run_span_clear_cycle(spans: Array) -> void:
	if spans.is_empty():
		return
	var by_row: Dictionary = {}
	for d in spans:
		var y: int = d["y"]
		if not by_row.has(y):
			by_row[y] = []
		(by_row[y] as Array).append(d)
	var ys: Array[int] = int_dict_keys(by_row)
	ys.sort()
	ys.reverse()
	var y: int = ys[0]
	var row_spans: Array = by_row[y]
	row_spans.sort_custom(Callable(self, "_cmp_span_x0"))
	var cut_ids_row: Array[int] = []
	var cleared_row := {}
	for seg in row_spans:
		var x0: int = seg["x0"]
		var x1: int = seg["x1"]
		var cut_ids_this := await _clear_span_animate(y, x0, x1, cleared_row)
		for id in cut_ids_this:
			cut_ids_row.append(id)
	emit_signal("rows_cleared", y, row_spans.size())
	_convert_survivors_to_rubble(cut_ids_row)
	_masked_collapse_after_clear_one_row(cleared_row, y, row_spans)

func int_dict_keys(d:Dictionary) -> Array[int]:
	var out:Array[int]=[]
	for k in d.keys():
		out.append(int(k))
	return out

func _masked_collapse_after_clear_one_row(_cleared:Dictionary, cleared_y:int, spans_for_row:Array) -> void:
	var snap:Dictionary={}
	for pos in _occupied.keys():
		var b: Block = _occupied[pos]
		if b==null or not is_instance_valid(b):
			_occupied.erase(pos)
			continue
		snap[pos]={"pid":b.piece_id,"rubble":b.rubble}
	var passes:Array = ClearCollapseMod.collapse_passes(board_mask, board_width, board_height, cleared_y, spans_for_row, snap)
	for pass_moves in passes:
		var applied:Array=[]
		for m in pass_moves:
			var src:Vector2i=m["from"]
			if _occupied.has(src):
				applied.append({"from":src,"to":m["to"],"blk":_occupied[src]})
		for m in applied:
			_occupied.erase(m["from"])
		for m in applied:
			var dest:Vector2i=m["to"]
			var bl:Block=m["blk"]
			_occupied[dest]=bl
			if bl!=null and is_instance_valid(bl):
				bl.position=(Vector2(dest)*cell_size).floor()
				bl.set_grid_cell(dest)

func _cleared_columns_for_row(spans_for_row:Array) -> PackedInt32Array:
	var cols:=PackedInt32Array()
	var seen:= {}
	for seg in spans_for_row:
		var x0:int=seg["x0"]
		var x1:int=seg["x1"]
		for x in range(x0,x1+1):
			if not seen.has(x):
				seen[x]=true
				cols.append(x)
	cols.sort()
	return cols

func _mask_corridor_clear_inclusive(x:int, y_from:int, y_to:int) -> bool:
	if y_from>y_to:
		var t:=y_from
		y_from=y_to
		y_to=t
	for yy in range(max(y_from,0), y_to+1):
		if not board_mask.is_playable(x,yy):
			return false
	return true

func _on_settings_reloaded(cfg: GameConfig) -> void:
	if cfg == null: return
	rubble_jitter_px = cfg.rubble_jitter_px
	rubble_opacity = cfg.rubble_opacity
	_hard_drop_allowed = cfg.hard_drop_enabled

func _on_settings_changed(key: String, _value) -> void:
	# For now just pull the whole cfg each time (cheap, keeps code compact)
	var cfg := Settings.get_cfg()
	if cfg == null: return
	_on_settings_reloaded(cfg)

func _on_palette_changed(p: PaletteData) -> void:
	if p == null:
		return
	for cell in _occupied.keys():
		var b: Block = _occupied[cell]
		if b == null or not is_instance_valid(b):
			continue
		var col: Color = (Palette.color_for_shape_key(b.shape_key) if b.shape_key != "" else b.base_color)
		b.apply_palette_color(col)
		if b.rubble:
			b.apply_rubble_opacity(p.rubble_tint.a)
	var act := _get_active_polyomino()
	if act != null and act.shape_key != "":
		act.block_color = Palette.color_for_shape_key(act.shape_key)

