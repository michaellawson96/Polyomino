extends Control
class_name SegmentBar

@export var max_value: int = 100: set = set_max_value
@export var value: int = 0: set = set_value
@export var vertical: bool = true
@export var empty_color: Color = Color(0.35, 0.05, 0.05, 1.0)
@export var fill_color: Color = Color(0.9, 0.15, 0.15, 1.0)
@export var grid_color: Color = Color(0, 0, 0, 1)
@export var grid_px: float = 1.0
@export var segment_unit: int = 1: set = set_segment_unit

func set_max_value(v: int) -> void:
	max_value = max(1, v)
	value = clamp(value, 0, max_value)
	_validate_segment_unit()
	queue_redraw()

func set_value(v: int) -> void:
	value = clamp(v, 0, max_value)
	queue_redraw()

func set_segment_unit(u: int) -> void:
	segment_unit = max(1, u)
	_validate_segment_unit()
	queue_redraw()

func _validate_segment_unit() -> void:
	if segment_unit <= 0:
		segment_unit = 1
	if max_value % segment_unit != 0:
		push_error("SegmentBar: segment_unit must divide max_value exactly (max_value=" + str(max_value) + ", segment_unit=" + str(segment_unit) + "). Falling back to 1.")
		segment_unit = 1

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(r, empty_color, true)
	if max_value <= 0:
		return
	var ratio: float = float(value) / float(max_value)
	ratio = clamp(ratio, 0.0, 1.0)
	if vertical:
		var fill_h: float = r.size.y * ratio
		if fill_h > 0.0:
			var y0: float = r.size.y - fill_h
			draw_rect(Rect2(Vector2(0, y0), Vector2(r.size.x, fill_h)), fill_color, true)
		var seg_count: int = max_value / segment_unit
		if seg_count > 0:
			var cell_h: float = r.size.y / float(seg_count)
			if cell_h >= 1.0:
				var y: float = r.size.y
				for i in range(seg_count + 1):
					draw_line(Vector2(0, y), Vector2(r.size.x, y), grid_color, grid_px)
					y -= cell_h
	else:
		var fill_w: float = r.size.x * ratio
		if fill_w > 0.0:
			draw_rect(Rect2(Vector2(0, 0), Vector2(fill_w, r.size.y)), fill_color, true)
		var seg_count2: int = max_value / segment_unit
		if seg_count2 > 0:
			var cell_w: float = r.size.x / float(seg_count2)
			if cell_w >= 1.0:
				var x: float = 0.0
				for i in range(seg_count2 + 1):
					draw_line(Vector2(x, 0), Vector2(x, r.size.y), grid_color, grid_px)
					x += cell_w
