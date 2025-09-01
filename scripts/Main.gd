extends Node2D

const POLY_DATA := preload("res://scripts/PolyominoData.gd")

@onready var boards_container: Node = $BoardsContainer
@onready var board_scene: PackedScene = preload("res://scenes/Board.tscn")

func _ready():
	var ids: Array[String] = []
	for d in POLY_DATA.get_all():
		ids.append(String(d["id"]))
	_spawn_board_with_mask("res://masks/zigzag.png", 26, ids, 0)

func _spawn_board_with_size(size:Vector2i, cell_size:int, bag_ids:Array[String], rng_seed:int)->void:
	var board = board_scene.instantiate()
	boards_container.add_child(board)
	_connect_fbs_signal_logs(board)
	var padding_cells := _compute_top_padding_cells()
	board.position = Vector2(0, padding_cells * cell_size)
	var ok:bool = board.setup_with_size(size, cell_size, bag_ids, rng_seed)
	if not ok:
		push_error("Board setup_with_size failed")

func _spawn_board_with_mask(png_path:String, cell_size:int, bag_ids:Array[String], rng_seed:int)->void:
	var board = board_scene.instantiate()
	boards_container.add_child(board)
	_connect_fbs_signal_logs(board)
	var padding_cells := _compute_top_padding_cells()
	board.position = Vector2(0, padding_cells * cell_size)
	var ok:bool = board.setup_with_mask(png_path, cell_size, bag_ids, rng_seed)
	if not ok:
		push_error("Board setup_with_mask failed")


func _compute_top_padding_cells() -> int:
	var max_y := 0
	for s in POLY_DATA.get_all():
		for off in s["blocks"]:
			max_y = max(max_y, int(off.y))
	return max_y + 1

func _connect_fbs_signal_logs(board: Node) -> void:
	if not is_instance_valid(board): return
	if board.has_signal("hard_drop"):
		board.connect("hard_drop", Callable(self, "_on_fbs_hard_drop"))
	if board.has_signal("piece_locked"):
		board.connect("piece_locked", Callable(self, "_on_fbs_piece_locked"))
	if board.has_signal("rows_cleared"):
		board.connect("rows_cleared", Callable(self, "_on_fbs_rows_cleared"))
	if board.has_signal("rubble_spawned"):
		board.connect("rubble_spawned", Callable(self, "_on_fbs_rubble_spawned"))
	if board.has_signal("critical_started"):
		board.connect("critical_started", Callable(self, "_on_fbs_critical_started"))
	if board.has_signal("bag_reconfig_ok"):
		board.connect("bag_reconfig_ok", Callable(self, "_on_fbs_bag_ok"))
	if board.has_signal("bag_reconfig_fail"):
		board.connect("bag_reconfig_fail", Callable(self, "_on_fbs_bag_fail"))

func _on_fbs_hard_drop(dy:int) -> void:
	print("[FBS] hard_drop dy=", dy)

func _on_fbs_piece_locked(pid:int, lost_blocks:int) -> void:
	print("[FBS] piece_locked pid=", pid, " lost=", lost_blocks)

func _on_fbs_rows_cleared(y:int, span_count:int) -> void:
	print("[FBS] rows_cleared y=", y, " spans=", span_count)

func _on_fbs_rubble_spawned(count:int) -> void:
	print("[FBS] rubble_spawned count=", count)

func _on_fbs_critical_started(active:bool) -> void:
	print("[FBS] critical_started active=", active)

func _on_fbs_bag_ok(ids:Array[String]) -> void:
	print("[FBS] bag_reconfig_ok ids=", ids)

func _on_fbs_bag_fail(ids:Array[String]) -> void:
	print("[FBS] bag_reconfig_fail ids=", ids)
