extends Resource
class_name GameConfig

@export var gravity_cps: float = 1.0
@export var soft_drop_mult: float = 10.0
@export var hard_drop_enabled: bool = true

@export var clear_span_ms: int = 60
@export var clear_row_ms: int = 90

@export var rubble_jitter_px: int = 1
@export var rubble_opacity: float = 0.75

@export var ghost_thickness: float = 2.0
@export var grid_contrast: float = 0.35

@export var master_volume_db: float = 0.0
@export var sfx_volume_db: float = 0.0
@export var bgm_volume_db: float = 0.0

@export var palette: String = "Default"
