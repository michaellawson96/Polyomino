extends Node
class_name SettingsSingleton

signal changed(key: String, value)
signal reloaded(cfg: GameConfig)

var _cfg: GameConfig
var _cfg_path: String = "res://resources/default_game_config.tres"

func _ready() -> void:
	_reload_from_path(_cfg_path)

func _reload_from_path(p: String) -> void:
	var res := ResourceLoader.load(p)
	if res != null and res is GameConfig:
		_cfg = res
		emit_signal("reloaded", _cfg)
		emit_signal("changed", "*", null)

func get_cfg() -> GameConfig:
	return _cfg

func gravity_cps() -> float: return _cfg.gravity_cps
func soft_drop_mult() -> float: return _cfg.soft_drop_mult
func hard_drop_enabled() -> bool: return _cfg.hard_drop_enabled
func clear_span_ms() -> int: return _cfg.clear_span_ms
func clear_row_ms() -> int: return _cfg.clear_row_ms
func rubble_jitter_px() -> int: return _cfg.rubble_jitter_px
func rubble_opacity() -> float: return _cfg.rubble_opacity
func ghost_thickness() -> float: return _cfg.ghost_thickness
func grid_contrast() -> float: return _cfg.grid_contrast
func master_volume_db() -> float: return _cfg.master_volume_db
func sfx_volume_db() -> float: return _cfg.sfx_volume_db
func bgm_volume_db() -> float: return _cfg.bgm_volume_db
func palette() -> String: return _cfg.palette

func apply_config(cfg: GameConfig) -> void:
	if cfg == null: return
	_cfg = cfg
	emit_signal("reloaded", _cfg)
	emit_signal("changed", "*", null)

func set_value(key: String, value) -> void:
	if _cfg == null: return
	if not _cfg.has_method("get"): return
	_cfg.set(key, value)
	emit_signal("changed", key, value)
