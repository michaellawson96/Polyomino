class_name GhostOutline
extends Node2D

@export var color: Color = Color(1, 1, 1, 0.6)
@export var line_width: float = 2.0

var cell_size: int = 32
var blocks: Array[Vector2] = []
var base: Vector2i = Vector2i.ZERO
var _thickness: float = 2.0

func _ready():
	if typeof(Settings) != TYPE_NIL:
		Settings.connect("reloaded", Callable(self, "_on_settings_reloaded"))
		Settings.connect("changed", Callable(self, "_on_settings_changed"))
		_on_settings_reloaded(Settings.get_cfg())

func _on_settings_reloaded(cfg: GameConfig) -> void:
	if cfg == null: return
	_thickness = cfg.ghost_thickness
	queue_redraw()

func _on_settings_changed(key: String, value) -> void:
	_on_settings_reloaded(Settings.get_cfg())


func set_style(cs: int, col: Color) -> void:
	cell_size = cs
	color = col
	queue_redraw()

func set_shape(b: Array[Vector2]) -> void:
	blocks = b
	queue_redraw()

func set_base(g: Vector2i) -> void:
	base = g
	position = (Vector2(base) * cell_size).floor()
	queue_redraw()

func _draw() -> void:
	if blocks.is_empty():
		return
	var set := {}
	for off in blocks:
		set[Vector2i(int(off.x), int(off.y))] = true
	for off in blocks:
		var x := int(off.x)
		var y := int(off.y)
		if not set.has(Vector2i(x, y + 1)):
			var ypix := float((y + 1) * cell_size)
			var x0 := float(x * cell_size)
			var x1 := float((x + 1) * cell_size)
			draw_line(Vector2(x0, ypix), Vector2(x1, ypix), color, _thickness)
