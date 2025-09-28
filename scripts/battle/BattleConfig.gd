extends Resource
class_name BattleConfig

@export var notes: String = "Battle config."

# Piece hue + shades (used by BattleScene._apply_battle_palette_overrides)
@export var piece_base_color: Color = Color(0.20, 0.65, 0.95, 1.0)
@export var shade_min: float = 0.35
@export var shade_max: float = 0.85
@export var forced_piece_colors: Dictionary = {} # shape_key:String -> Color

# Points economy (Step 6)
@export var points_per_cell: int = 1
@export var combo_cap: int = 3

# Actions UI (Step 7)
@export var actions_always_visible: bool = true
@export var action_attack_label: String = "Attack"
@export var action_attack_cost: int = 5
@export var action2_id: String = ""
@export var action2_label: String = ""
@export var action2_cost: int = 0
@export var action3_id: String = ""
@export var action3_label: String = ""
@export var action3_cost: int = 0
@export var action4_id: String = ""
@export var action4_label: String = ""
@export var action4_cost: int = 0
