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

static func collapse_passes(board_mask, board_width:int, board_height:int, cleared_y:int, spans_for_row:Array, snapshot:Dictionary) -> Array:
	var cleared_cols:=_cleared_columns_for_row(spans_for_row)
	if cleared_y<=0 or cleared_cols.is_empty():
		return []
	var colset:Dictionary={}
	for x in cleared_cols:
		colset[x]=true
	var col_list:Array=cleared_cols.duplicate()
	col_list.sort()
	var passes:Array=[]
	while true:
		var moves:Array=[]
		var reserved:Dictionary={}
		var piece_cells:Dictionary={}
		var piece_intact:Dictionary={}
		var piece_has_col:Dictionary={}
		var piece_all_above:Dictionary={}
		for y in range(cleared_y-1,-1,-1):
			for i in range(col_list.size()):
				var x:int=int(col_list[i])
				var cell:=Vector2i(x,y)
				if not snapshot.has(cell):
					continue
				var meta:Dictionary=snapshot[cell]
				var pid:int=meta.get("pid",-1)
				if not piece_cells.has(pid):
					piece_cells[pid]=[]
					piece_intact[pid]=true
					piece_has_col[pid]=false
					piece_all_above[pid]=true
				(piece_cells[pid] as Array).append(cell)
				if meta.get("rubble",false):
					piece_intact[pid]=false
				if colset.has(cell.x):
					piece_has_col[pid]=true
				if int(cell.y)>=cleared_y:
					piece_all_above[pid]=false
		for y in range(cleared_y-1,-1,-1):
			for i in range(col_list.size()):
				var x:int=int(col_list[i])
				var pos:=Vector2i(x,y)
				if not snapshot.has(pos):
					continue
				var meta:Dictionary=snapshot[pos]
				if meta.get("rubble",false):
					var to_r:=Vector2i(pos.x,pos.y+1)
					if to_r.y<board_height and board_mask.is_playable(to_r.x,to_r.y) and not reserved.has(to_r) and not snapshot.has(to_r):
						moves.append({"from":pos,"to":to_r,"pid":meta.get("pid",-1),"rubble":true})
						reserved[to_r]=true
					continue
				var pid:int=meta.get("pid",-1)
				if not piece_intact.get(pid,false):
					continue
				if not piece_has_col.get(pid,false):
					continue
				if not piece_all_above.get(pid,false):
					continue
				if piece_cells.has(pid):
					var cells:Array=piece_cells[pid]
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
						piece_cells.erase(pid)
		if moves.is_empty():
			break
		for m in moves:
			snapshot.erase(m["from"])
		for m in moves:
			var topos:Vector2i=m["to"]
			snapshot[topos]={"pid":m.get("pid",-1),"rubble":m.get("rubble",false)}
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
