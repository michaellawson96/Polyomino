extends Node
class_name PaletteService

signal palette_changed(palette: PaletteData)

const _DEFAULT_PATH := "res://resources/palettes/palette_default.tres"
const _HC_PATH := "res://resources/palettes/palette_high_contrast.tres"

var _palette: PaletteData
var _rt_piece_base_color_set: bool = false
var _rt_piece_base_color: Color = Color.WHITE
var _rt_shade_levels: Array[float] = []
var _rt_shade_index_for_key: Dictionary = {}

func _ready() -> void:
	if typeof(Settings) != TYPE_NIL:
		Settings.connect("reloaded", Callable(self, "_on_settings_reloaded"))
		Settings.connect("changed", Callable(self, "_on_settings_changed"))
	_apply_from_settings()

func set_runtime_piece_base_color(c: Color) -> void:
	_rt_piece_base_color_set = true
	_rt_piece_base_color = c
	emit_signal("palette_changed", current())

func set_runtime_shades(levels: Array[float]) -> void:
	_rt_shade_levels = []
	for v in levels:
		_rt_shade_levels.append(clamp(float(v), 0.0, 1.0))
	emit_signal("palette_changed", current())

func set_runtime_shade_index_map(ids: Array[String]) -> void:
	_rt_shade_index_for_key.clear()
	for i in range(ids.size()):
		_rt_shade_index_for_key[ids[i]] = i
	emit_signal("palette_changed", current())

func clear_runtime_overrides() -> void:
	_rt_piece_base_color_set = false
	_rt_shade_levels.clear()
	_rt_shade_index_for_key.clear()
	emit_signal("palette_changed", current())

func _on_settings_reloaded(_cfg) -> void:
	_apply_from_settings()

func _on_settings_changed(key: String, _v) -> void:
	if key == "palette" or key == "*":
		_apply_from_settings()

func _apply_from_settings() -> void:
	var pal_name := "Default"
	if typeof(Settings) != TYPE_NIL and Settings.get_cfg() != null:
		pal_name = Settings.get_cfg().palette
	var path := _DEFAULT_PATH
	var n := (pal_name if pal_name != null else "Default").strip_edges().to_lower()

	if n == "high contrast" or n == "high_contrast" or n == "highcontrast" or n == "hc":
		path = _HC_PATH

	var pal := ResourceLoader.load(path)
	if pal == null or not (pal is PaletteData):
		push_warning("Palette: failed to load '%s'; using default in-memory palette." % path)
		var fallback := PaletteData.new()
		_palette = fallback
	else:
		_palette = pal
	emit_signal("palette_changed", _palette)

func current() -> PaletteData:
	return _palette

func color_for_shape_key(key: String) -> Color:
	var base: Color = _piece_base_hue()
	var levels: Array[float] = _shade_levels()
	if levels.is_empty():
		return base
	var idx: int = 0
	if _rt_shade_index_for_key.has(key):
		idx = int(_rt_shade_index_for_key[key]) % levels.size()
	else:
		idx = abs(int(hash(key))) % levels.size()
	var v: float = clamp(levels[idx], 0.0, 1.0)
	return _color_with_lightness(base, v)


func _piece_base_hue() -> Color:
	if _rt_piece_base_color_set:
		return _rt_piece_base_color
	var pal: PaletteData = current()
	if pal != null:
		var c_var: Variant = pal.get("piece_base_color")
		if c_var is Color:
			var c: Color = c_var
			return c
	return Color(0.20, 0.65, 0.95, 1.0)

func _shade_levels() -> Array[float]:
	if _rt_shade_levels.size() > 0:
		return _rt_shade_levels
	var pal: PaletteData = current()
	if pal != null:
		var v: Variant = pal.get("shade_levels")
		if v is PackedFloat32Array:
			var arr: PackedFloat32Array = v
			var out: Array[float] = []
			for i in range(arr.size()):
				out.append(float(arr[i]))
			if out.size() > 0:
				return out
	return [0.30, 0.42, 0.54, 0.66, 0.78, 0.90]


func _color_with_lightness(base: Color, v: float) -> Color:
	return Color.from_hsv(base.h, base.s, clamp(v, 0.0, 1.0), 1.0)

