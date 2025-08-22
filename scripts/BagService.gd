extends RefCounted
class_name BagService

var _allowed:Array= []
var _bag:Array= []
var _idx:int= 0
var _rng:RandomNumberGenerator= RandomNumberGenerator.new()
var _seed:int= 0

func setup(pieces:Array,seed:int=0)->void:
	_allowed=pieces.duplicate(true)
	_seed=seed
	if seed!=0:
		_rng.seed=seed
	else:
		_rng.randomize()
	_refill()

func next()->Variant:
	if _bag.is_empty():return null
	if _idx>=_bag.size():_refill()
	var v=_bag[_idx]
	_idx+=1
	return v

func peek(n:int)->Array:
	var out:Array=[]
	if n<=0:return out
	var i=_idx
	var bag=_bag
	var bag_size=bag.size()
	if bag_size==0:return out
	while out.size()<n:
		if i>=bag_size:
			bag=_shuffled_copy(_allowed)
			bag_size=bag.size()
			i=0
		out.append(bag[i])
		i+=1
	return out

func remaining_in_bag()->int:
	if _bag.is_empty():return 0
	return _bag.size()-_idx

func allowed()->Array:
	return _allowed.duplicate(true)

func seed()->int:
	return _seed

func _refill()->void:
	_bag=_shuffled_copy(_allowed)
	_idx=0

func _shuffled_copy(src:Array)->Array:
	var arr=src.duplicate(true)
	var n=arr.size()
	for i in range(n-1,0,-1):
		var j=_rng.randi_range(0,i)
		var tmp=arr[i]
		arr[i]=arr[j]
		arr[j]=tmp
	return arr
