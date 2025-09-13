extends Control
class_name SegmentBar

@export var max_value: int = 100: set = set_max_value
@export var value: int = 0: set = set_value
@export var vertical: bool = true
@export var empty_color: Color = Color(0.35, 0.05, 0.05, 1.0)
@export var fill_color: Color = Color(0.9, 0.15, 0.15, 1.0)
@export var grid_color: Color = Color(0, 0, 0, 1)
@export var grid_px: float = 1.0

func set_max_value(v: int) -> void:
	max_value = max(1, v)
	value = clamp(value, 0, max_value)
	queue_redraw()

func set_value(v: int) -> void:
	value = clamp(v, 0, max_value)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(r, empty_color, true)
	if max_value <= 0:
		return
	if vertical:
		var cell_h: float = r.size.y / float(max_value)
		var fill_h: float = cell_h * float(value)
		if fill_h > 0.0:
			var y0: float = r.size.y - fill_h
			draw_rect(Rect2(Vector2(0, y0), Vector2(r.size.x, fill_h)), fill_color, true)
		var y: float = r.size.y
		for i in range(max_value + 1):
			draw_line(Vector2(0, y), Vector2(r.size.x, y), grid_color, grid_px)
			y -= cell_h
	else:
		var cell_w: float = r.size.x / float(max_value)
		var fill_w: float = cell_w * float(value)
		if fill_w > 0.0:
			draw_rect(Rect2(Vector2(0, 0), Vector2(fill_w, r.size.y)), fill_color, true)
		var x: float = 0.0
		for i in range(max_value + 1):
			draw_line(Vector2(x, 0), Vector2(x, r.size.y), grid_color, grid_px)
			x += cell_w
