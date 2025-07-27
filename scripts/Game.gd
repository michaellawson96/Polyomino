extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var shape = PolyominoData.get_shape("I")
	if shape:
		print("Loaded shape 'I':")
		print("  Blocks: ", shape.blocks)
		print("  Pivot: ", shape.pivot)
	else:
		print("Shape not found.")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
