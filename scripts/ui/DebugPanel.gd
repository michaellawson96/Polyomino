extends Control
class_name DebugPanel

var palette_opt: OptionButton
var hard_chk: CheckBox
var ghost_slider: HSlider
var ghost_val: Label
var contrast_slider: HSlider
var contrast_val: Label

var _dragging: bool = false
var _drag_start: Vector2
var _panel_start: Vector2


func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_PASS
	position=Vector2(10,10)
	var panel:=PanelContainer.new()
	add_child(panel)
	var vb:=VBoxContainer.new()
	panel.add_child(vb)
	vb.custom_minimum_size=Vector2(260,0)
	var header:=HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.add_child(header)
	var title:=Label.new(); title.text="Debug (drag me)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.connect("gui_input", Callable(self, "_on_handle_gui_input"))
	var hb0:=HBoxContainer.new(); vb.add_child(hb0)
	var l0:=Label.new(); l0.text="Palette"; hb0.add_child(l0)
	palette_opt=OptionButton.new(); hb0.add_child(palette_opt)
	palette_opt.add_item("Default"); palette_opt.add_item("High Contrast")
	palette_opt.connect("item_selected",Callable(self,"_on_palette_selected"))
	var hb1:=HBoxContainer.new(); vb.add_child(hb1)
	hard_chk=CheckBox.new(); hard_chk.text="Hard Drop"; hb1.add_child(hard_chk)
	hard_chk.connect("toggled",Callable(self,"_on_hard_toggled"))
	var hb2:=HBoxContainer.new(); vb.add_child(hb2)
	var l2:=Label.new(); l2.text="Ghost"; hb2.add_child(l2)
	ghost_slider=HSlider.new(); ghost_slider.min_value=1.0; ghost_slider.max_value=8.0; ghost_slider.step=0.5; ghost_slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hb2.add_child(ghost_slider)
	ghost_val=Label.new(); hb2.add_child(ghost_val)
	ghost_slider.connect("value_changed",Callable(self,"_on_ghost_changed"))
	var hb3:=HBoxContainer.new(); vb.add_child(hb3)
	var l3:=Label.new(); l3.text="Grid"; hb3.add_child(l3)
	contrast_slider=HSlider.new(); contrast_slider.min_value=0.0; contrast_slider.max_value=1.0; contrast_slider.step=0.05; contrast_slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hb3.add_child(contrast_slider)
	contrast_val=Label.new(); hb3.add_child(contrast_val)
	contrast_slider.connect("value_changed",Callable(self,"_on_contrast_changed"))
	if typeof(Settings)!=TYPE_NIL:
		Settings.connect("reloaded",Callable(self,"_on_cfg"))
		Settings.connect("changed",Callable(self,"_on_cfg_kv"))
		_on_cfg(Settings.get_cfg())
	_add_blocks_opacity_control_at_bottom()

func _on_blocks_opacity_changed(v: float) -> void:
	if typeof(Settings) != TYPE_NIL:
		Settings.set_value("block_opacity", clamp(v, 0.0, 1.0))

func _on_cfg(cfg) -> void:
	if cfg==null: return
	var p: String = String(cfg.palette).strip_edges().to_lower()
	if p=="high contrast" or p=="high_contrast" or p=="highcontrast" or p=="hc": palette_opt.select(1)
	else: palette_opt.select(0)
	hard_chk.button_pressed=cfg.hard_drop_enabled
	ghost_slider.value=cfg.ghost_thickness
	ghost_val.text=str(snapped(cfg.ghost_thickness,0.1))
	contrast_slider.value=cfg.grid_contrast
	contrast_val.text=str(snapped(cfg.grid_contrast,0.01))

func _on_cfg_kv(_k:String,_v) -> void:
	_on_cfg(Settings.get_cfg())

func _on_palette_selected(index:int) -> void:
	var name:=("Default" if index==0 else "High Contrast")
	if typeof(Settings)!=TYPE_NIL: Settings.set_value("palette",name)

func _on_hard_toggled(pressed:bool) -> void:
	if typeof(Settings)!=TYPE_NIL: Settings.set_value("hard_drop_enabled",pressed)

func _on_ghost_changed(v:float) -> void:
	ghost_val.text=str(snapped(v,0.1))
	if typeof(Settings)!=TYPE_NIL: Settings.set_value("ghost_thickness",v)

func _on_contrast_changed(v:float) -> void:
	contrast_val.text=str(snapped(v,0.01))
	if typeof(Settings)!=TYPE_NIL: Settings.set_value("grid_contrast",v)

func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = get_viewport().get_mouse_position()
			_panel_start = global_position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = get_viewport().get_mouse_position() - _drag_start
		global_position = _panel_start + delta

func _find_first_vbox(n: Node) -> VBoxContainer:
	if n is VBoxContainer:
		return n as VBoxContainer
	for c in n.get_children():
		var r := _find_first_vbox(c)
		if r != null:
			return r
	return null

func _add_blocks_opacity_control_at_bottom() -> void:
	var host: VBoxContainer = _find_first_vbox(self)
	if host == null:
		host = VBoxContainer.new()
		host.name = "AutoVBox"
		add_child(host)
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_to_group("__blocks_opacity_controls__")
	host.add_child(box)
	var lbl := Label.new()
	lbl.text = "Blocks Opacity"
	box.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	var initial_a: float = 0.65
	if typeof(Settings) != TYPE_NIL and Settings.get_cfg() != null:
		initial_a = clamp(Settings.get_cfg().block_opacity, 0.0, 1.0)
	slider.value = initial_a
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(slider)
	slider.connect("value_changed", Callable(self, "_on_blocks_opacity_changed"))
	if self is Control:
		var cur: Vector2 = (self as Control).custom_minimum_size
		(self as Control).custom_minimum_size = Vector2(cur.x, cur.y + 56)
