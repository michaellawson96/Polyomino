extends Node

const BoardScene := preload("res://scenes/Board.tscn")
const BoardMask := preload("res://scripts/BoardMask.gd")
const TestBlock := preload("res://tests/TestBlock.gd")

func _ready():
	var ok1: bool = _test_intact_pieces_drop_one_when_eligible()
	var ok2: bool = _test_mask_corridor_blocks_drop()
	var ok3: bool = _test_rubble_drops_one_and_intact_stays_if_blocked()
	var pass_count: int = int(ok1) + int(ok2) + int(ok3)
	if pass_count == 3:
		print("[MASK GRAVITY TESTS] ok=3 fail=0")
		get_tree().quit(0)
	else:
		print("[MASK GRAVITY TESTS] ok=", pass_count, " fail=", 3 - pass_count)
		get_tree().quit(1)

func _make_board(w: int, h: int) -> Node:
	var b: Node = BoardScene.instantiate()
	get_tree().root.add_child(b)
	b.board_width = w
	b.board_height = h
	b.cell_size = 16
	if b.board_mask == null:
		b.board_mask = BoardMask.new()
	b.board_mask.set_size(w, h)
	b._recompute_mask_caches()
	return b

func _set_mask_all_playable(b: Node) -> void:
	for y in range(b.board_height):
		for x in range(b.board_width):
			b.board_mask.set_cell(x, y, true)
	b._recompute_mask_caches()

func _place(b: Node, pid: int, rubble: bool, cell: Vector2i) -> TestBlock:
	var blk: TestBlock = TestBlock.new()
	blk.piece_id = pid
	blk.rubble = rubble
	blk.set_grid_cell(cell)
	blk.position = (Vector2(cell) * b.cell_size).floor()
	b.add_child(blk)
	b._occupied[cell] = blk
	return blk

func _make_spans_for_row(b: Node, y: int) -> Array:
	var spans: Array = b._row_spans(y)
	var out: Array = []
	for seg in spans:
		out.append({"y": y, "x0": int(seg.x), "x1": int(seg.y)})
	return out

func _assert(cond: bool, msg: String) -> bool:
	if not cond:
		print("[FAIL] ", msg)
	return cond

func _test_intact_pieces_drop_one_when_eligible() -> bool:
	var b: Node = _make_board(6, 5)
	_set_mask_all_playable(b)
	var cleared_y: int = 3
	var row_spans: Array = []
	row_spans.append({"y": cleared_y, "x0": 0, "x1": 5})
	var _p1a: TestBlock = _place(b, 1, false, Vector2i(1, 0))
	var _p1b: TestBlock = _place(b, 1, false, Vector2i(2, 0))
	var _p2a: TestBlock = _place(b, 2, false, Vector2i(1, 1))
	var _p2b: TestBlock = _place(b, 2, false, Vector2i(2, 1))
	var _p3a: TestBlock = _place(b, 3, false, Vector2i(4, 0))
	var _p3b: TestBlock = _place(b, 3, false, Vector2i(4, 1))
	var cleared: Dictionary = {}
	b._masked_collapse_after_clear_one_row(cleared, cleared_y, row_spans)
	var ok: bool = true
	ok = _assert(b._occupied.has(Vector2i(1, 1)), "piece 1 (1,0)->(1,1)") and ok
	ok = _assert(b._occupied.has(Vector2i(2, 1)), "piece 1 (2,0)->(2,1)") and ok
	ok = _assert(b._occupied.has(Vector2i(1, 2)), "piece 2 (1,1)->(1,2)") and ok
	ok = _assert(b._occupied.has(Vector2i(2, 2)), "piece 2 (2,1)->(2,2)") and ok
	ok = _assert(b._occupied.has(Vector2i(4, 1)), "piece 3 (4,0)->(4,1)") and ok
	ok = _assert(b._occupied.has(Vector2i(4, 2)), "piece 3 (4,1)->(4,2)") and ok
	return ok

func _test_mask_corridor_blocks_drop() -> bool:
	var b: Node = _make_board(6, 5)
	_set_mask_all_playable(b)
	for y in range(b.board_height):
		b.board_mask.set_cell(2, y, false)
	b._recompute_mask_caches()
	var cleared_y: int = 3
	var row_spans: Array = []
	row_spans.append({"y": cleared_y, "x0": 0, "x1": 5})
	var _a1: TestBlock = _place(b, 1, false, Vector2i(1, 1))
	var _a2: TestBlock = _place(b, 1, false, Vector2i(1, 2))
	var _a3: TestBlock = _place(b, 1, false, Vector2i(1, 0))
	var _b3: TestBlock = _place(b, 3, false, Vector2i(3, 1))
	var _b4: TestBlock = _place(b, 3, false, Vector2i(3, 2))
	var _b5: TestBlock = _place(b, 3, false, Vector2i(3, 0))
	var cleared: Dictionary = {}
	b._masked_collapse_after_clear_one_row(cleared, cleared_y, row_spans)
	var ok: bool = true
	ok = _assert(b._occupied.has(Vector2i(1, 1)), "left piece corridor blocked") and ok
	ok = _assert(b._occupied.has(Vector2i(3, 2)), "right piece drops one") and ok
	return ok

func _test_rubble_drops_one_and_intact_stays_if_blocked() -> bool:
	var b: Node = _make_board(6, 5)
	_set_mask_all_playable(b)
	var cleared_y: int = 3
	var row_spans: Array = []
	row_spans.append({"y": cleared_y, "x0": 1, "x1": 4})
	var _intact_a: TestBlock = _place(b, 7, false, Vector2i(0, 1))
	var _intact_b: TestBlock = _place(b, 7, false, Vector2i(0, 2))
	var _rubble1: TestBlock = _place(b, 9, true, Vector2i(2, 1))
	var _rubble2: TestBlock = _place(b, 9, true, Vector2i(3, 2))
	var _blocker: TestBlock = _place(b, 8, false, Vector2i(2, 2))
	var cleared: Dictionary = {}
	b._masked_collapse_after_clear_one_row(cleared, cleared_y, row_spans)
	var ok: bool = true
	ok = _assert(b._occupied.has(Vector2i(0, 1)), "intact outside cleared columns stays") and ok
	ok = _assert(b._occupied.has(Vector2i(2, 1)), "rubble at (2,1) blocked by (2,2)") and ok
	ok = _assert(not b._occupied.has(Vector2i(3, 3)), "rubble (3,2) cannot fall out of board") and ok
	return ok
