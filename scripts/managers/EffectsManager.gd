extends Node
class_name EffectsManager

func attach_board(board: Node) -> void:
	if board == null or not is_instance_valid(board):
		return
	if board.has_signal("hard_drop"):
		board.connect("hard_drop", Callable(self, "_on_hard_drop"))
	if board.has_signal("rows_cleared"):
		board.connect("rows_cleared", Callable(self, "_on_rows_cleared"))
	if board.has_signal("rubble_spawned"):
		board.connect("rubble_spawned", Callable(self, "_on_rubble_spawned"))

func _on_hard_drop(dy: int) -> void:
	print("[VFX] camera_bump dy=", dy)

func _on_rows_cleared(y: int, span_count: int) -> void:
	print("[VFX] clear_burst y=", y, " spans=", span_count)

func _on_rubble_spawned(count: int) -> void:
	print("[VFX] rubble_dust count=", count)
