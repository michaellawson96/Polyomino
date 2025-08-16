# PolyominoData.gd
class_name PolyominoData
extends Node

# Each entry: { id, blocks:Array[Vector2], color:Color }
# Offsets are relative to (0,0). One representative per free shape (no rotations/flips duplicates).
const SHAPES: Array[Dictionary] = [
	# --- 1-cell ---
	{ "id": "M1", "blocks": [Vector2(0, 0)], "color": Color8(240, 240, 240) },

	# --- 2-cells (domino) ---
	{ "id": "D2", "blocks": [Vector2(0, 0), Vector2(1, 0)], "color": Color8(180, 180, 255) },

	# --- 3-cells (triominoes) ---
	# I3 (straight)
	{ "id": "I3", "blocks": [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)], "color": Color8(180, 255, 180) },
	# L3 (bent)
	{ "id": "L3", "blocks": [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)], "color": Color8(255, 210, 160) },

	# --- 5-cells (pentominoes, 12 free shapes) ---
	# Coordinates chosen as compact representatives; all connected; include (0,0).
	# F
	{ "id": "F5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(2,1), Vector2(1,-1)], "color": Color8(255,170,170) },
	# I
	{ "id": "I5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(3,0), Vector2(4,0)], "color": Color8(170,255,255) },
	# L
	{ "id": "L5", "blocks": [Vector2(0,0), Vector2(0,1), Vector2(0,2), Vector2(0,3), Vector2(1,3)], "color": Color8(255,190,120) },
	# P
	{ "id": "P5", "blocks": [Vector2(0,0), Vector2(0,1), Vector2(1,0), Vector2(1,1), Vector2(0,2)], "color": Color8(220,160,255) },
	# N
	{ "id": "N5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(2,1), Vector2(3,1)], "color": Color8(160,220,255) },
	# T
	{ "id": "T5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(1,1), Vector2(1,2)], "color": Color8(255,220,160) },
	# U
	{ "id": "U5", "blocks": [Vector2(0,0), Vector2(2,0), Vector2(0,1), Vector2(1,1), Vector2(2,1)], "color": Color8(200,255,200) },
	# V
	{ "id": "V5", "blocks": [Vector2(0,0), Vector2(0,1), Vector2(0,2), Vector2(1,2), Vector2(2,2)], "color": Color8(255,200,200) },
	# W
	{ "id": "W5", "blocks": [Vector2(0,0), Vector2(1,1), Vector2(2,2), Vector2(1,0), Vector2(2,1)], "color": Color8(200,200,255) },
	# X
	{ "id": "X5", "blocks": [Vector2(1,0), Vector2(0,1), Vector2(1,1), Vector2(2,1), Vector2(1,2)], "color": Color8(200,255,200) },
	# Y
	{ "id": "Y5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(3,0), Vector2(2,1)], "color": Color8(220,220,160) },
	# Z
	{ "id": "Z5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(2,1), Vector2(2,2)], "color": Color8(160,200,255) },
]

static func get_all() -> Array[Dictionary]:
	return SHAPES

static func get_shape(id: String) -> Dictionary:
	for s in SHAPES:
		if s["id"] == id:
			return s
	return {}
