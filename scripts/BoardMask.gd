extends Resource
class_name BoardMask

@export var width:int=10
@export var height:int=20
var data:PackedByteArray=PackedByteArray()

func set_size(w:int,h:int)->void:
	width=w
	height=h
	data.resize(w*h)
	for i in data.size():
		data[i]=1

func is_playable(x:int,y:int)->bool:
	if x<0 or x>=width or y<0 or y>=height:
		return false
	return data[y*width+x]==1

func set_cell(x:int,y:int,playable:bool)->void:
	if x<0 or x>=width or y<0 or y>=height:
		return
	data[y*width+x] = 1 if playable else 0


func row_playable_count(y:int)->int:
	if y<0 or y>=height:
		return 0
	var c:int=0
	var base:=y*width
	for x in width:
		if data[base+x]==1:
			c+=1
	return c

func top_playable_row_for_col(x:int)->int:
	if x<0 or x>=width:
		return -1
	for y in height:
		if data[y*width+x]==1:
			return y
	return -1

func from_image(img:Image, threshold:float=0.5)->void:
	var w:int = min(img.get_width(), width)
	var h:int = min(img.get_height(), height)
	for y in h:
		for x in w:
			var c:=img.get_pixel(x,y).v
			set_cell(x,y,c>=threshold)
