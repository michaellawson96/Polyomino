extends Node2D

const POLY_DATA := preload("res://scripts/PolyominoData.gd")
const EffectsManagerScript := preload("res://scripts/managers/EffectsManager.gd")

@onready var boards_container: Node = $BoardsContainer
@onready var board_scene: PackedScene = preload("res://scenes/Board.tscn")

var effects_manager: EffectsManager

func _ready():
	effects_manager = EffectsManagerScript.new()
	add_child(effects_manager)
	var ids: Array[String] = []
	for d in POLY_DATA.get_all():
		ids.append(String(d["id"]))
	_spawn_board_with_mask("res://masks/10x20.png", 26, ids, 0)


func _spawn_board_with_size(size:Vector2i, cell_size:int, bag_ids:Array[String], rng_seed:int)->void:
	var board = board_scene.instantiate()
	boards_container.add_child(board)
	if effects_manager == null or not is_instance_valid(effects_manager):
		effects_manager = EffectsManagerScript.new()
		add_child(effects_manager)
	effects_manager.attach_board(board)
	var padding_cells := _compute_top_padding_cells()
	board.position = Vector2(0, padding_cells * cell_size)
	var ok:bool = board.setup_with_size(size, cell_size, bag_ids, rng_seed)
	if not ok:
		push_error("Board setup_with_size failed")

func _spawn_board_with_mask(png_path:String, cell_size:int, bag_ids:Array[String], rng_seed:int)->void:
	var board = board_scene.instantiate()
	boards_container.add_child(board)
	if effects_manager == null or not is_instance_valid(effects_manager):
		effects_manager = EffectsManagerScript.new()
		add_child(effects_manager)
	effects_manager.attach_board(board)
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
