extends Node
class_name PaletteService

signal palette_changed(palette: Palette)

var _palette: Palette
const _DEFAULT_PATH := "res://resources/palettes/palette_default.tres"
const _HC_PATH := "res://resources/palettes/palette_high_contrast.tres"

func _ready() -> void:
	if typeof(Settings) != TYPE_NIL:
		Settings.connect("reloaded", Callable(self, "_on_settings_reloaded"))
		Settings.connect("changed", Callable(self, "_on_settings_changed"))
	_apply_from_settings()

func _on_settings_reloaded(cfg) -> void:
	_apply_from_settings()

func _on_settings_changed(key: String, _v) -> void:
	if key == "palette" or key == "*":
		_apply_from_settings()

func _apply_from_settings() -> void:
	var name := "Default"
	if typeof(Settings) != TYPE_NIL and Settings.get_cfg() != null:
		name = Settings.get_cfg().palette
	var path := _DEFAULT_PATH
	var n := (name if name!=null else "Default").strip_edges().to_lower()
	if n == "high contrast" or n == "high_contrast" or n == "highcontrast":
		path = _HC_PATH
	var pal := ResourceLoader.load(path)
	if pal != null and pal is Palette:
		_palette = pal
		emit_signal("palette_changed", _palette)

func current() -> Palette:
	return _palette

func color_for_shape_key(key: String) -> Color:
	if _palette == null or _palette.piece_colors.is_empty():
		return Color.WHITE
	var idx := abs(int(hash(key))) % _palette.piece_colors.size()
	return _palette.piece_colors[idx]
