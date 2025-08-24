extends Control

@export var board_path:NodePath=".."
@onready var board:Node=get_node(board_path)

func _draw()->void:
	if board==null or board.board_mask==null:
		return
	var cell:int=board.cell_size
	for y in board.board_height:
		for x in board.board_width:
			if not board.board_mask.is_playable(x,y):
				var r:=Rect2(Vector2(x*cell,y*cell),Vector2(cell,cell))
				draw_rect(r,Color(0,0,0,0.6),true)

func refresh()->void:
	queue_redraw()
