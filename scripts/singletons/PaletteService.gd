extends Node
class_name PaletteService

signal palette_changed(palette: PaletteData)

var _palette: PaletteData
const _DEFAULT_PATH := "res://resources/palettes/palette_default.tres"
const _HC_PATH := "res://resources/palettes/palette_high_contrast.tres"

func _ready() -> void:
	if typeof(Settings) != TYPE_NIL:
		Settings.connect("reloaded", Callable(self, "_on_settings_reloaded"))
		Settings.connect("changed", Callable(self, "_on_settings_changed"))
	_apply_from_settings()

func _on_settings_reloaded(_cfg) -> void:
	_apply_from_settings()

func _on_settings_changed(key: String, _v) -> void:
	if key == "palette" or key == "*":
		_apply_from_settings()

func _apply_from_settings() -> void:
	var name := "Default"
	if typeof(Settings) != TYPE_NIL and Settings.get_cfg() != null:
		name = Settings.get_cfg().palette
	var path := _DEFAULT_PATH
	var n := (name if name != null else "Default").strip_edges().to_lower()
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
	if _palette == null or _palette.piece_colors.is_empty():
		return Color.WHITE
	var h: int = abs(int(hash(key)))
	var size: int = _palette.piece_colors.size()
	var idx: int = h % size
	return _palette.piece_colors[idx]
