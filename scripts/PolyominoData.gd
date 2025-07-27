# scripts/PolyominoData.gd
extends Node

class_name PolyominoData

static func get_sample_shapes() -> Dictionary:
	return {
		"I": {
			"blocks": [Vector2(0, -1), Vector2(0, 0), Vector2(0, 1), Vector2(0, 2)],
			"pivot": Vector2(0, 0)
		}
	}

static func get_shape(name: String) -> Dictionary:
	var shapes = get_sample_shapes()
	return shapes.get(name, null)
