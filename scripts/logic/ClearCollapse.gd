extends Resource
class_name ClearCollapse

static func row_spans(board_mask, board_width:int, y:int) -> Array:
	var spans:Array[Vector2i]=[]
	var in_run:bool=false
	var x0:int=0
	for x in board_width:
		if board_mask.is_playable(x,y):
			if not in_run:
				in_run=true
				x0=x
		else:
			if in_run:
				spans.append(Vector2i(x0,x-1))
				in_run=false
	if in_run:
		spans.append(Vector2i(x0,board_width-1))
	return spans

static func find_full_spans(board_mask, board_width:int, board_height:int, occupied_positions:Dictionary) -> Array:
	var result:Array[Dictionary]=[]
	for y in range(board_height-1,-1,-1):
		var spans:=row_spans(board_mask,board_width,y)
		for seg in spans:
			var x0:int=seg.x
			var x1:int=seg.y
			var filled:bool=true
			for x in range(x0,x1+1):
				if not occupied_positions.has(Vector2i(x,y)):
					filled=false
					break
			if filled and x1>=x0:
				result.append({"y":y,"x0":x0,"x1":x1})
	return result

static func _has_mask_ceiling_between(board_mask, x:int, y_from:int, cleared_y:int) -> bool:
	for yy in range(y_from+1, cleared_y):
		if not board_mask.is_playable(x, yy):
			return true
	return false


static func collapse_passes(board_mask, board_width:int, board_height:int, cleared_y:int, spans_for_row:Array, snapshot:Dictionary) -> Array:
	var cleared_cols:=_cleared_columns_for_row(spans_for_row)
	if cleared_y<=0 or cleared_cols.is_empty():
		return []
	var colset:Dictionary={}
	for x in cleared_cols:
		colset[int(x)]=true
	var passes:Array=[]
	var moved_pids:Dictionary={}
	var moved_rubble:Dictionary={}
	while true:
		var moves:Array=[]
		var reserved:Dictionary={}
		var piece_cells_all:Dictionary={}
		var piece_intact:Dictionary={}
		var piece_has_elig:Dictionary={}
		var piece_all_above:Dictionary={}
		for pos in snapshot.keys():
			var meta:Dictionary=snapshot[pos]
			var pid:int=meta.get("pid",-1)
			if not piece_cells_all.has(pid):
				piece_cells_all[pid]=[]
				piece_intact[pid]=true
				piece_has_elig[pid]=false
				piece_all_above[pid]=true
			(piece_cells_all[pid] as Array).append(pos)
			if meta.get("rubble",false):
				piece_intact[pid]=false
			if colset.has(int(pos.x)):
				piece_has_elig[pid]=true
			if int(pos.y)>=cleared_y:
				piece_all_above[pid]=false
		var considered_pid:Dictionary={}
		for y in range(cleared_y-1,-1,-1):
			for xv in cleared_cols:
				var x:int=int(xv)
				var pos:=Vector2i(x,y)
				if not snapshot.has(pos):
					continue
				var meta:Dictionary=snapshot[pos]
				var pid:int=meta.get("pid",-1)
				# Rubble: skip if already moved; apply ceiling rule per-block
				if meta.get("rubble",false):
					if not moved_rubble.has(pos) and colset.has(x):
						if not _has_mask_ceiling_between(board_mask, x, y, cleared_y):
							var to_r:=Vector2i(x,y+1)
							if to_r.y<board_height and board_mask.is_playable(to_r.x,to_r.y) and not reserved.has(to_r) and not snapshot.has(to_r):
								moves.append({"from":pos,"to":to_r,"pid":pid,"rubble":true})
								reserved[to_r]=true
					continue
				# Intact piece: one move per piece; apply ceiling rule across ALL blocks
				if moved_pids.has(pid) or considered_pid.has(pid):
					continue
				considered_pid[pid]=true
				if not piece_intact.get(pid,false):
					continue
				if not piece_has_elig.get(pid,false):
					continue
				if not piece_all_above.get(pid,false):
					continue
				var cells:Array = piece_cells_all.get(pid,[])
				if cells.is_empty():
					continue
				var all_blocked_by_ceiling:bool=true
				for c in cells:
					if not _has_mask_ceiling_between(board_mask, int(c.x), int(c.y), cleared_y):
						all_blocked_by_ceiling=false; break
				if all_blocked_by_ceiling:
					continue
				var can_move:bool=true
				for c in cells:
					var to:=Vector2i(int(c.x),int(c.y)+1)
					if to.y>=board_height or not board_mask.is_playable(to.x,to.y):
						can_move=false; break
					if reserved.has(to):
						can_move=false; break
					if snapshot.has(to) and int((snapshot[to] as Dictionary).get("pid",-2))!=pid:
						can_move=false; break
				if can_move:
					for c2 in cells:
						var to2:=Vector2i(int(c2.x),int(c2.y)+1)
						moves.append({"from":Vector2i(int(c2.x),int(c2.y)),"to":to2,"pid":pid,"rubble":false})
						reserved[to2]=true
					moved_pids[pid]=true
		if moves.is_empty():
			break
		for m in moves:
			snapshot.erase(m["from"])
		for m in moves:
			var topos:Vector2i=m["to"]
			snapshot[topos]={"pid":m.get("pid",-1),"rubble":m.get("rubble",false)}
			if m.get("rubble",false):
				moved_rubble[topos]=true
		passes.append(moves)
	return passes

static func _cleared_columns_for_row(spans_for_row:Array) -> PackedInt32Array:
	var cols:=PackedInt32Array()
	var seen:Dictionary={}
	for seg in spans_for_row:
		var x0:int=seg["x0"]
		var x1:int=seg["x1"]
		for x in range(x0,x1+1):
			if not seen.has(x):
				seen[x]=true
				cols.append(x)
	cols.sort()
	return cols
