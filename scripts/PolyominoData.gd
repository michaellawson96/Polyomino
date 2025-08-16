# PolyominoData.gd
class_name PolyominoData
extends Node

# Each entry: { id, blocks:Array[Vector2], color:Color }
# Offsets are relative to (0,0). One representative per free shape (no rotations/flips duplicates).
const SHAPES: Array[Dictionary] = [
	# --- 1-cell ---
	{ "id": "M1", "blocks": [Vector2(0, 0)] },

	# --- 2-cells ---
	{ "id": "D2", "blocks": [Vector2(0, 0), Vector2(1, 0)] },

	# --- 3-cells ---
	{ "id": "I3", "blocks": [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)] },
	{ "id": "L3", "blocks": [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)] },

	# --- 5-cells (no Z5 since it’s a flip of W5) ---
	{ "id": "F5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(2,1), Vector2(1,-1)] },
	{ "id": "I5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(3,0), Vector2(4,0)] },
	{ "id": "L5", "blocks": [Vector2(0,0), Vector2(0,1), Vector2(0,2), Vector2(0,3), Vector2(1,3)] },
	{ "id": "P5", "blocks": [Vector2(0,0), Vector2(0,1), Vector2(1,0), Vector2(1,1), Vector2(0,2)] },
	{ "id": "N5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(2,1), Vector2(3,1)] },
	{ "id": "T5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(1,1), Vector2(1,2)] },
	{ "id": "U5", "blocks": [Vector2(0,0), Vector2(2,0), Vector2(0,1), Vector2(1,1), Vector2(2,1)] },
	{ "id": "V5", "blocks": [Vector2(0,0), Vector2(0,1), Vector2(0,2), Vector2(1,2), Vector2(2,2)] },
	{ "id": "W5", "blocks": [Vector2(0,0), Vector2(1,1), Vector2(2,2), Vector2(1,0), Vector2(2,1)] },
	{ "id": "X5", "blocks": [Vector2(1,0), Vector2(0,1), Vector2(1,1), Vector2(2,1), Vector2(1,2)] },
	{ "id": "Y5", "blocks": [Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(3,0), Vector2(2,1)] },
]

static func get_all() -> Array[Dictionary]:
	return SHAPES

static func get_shape(id: String) -> Dictionary:
	for s in SHAPES:
		if s["id"] == id:
			return s
	return {}

# PolyominoData.gd (append near the top, after SHAPES)

# Colorblind-friendly-ish, limited palette (adjust to taste)
const PALETTE: Array[Color] = [
	Color8( 66, 135, 245), # blue
	Color8(245, 130,  48), # orange
	Color8( 60, 180,  75), # green
	Color8(145,  30, 180), # purple
	Color8(240,  50, 230), # magenta
	Color8(128, 128,   0), # olive
	Color8( 70, 240, 240), # cyan
	Color8(230,  25,  75), # red
]

static func get_color(id: String) -> Color:
	# Deterministic mapping: stable across runs
	var idx: int = abs(hash(id)) % PALETTE.size()
	return PALETTE[idx]

static func get_shape_with_color(id: String) -> Dictionary:
	var s := get_shape(id)
	if s.is_empty():
		return {}
	var out := s.duplicate(true)
	out["color"] = get_color(id)
	return out
