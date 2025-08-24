extends SceneTree
const BoardMask=preload("res://scripts/BoardMask.gd")

func _initialize():
	_test_row_counts()
	_test_top_rows()
	print("[MASK TESTS] ok")
	quit(0)

func _test_row_counts()->void:
	var m:=BoardMask.new()
	m.set_size(5,4)
	for y in 4:
		for x in 5:
			m.set_cell(x,y,true)
	m.set_cell(2,1,false)
	assert(m.row_playable_count(1)==4)
	assert(m.row_playable_count(0)==5)

func _test_top_rows()->void:
	var m:=BoardMask.new()
	m.set_size(3,4)
	m.set_cell(0,0,false); m.set_cell(0,1,true)
	m.set_cell(1,0,false); m.set_cell(1,1,false); m.set_cell(1,2,true)
	m.set_cell(2,0,true)
	assert(m.top_playable_row_for_col(0)==1)
	assert(m.top_playable_row_for_col(1)==2)
	assert(m.top_playable_row_for_col(2)==0)
