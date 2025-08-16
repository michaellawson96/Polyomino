extends Node2D

@onready var boards_container: Node = $BoardsContainer
@onready var board_scene: PackedScene = preload("res://scenes/Board.tscn")

func _ready():
	_spawn_board(Vector2(10, 20), 30)  # Default board

func _spawn_board(size: Vector2i, cell_size: int) -> void:
	var board = board_scene.instantiate()
	boards_container.add_child(board)

	board.board_width = size.x
	board.board_height = size.y
	board.cell_size = cell_size
