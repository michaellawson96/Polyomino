class_name PolyominoData
extends Node

const SHAPES: Array[Dictionary] = [
	{ "id": "M1", "blocks": [Vector2(0, 0)] },
	{ "id": "D2", "blocks": [Vector2(0, 0), Vector2(1, 0)] },
	{ "id": "I3", "blocks": [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)] },
	{ "id": "L3", "blocks": [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)] },
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

const PALETTE: Array[Color] = [
	Color8( 66, 135, 245),
	Color8(245, 130,  48),
	Color8( 60, 180,  75),
	Color8(145,  30, 180),
	Color8(240,  50, 230),
	Color8(128, 128,   0),
	Color8( 70, 240, 240),
	Color8(230,  25,  75),
]

static func get_color(id: String) -> Color:
	var idx: int = abs(hash(id)) % PALETTE.size()
	return PALETTE[idx]

static func get_shape_with_color(id: String) -> Dictionary:
	var s := get_shape(id)
	if s.is_empty():
		return {}
	var out := s.duplicate(true)
	out["color"] = get_color(id)
	return out

static func get_blocks(id: String) -> Array[Vector2]:
	var s := get_shape(id)
	if s.is_empty():
		return []
	var raw: Array = s["blocks"]
	var out: Array[Vector2] = []
	out.resize(raw.size())
	for i in raw.size():
		out[i] = raw[i] as Vector2
	return out	

func color_for_shape_key(key: String) -> Color:
	if typeof(Palette) != TYPE_NIL:
		return Palette.color_for_shape_key(key)
	return Color.from_hsv(float((abs(int(hash(key))) % 360)) / 360.0, 0.7, 0.9, 1.0)

func get_color_for_shape_key(key: String) -> Color:
	return color_for_shape_key(key)
