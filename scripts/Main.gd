extends Node2D

const POLY_DATA := preload("res://scripts/PolyominoData.gd")

@onready var boards_container: Node = $BoardsContainer
@onready var board_scene: PackedScene = preload("res://scenes/Board.tscn")

func _ready():
	_spawn_board(Vector2(10, 20), 26)  # Default board

func _spawn_board(size: Vector2i, cell_size: int) -> void:
	var board = board_scene.instantiate()
	boards_container.add_child(board)
	board.board_width = size.x
	board.board_height = size.y
	board.cell_size = cell_size
	var padding_cells := _compute_top_padding_cells()
	board.position = Vector2(0, padding_cells * cell_size) 

func _compute_top_padding_cells() -> int:
	var max_y := 0
	for s in POLY_DATA.get_all():
		for off in s["blocks"]:
			max_y = max(max_y, int(off.y))
	return max_y + 1
