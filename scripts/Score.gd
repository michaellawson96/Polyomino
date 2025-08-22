extends CanvasLayer

signal row_clear(count:int)
signal combo(count:int)
signal hard_drop(cells:int)
signal score_changed(score:int)

@export var config:ScoreConfig
@export var show_on_start:bool=false

var score:int=0
var chain:int=0
var label:RichTextLabel
var panel:Panel
var lines:Array[String]=[]

func _ready()->void:
	if config==null:
		config=preload("res://configs/score_config.tres")
	_make_ui()
	visible=show_on_start

func _input(e:InputEvent)->void:
	if e.is_action_pressed("ui_score_overlay"):
		visible=!visible

func _make_ui()->void:
	panel=Panel.new()
	add_child(panel)
	panel.anchor_left=1.0
	panel.anchor_top=0.0
	panel.anchor_right=1.0
	panel.anchor_bottom=0.0
	panel.offset_left=-360
	panel.offset_top=12
	panel.offset_right=-12
	panel.offset_bottom=260
	label=RichTextLabel.new()
	panel.add_child(label)
	label.fit_content=true
	label.size_flags_vertical=Control.SIZE_EXPAND_FILL
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_refresh()

func _push(s:String)->void:
	lines.append(s)
	if lines.size()>200:lines.pop_front()
	_refresh()

func _refresh()->void:
	if label==null:return
	var t=""
	for s in lines:t+=s+"\n"
	label.clear()
	label.append_text(t)

func note_rows_cleared(n:int)->void:
	if n<=0:
		note_lock_no_clear()
		return
	var add:int=0
	var idx:int=min(n,config.points_per_rows.size()-1)
	add+=config.points_per_rows[idx]
	if chain>0:add+=config.combo_step*chain
	score+=add
	chain+=1
	emit_signal("row_clear",n)
	emit_signal("combo",chain)
	emit_signal("score_changed",score)
	_push("[clear] rows="+str(n)+" chain="+str(chain)+" add="+str(add)+" score="+str(score))

func note_lock_no_clear()->void:
	if chain>0:_push("[chain reset] "+str(chain))
	chain=0
	emit_signal("combo",chain)
	emit_signal("score_changed",score)

func note_hard_drop(cells:int)->void:
	if cells<=0:return
	var add:int=cells*config.hard_drop_per_cell
	score+=add
	emit_signal("hard_drop",cells)
	emit_signal("score_changed",score)
	_push("[hard_drop] cells="+str(cells)+" add="+str(add)+" score="+str(score))
