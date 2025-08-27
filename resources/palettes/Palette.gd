extends Resource
class_name PaletteData

@export var name: String = "Default"

@export var piece_colors: Array[Color] = [
	Color8(239, 83, 80),
	Color8(255, 167, 38),
	Color8(255, 238, 88),
	Color8(102, 187, 106),
	Color8(66, 165, 245),
	Color8(171, 71, 188),
	Color8(0, 188, 212),
	Color8(255, 112, 67),
	Color8(124, 179, 66),
	Color8(63, 81, 181)
]

@export var rubble_tint: Color = Color(1,1,1,0.75)
@export var ghost_tint: Color = Color(1,1,1,0.35)
@export var grid_line: Color = Color(1,1,1,0.18)
