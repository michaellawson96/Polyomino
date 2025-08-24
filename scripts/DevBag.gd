extends Node

var set_a: Array[String] = ["M1"]
var set_b: Array[String] = ["L3"]

func _unhandled_input(e:InputEvent)->void:
	if e.is_action_pressed("ui_bag_set_a"):
		_apply(set_a,42)
	if e.is_action_pressed("ui_bag_set_b"):
		_apply(set_b,77)

func _apply(ids:Array[String],seed:int)->void:
	var b:=get_tree().get_first_node_in_group("board")
	if b!=null and b.has_method("reconfigure_bag"):
		var ok:bool=b.reconfigure_bag(ids,seed)
		if not ok:
			print("[Bag] reconfigure rejected by entryway rule")
