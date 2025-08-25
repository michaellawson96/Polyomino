extends Node

const BagService= preload("res://scripts/BagService.gd")

var _ok:int=0
var _fail:int=0

func _ready()->void:
	_test_no_repeats_within_bag()
	_test_multiple_bags_no_repeats_per_segment()
	_test_seed_determinism()
	_done()

func _assert(cond:bool,msg:String)->void:
	if cond:_ok+=1
	else:
		_fail+=1
		print("[FAIL] "+msg)

func _gen_ids(n:int)->Array[String]:
	var out:Array[String]=[]
	for i in n:
		out.append("P"+str(i))
	return out

func _test_no_repeats_within_bag()->void:
	for n in range(3,13):
		var ids=_gen_ids(n)
		var bag:=BagService.new()
		bag.setup(ids,123)
		var seen:= {}
		for i in n:
			var v=bag.next()
			seen[v]=true
		_assert(seen.keys().size()==n,"no_repeats_within_bag n="+str(n))
		_assert(bag.remaining_in_bag()==0,"remaining_zero_after_full_bag n="+str(n))

func _test_multiple_bags_no_repeats_per_segment()->void:
	for n in range(3,13):
		var ids=_gen_ids(n)
		var bag:=BagService.new()
		bag.setup(ids,456)
		var total=int(n*3)
		var seq:Array=[]
		for i in total:
			seq.append(bag.next())
		for seg in range(0,total,n):
			var s:= {}
			for i in range(seg,seg+n):
				s[seq[i]]=true
			_assert(s.keys().size()==n,"segment_unique n="+str(n)+" seg="+str(seg/n))

func _test_seed_determinism()->void:
	var ids=_gen_ids(7)
	var a:=BagService.new()
	var b:=BagService.new()
	a.setup(ids,999)
	b.setup(ids,999)
	var s1:Array=[]
	var s2:Array=[]
	for i in 21:
		s1.append(a.next())
		s2.append(b.next())
	_assert(s1==s2,"deterministic_same_seed")
	var c:=BagService.new()
	c.setup(ids,1001)
	var diff:=false
	for i in 21:
		if s1[i]!=c.next():diff=true;break
	_assert(diff,"different_seed_differs")

func _done()->void:
	print("[TESTS] ok="+str(_ok)+" fail="+str(_fail))
	if _fail>0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
