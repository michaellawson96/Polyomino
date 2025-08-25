extends Resource
class_name PlacementRules

static func can_place(board_mask, board_width:int, board_height:int, base:Vector2i, offsets:Array, occupied:Dictionary) -> bool:
	var bx:int=base.x
	var by:int=base.y
	for off in offsets:
		var nx:int=bx+int(off.x)
		var ny:int=by+int(off.y)
		if nx<0 or nx>=board_width:
			return false
		if ny>=board_height:
			return false
		if ny>=0 and not board_mask.is_playable(nx,ny):
			return false
		if ny>=0 and occupied.has(Vector2i(nx,ny)):
			return false
	return true

static func would_collide(board_mask, board_width:int, board_height:int, base:Vector2i, offsets:Array, delta:Vector2i, occupied:Dictionary) -> bool:
	var bx:int=base.x
	var by:int=base.y
	for off in offsets:
		var nx:int=bx+int(off.x)+int(delta.x)
		var ny:int=by+int(off.y)+int(delta.y)
		if nx<0 or nx>=board_width:
			return true
		if ny>=board_height:
			return true
		if ny>=0 and not board_mask.is_playable(nx,ny):
			return true
		if ny>=0 and occupied.has(Vector2i(nx,ny)):
			return true
	return false

static func hard_drop_delta(board_mask, board_width:int, board_height:int, base:Vector2i, offsets:Array, occupied:Dictionary) -> int:
	var dy:int=0
	while true:
		var collide:bool=false
		for off in offsets:
			var nx:int=base.x+int(off.x)
			var ny:int=base.y+int(off.y)+dy+1
			if nx<0 or nx>=board_width:
				collide=true; break
			if ny>=board_height:
				collide=true; break
			if ny>=0 and not board_mask.is_playable(nx,ny):
				collide=true; break
			if ny>=0 and occupied.has(Vector2i(nx,ny)):
				collide=true; break
		if collide:
			break
		dy+=1
	return dy
