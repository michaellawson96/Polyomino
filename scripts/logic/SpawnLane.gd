extends Resource
class_name SpawnLane

static func compute_top_rows(board_mask, board_width:int) -> PackedInt32Array:
	var a:=PackedInt32Array()
	a.resize(board_width)
	for x in board_width:
		a[x]=board_mask.top_playable_row_for_col(x)
	return a

static func snap_y_for_lane(top_rows:PackedInt32Array, board_width:int, gx:int, offsets:Array) -> int:
	var min_y:=999999
	for off in offsets:
		var cx:=gx+int(off.x)
		var top:= (top_rows[cx] if (cx>=0 and cx<board_width) else -1)
		if top<0:
			top=0
		var y_here:int=top-int(off.y)-1
		if y_here<min_y:
			min_y=y_here
	return min_y

static func can_step_right_in_lane(top_rows:PackedInt32Array, board_mask, board_width:int, board_height:int, next_x:int, offsets:Array) -> bool:
	for off in offsets:
		var cx:=next_x+int(off.x)
		if cx<0 or cx>=board_width:
			return false
		var top:=top_rows[cx]
		if top<0:
			return false
		var spawn_y:int=top-int(off.y)-1
		if spawn_y>=board_height:
			return false
		if spawn_y>=0 and not board_mask.is_playable(cx,spawn_y+1):
			pass
	return true

static func top_row_span_length(board_mask, board_width:int) -> int:
	var y:int=0
	var run:int=0
	var best:int=0
	var gaps:int=0
	for x in board_width:
		var p:bool=board_mask.is_playable(x,y)
		if p:
			run+=1
		else:
			if run>0:
				best=max(best,run)
				run=0
				gaps+=1
	if run>0:
		best=max(best,run)
		run=0
		gaps+=1
	if best==0: return 0
	if gaps>1: return -1
	return best

static func compute_piece_width(blocks:Array) -> int:
	if blocks.is_empty():
		return 1
	var minx:int=int(blocks[0].x)
	var maxx:int=int(blocks[0].x)
	for v in blocks:
		var ix:int=int(v.x)
		if ix<minx: minx=ix
		if ix>maxx: maxx=ix
	return (maxx-minx)+1

static func validate_entryway_for_bag(board_mask, board_width:int, ids:Array[String], poly_data) -> bool:
	var span:int=top_row_span_length(board_mask,board_width)
	if span<=0: return false
	if span==-1: return false
	var uniq:={}
	for id in ids:
		uniq[id]=true
	for id in uniq.keys():
		var blocks:Array=poly_data.get_blocks(String(id))
		if compute_piece_width(blocks)>span:
			return false
	return true
