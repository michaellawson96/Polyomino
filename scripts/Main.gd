extends Node

const BATTLE_SCENE := preload("res://scenes/BattleScene.tscn")
const DebugPanelScript := preload("res://scripts/ui/DebugPanel.gd")
const ACTION_TOGGLE_DEBUG := "toggle_debug_panel"

var _root_scene: Node = null
var debug_panel: DebugPanel = null

func _ready() -> void:
	_spawn_battle_scene()
	_ensure_debug_panel()
	_hide_debug_panel_on_boot()

func _spawn_battle_scene() -> void:
	if _root_scene != null and is_instance_valid(_root_scene):
		_root_scene.queue_free()
	_root_scene = BATTLE_SCENE.instantiate()
	add_child(_root_scene)

func _ensure_debug_panel() -> void:
	if debug_panel == null or not is_instance_valid(debug_panel):
		debug_panel = DebugPanelScript.new()
		add_child(debug_panel)

func _hide_debug_panel_on_boot() -> void:
	if debug_panel and debug_panel is CanvasItem:
		(debug_panel as CanvasItem).visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_TOGGLE_DEBUG):
		if debug_panel != null and is_instance_valid(debug_panel):
			debug_panel.visible = not debug_panel.visible
