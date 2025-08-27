extends Resource
class_name Palette

@export var name: String = "Default"

@export var piece_colors: Array[Color] = [
	Color8(239, 83, 80),   # red
	Color8(255, 167, 38),  # orange
	Color8(255, 238, 88),  # yellow
	Color8(102, 187, 106), # green
	Color8(66, 165, 245),  # blue
	Color8(171, 71, 188),  # purple
	Color8(0, 188, 212),   # cyan
	Color8(255, 112, 67),  # deep orange
	Color8(124, 179, 66),  # lime green
	Color8(63, 81, 181)    # indigo
]

@export var rubble_tint: Color = Color(1,1,1,0.75)
@export var ghost_tint: Color = Color(1,1,1,0.35)
@export var grid_line: Color = Color(1,1,1,0.18)
