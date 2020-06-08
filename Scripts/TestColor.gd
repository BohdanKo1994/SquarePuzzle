extends Spatial

onready var puzzleRoot = get_node("/root/SceneTop/PuzzleRoot")
onready var boxPref = load("res://Prefabs/BoxOfPlanes.tscn")
onready var camera = get_viewport().get_camera()

var matrix = []
var levels = []
var selectedLvl = 0

var squareSize = 3
var finishedImg = []

var rotFinish:bool = true
var rotSpeed:float = 5

var spreaded:bool = false
var selectedBoxes = []

var rng = RandomNumberGenerator.new()

#input
var mpresd:bool = false
var mstartpos:Vector2 = Vector2.ZERO
var goDown:Vector3 = Vector3(999,999,999)

#UI
onready var scoreBar = get_node("/root/SceneTop/UI/scoreBar")

class Level_data:
	var name: String
	var imgCollectionPaths = []

class Box:
	var ic:int
	var ix:int
	var iy:int
	var normalPos:Vector3
	var spredPos:Vector3
	var goalPos:Array
	var goalRot:Transform
	var pooledUp:bool = false
	var busy:bool = false
	#var swapingFor = null
	var spt:Spatial


func _ready():
	LoadLevelData()
	SpawnLevel()

func _process(delta):
	ProccessMouse()
	MoveBoxes(delta)
	RotBox(delta)

	if Input.is_action_just_released("ui_down"): # Probbaly attack to UI button or i personaly would to double tap if phone
		print("Spread toogle")
		if spreaded:
			spreaded = false
		else:
			spreaded = true

		#test
		for x in range(squareSize):
			for y in range(squareSize):
				if spreaded:
					matrix[x][y].goalPos.append( matrix[x][y].spredPos )
				else:
					matrix[x][y].goalPos.append( matrix[x][y].normalPos )

#LEVEL SETUP STUFF
func LoadLevelData():

	var dir = Directory.new()
	if !dir.dir_exists("res://Levels"):
		printerr("Missing Levels dir")
		push_error("Missing Levels dir")
		get_tree().quit()
	else:
		printerr("Dir found")

	if dir.open("res://Levels") == OK:
		#printerr("aaaa")
		dir.list_dir_begin(true,true)
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				#print("Found directory: " + file_name)
				var subdir = Directory.new()
				#print("Levels"+file_name)
				if subdir.open("res://Levels/"+file_name) == OK:
					printerr(file_name)
					var ld = Level_data.new()
					subdir.list_dir_begin(true,true)
					ld.name = file_name
					var fn = subdir.get_next()
					while fn !="":

						var fnn = ""
						printerr(fn)
						if fn.ends_with(".import"):
							printerr(" N ", fn)
							fnn = fn.replace(".import", "")

						if fnn.length() > 5 && fnn.right(fnn.length() - 4) == ".png":
							ld.imgCollectionPaths.append("res://Levels/"+file_name+"/"+fnn)
						fn = subdir.get_next()

						# if fn.length() > 5 && fn.right(fn.length() - 4) == ".png":
						# 	ld.imgCollectionPaths.append("res://Levels/"+file_name+"/"+fn)
						# fn = subdir.get_next()
					#levels.append(ld)
					if ld.imgCollectionPaths.size() == 6:
						levels.append(ld)
						print("Added lvl "+ ld.name)
					else:
						print("found only " + str(ld.imgCollectionPaths.size()) + " images, skipping lvl " + ld.name)
				else:
					print("Eroor while opening subdir")
				subdir.list_dir_end()
			file_name = dir.get_next()
		dir.list_dir_end ()
	else:
		printerr("An error occurred when trying to access the path.")


	# debug
	# print(levels.size())
	# print(levels[0].name)
	# print(levels[0].imgCollectionPaths.size())

func SpawnLevel():
	randomize()

	#create jagged array  [x][y] :)
	for x in range(squareSize):
		matrix.append([])
		for y in range(squareSize):
			matrix[x].append([])
		

	var boxes = []
	var sinfo = []

	#create materials and side names
	for x in range(squareSize):
		for y in range(squareSize):
			for n in range(6):
				# so evry box multyply by 6 sides
				var sm:SpatialMaterial = SpatialMaterial.new()
				var st = load(levels[selectedLvl].imgCollectionPaths[n])
				sm.set_texture(0,st)
				sm.set_uv1_scale(Vector3( 0.99/squareSize,0.99/squareSize,0.99/squareSize))
				sm.set_uv1_offset(Vector3( 0.99/squareSize*y,0.99/squareSize*x,0))
				#smats.append(sm)
				var nam:String = str(n) + ";" + str(y) + ";" + str(x)
				#snames.append(nam)
				sinfo.append( [sm, nam] )

	sinfo.shuffle() #randomize order

	#Create boxes 
	for x in range(squareSize):
		for y in range(squareSize):
			var b = Box.new()
			b.spt = boxPref.instance()
			puzzleRoot.add_child(b.spt)
			boxes.append(b)
	
	#add side infos to boxes
	while !sinfo.empty():
		var take1 = sinfo.pop_back() #first is mat, sec name
		
		for b in boxes:
			var used = false
			var firstc = []
			#get all first letters
			for c in range(6):
				firstc.append(b.spt.get_child(c).name[0])
			
			if firstc.has( take1[1][0] ):  #take1[1][0] = frist char of name
				continue #if it allready exists we go some other box cuz cant have 1 box
				#with 2 sides of same img
			else:
				#change first free ocurence of side
				for c in range(6):
					var s = b.spt.get_child(c)
					if s.name[0] == "s": #its free
						s.set_name(take1[1])
						s.set_surface_material(0,take1[0])
						used = true
						break
			if used:
				break


	#then we plant boxes at place
	var x = 0
	var y = 0

	for b in boxes:
		if squareSize % 2 == 0:
			var startSpred:float = 1.5 + (squareSize/2)*-3
			b.spredPos = Vector3(startSpred + x*3, 0 , startSpred + y*3) 
			var startNormal:float = 1 - squareSize
			b.normalPos = Vector3(startNormal + x*2,0, startNormal + y*2)

		else:
			var startSpred:float = -3*((squareSize-1)/2)
			b.spredPos = Vector3( startSpred + x*3, 0, startSpred + y*3) 
			var startNormal:float = -2*((squareSize-1)/2)
			b.normalPos = Vector3(startNormal + x*2, 0, startNormal + y*2 )

		b.spt.set_translation( b.normalPos )
		matrix[x][y] = b
		x = x + 1
		if x >= squareSize:
			x = 0
			y = y + 1


	#update box class value so all work nice
	for b in boxes:
		UpdateValue(b)


func UpdateValue(box:Box):
	for s in range(6):

		#get front facing side and read its name and save is as value for compering
		if box.spt.get_child(s).global_transform.origin.y > box.spt.global_transform.origin.y + 0.5:
			var data = box.spt.get_child(s).name.split(';')
			box.ic = data[0]
			box.ix = data[1]
			box.iy = data[2]
			break


#MOTION
func MoveBoxes(delta):
	var checkPuzzle:bool = false

	for x in squareSize:
		for y in squareSize:
			if matrix[x][y].goalPos.empty():
				pass
			else:# if box hes a destintation to move
				var to:Vector3 = matrix[x][y].goalPos[0]
				if to == goDown: #using this as pulldown, should rewrited a lot :)
					matrix[x][y].pooledUp = false
					matrix[x][y].goalPos.remove(0)
					return


				if matrix[x][y].pooledUp:
					to = Vector3(to.x, 5, to.z)
				else:
					to = Vector3(to.x, 0, to.z)

				#direction to move to
				var dir = (to - matrix[x][y].spt.transform.origin )
				matrix[x][y].spt.global_translate(dir * 10 * delta)

				if matrix[x][y].spt.get_global_transform().origin.distance_to(to)  < 0.005: #if it reach waypoint enought
					matrix[x][y].spt.set_translation(to) # set to exact pos
					matrix[x][y].goalPos.remove(0)

					if matrix[x][y].goalPos.empty():
						matrix[x][y].busy = false #finished trevel to end pos
						
						#confirm somebox moved back to place
						if !matrix[x][y].pooledUp:
							UpdateValue(matrix[x][y])
							checkPuzzle = true

	if !checkPuzzle:
		return
	#so if something moved back first we need to check if there is nothing still up or moving
	for x in squareSize:
		for y in squareSize:
			if matrix[x][y].pooledUp or matrix[x][y].busy:
				return
	#so if its end of move we can now check if we matched puzzle nice
	print("Checking puzzle")
	CheckPuzzle()

func RotBox(delta):
	rotSpeed = rotSpeed + (50*delta)


	if !rotFinish and !selectedBoxes.empty():

		var atmT = selectedBoxes[0].spt.transform
		if selectedBoxes[0].goalRot.is_equal_approx(atmT):#we finished rot
			#print("finisehd rot")
			rotFinish = true
		else:
			selectedBoxes[0].spt.transform = selectedBoxes[0].spt.transform.interpolate_with(selectedBoxes[0].goalRot, rotSpeed*delta)




	
#GAME LOGIC
func SelectBox(x:int,y:int):
	#print("x:",x, " y:",y)
	#print(matrix[x][y].spt.transform.origin)

	var bpos = matrix[x][y].spt.get_global_transform().origin

	if selectedBoxes.empty():
		print("selecting first")
		selectedBoxes.append(matrix[x][y])
		selectedBoxes[0].pooledUp = true
		matrix[x][y].goalPos.append( Vector3(bpos.x, 1, bpos.z) )
		matrix[x][y].busy = true

	elif selectedBoxes[0] == matrix[x][y]: # if we selected same box again we diselect
		print("selected same")
		matrix[x][y].goalPos.append( goDown )
		matrix[x][y].goalPos.append( Vector3(bpos.x, 0, bpos.z) )
		rotFinish = true
		matrix[x][y].busy = true
		selectedBoxes.clear()
	else: #we selected some other box then we swap pos
		print("swaping")
		var b1 = selectedBoxes[0]
		var b1x = null
		var b1y
		var b1spos = selectedBoxes[0].spt.global_transform.origin # care this is allread pulled 
		var b2 = matrix[x][y]
		var b2x = null	
		var b2y
		var b2spos  = matrix[x][y].spt.global_transform.origin

		b1.busy  = true;
		b2.busy  = true;

		selectedBoxes.clear()
		
		#should have probably put matrix X and Y values in boxes itself, DUNO WHY I STARTED WITH MATRIX AT ALL
		for x in squareSize:
			for y in squareSize:
				if b1.spt == matrix[x][y].spt:
					b1x = x
					b1y = y
				if b2.spt == matrix[x][y].spt:
					b2x = x
					b2y = y
				
				if b1x != null and b2x != null:
					break
			if b1x != null and b2x != null:
				break

		#first pull up second box we clicked
		b2.pooledUp = true
		b2.goalPos.append( Vector3(bpos.x, 1, bpos.z) )
		yield(get_tree().create_timer(0.5), "timeout")
		
		#and need end end to swap in matrix and poses
		matrix[b2x][b2y] = b1
		matrix[b1x][b1y] = b2
		var nPos = b1.normalPos
		var sPos = b1.spredPos
		b1.normalPos = b2.normalPos
		b1.spredPos = b2.spredPos
		b2.normalPos = nPos
		b2.spredPos = sPos

		#now need to figure out swap waypoints
		if b1x == b2x: 
			print("samecolum")
			var sidedir
			if b1x == 0:
				sidedir = 1
			elif b1x == squareSize-1:
				sidedir = -1
			else:
				sidedir = rng.randi_range(0,1) * 2 - 1

			sidedir = sidedir * 2 if !spreaded else sidedir * 3

			#move b1
			b1.goalPos.append(b1spos + Vector3.RIGHT * sidedir)
			b1.goalPos.append(b2spos + Vector3.RIGHT * sidedir)
			b1.goalPos.append(b2spos)
			b1.goalPos.append(goDown)
			b1.goalPos.append(Vector3(b2spos.x, 0, b2spos.z))

			#move b2
			yield(get_tree().create_timer(0.5), "timeout")
			b2.goalPos.append(b1spos)
			b2.goalPos.append(goDown)
			b2.goalPos.append(b1spos)
			b2.goalPos.append(goDown)
			b2.goalPos.append(Vector3(b1spos.x, 0, b1spos.z))
			

		elif b1y == b2y:
			print("samerow")
			var updir

			if b1y == 0:
				updir = -1
			elif b1y == squareSize-1:
				updir = 1
			else:
				updir = rng.randi_range(0,1) * 2 - 1

			updir = updir * 2 if !spreaded else updir * 3

			#move b1
			b1.goalPos.append(b1spos + Vector3.FORWARD * updir)
			b1.goalPos.append(b2spos + Vector3.FORWARD * updir)
			b1.goalPos.append(b2spos)
			b1.goalPos.append(goDown)
			b1.goalPos.append(Vector3(b2spos.x, 0, b2spos.z))

			#move b2
			yield(get_tree().create_timer(0.5), "timeout")
			b2.goalPos.append(b1spos)
			b2.goalPos.append(goDown)
			b2.goalPos.append(b1spos)
			b2.goalPos.append(goDown)
			b2.goalPos.append(Vector3(b1spos.x, 0, b1spos.z))

		else:
			print("diferent row and colum")

			#move b1
			b1.goalPos.append( Vector3(b1spos.x, 5, b2spos.z) )
			b1.goalPos.append( Vector3(b2spos.x, 5, b2spos.z) )
			b1.goalPos.append( goDown )
			b1.goalPos.append( b2spos )

			#move b2
			b2.goalPos.append( Vector3( b2spos.x, 5, b1spos.z) )
			b2.goalPos.append( Vector3( b1spos.x, 5, b1spos.z) )
			b2.goalPos.append( goDown )
			b2.goalPos.append( Vector3( b1spos.x, 0, b1spos.z) )
		
func SetRot(dir):
	rotSpeed = 5 
	
	if !selectedBoxes.empty() and rotFinish:
		selectedBoxes[0].spt.transform = selectedBoxes[0].spt.transform.orthonormalized()
		rotFinish = false
		match dir:
			"up":
				selectedBoxes[0].goalRot = selectedBoxes[0].spt.transform.rotated(Vector3(1,0,0),deg2rad(-90))
				selectedBoxes[0].goalRot.origin = selectedBoxes[0].spt.transform.origin

			"down":
				selectedBoxes[0].goalRot = selectedBoxes[0].spt.transform.rotated(Vector3(1,0,0),deg2rad(90))
				selectedBoxes[0].goalRot.origin = selectedBoxes[0].spt.transform.origin
			
			"left":
				selectedBoxes[0].goalRot = selectedBoxes[0].spt.transform.rotated(Vector3(0,0,1),deg2rad(90))
				selectedBoxes[0].goalRot.origin = selectedBoxes[0].spt.transform.origin
			
			"right":
				selectedBoxes[0].goalRot = selectedBoxes[0].spt.transform.rotated(Vector3(0,0,1),deg2rad(-90))
				selectedBoxes[0].goalRot.origin = selectedBoxes[0].spt.transform.origin

			"clockwise":
				selectedBoxes[0].goalRot = selectedBoxes[0].spt.transform.rotated(Vector3(0,1,0),deg2rad(-90))
				selectedBoxes[0].goalRot.origin = selectedBoxes[0].spt.transform.origin

			"counter_clockwise":
				selectedBoxes[0].goalRot = selectedBoxes[0].spt.transform.rotated(Vector3(0,1,0),deg2rad(90))
				selectedBoxes[0].goalRot.origin = selectedBoxes[0].spt.transform.origin

func CheckPuzzle():
	var lookingImg

	#var text = " "

	for y in squareSize:
		for x in squareSize:

			if x==0 and y==0:
				#first we check if first img in allreayd finished lvl
				if finishedImg.has(matrix[x][y].ic):
					print("allready got score for this img")
					return #cuz no need to check then
				
				# we collect first img for compering
				lookingImg = matrix[x][y].ic

			#now we check againts that first img 
			if matrix[x][y].ic != lookingImg:
				print("not same img")
				return;

			#then we check if box img exists


			#then we check if box/img is in good oriontation cuz if not
			var ch = str(matrix[x][y].ic) + ";" + str(matrix[x][y].ix) + ";" +str(matrix[x][y].iy)
			var chnode = matrix[x][y].spt.get_node(ch)


			if !matrix[x][y].spt.get_node(ch).global_transform.basis.z.z > 0.99:
				print("wrong rot")
				return # terminate too :)


			#ok so now  we need to start checking for chain 
			if matrix[x][y].ix != x or matrix[x][y].iy != y:
				print("no row")
				return # cuz ye its not in row
				

	#IF IT DID NOT RETURN BY NOW, IT MEANS WE SOLVED THIS PUZZLE IMG
	finishedImg.append(lookingImg)
	print("SOLVED PUZZLE IMG")
	scoreBar.value = scoreBar.value + 1 #increse UI score






#INPUT CONTROLS STUFF
func ProccessMouse():

	for x in range(squareSize):
		for y in range(squareSize):
			if matrix[x][y].busy:
				return


	
	
		
	if Input.is_action_just_released("MouseL") and mpresd==true:
		mpresd = false
		if mstartpos.distance_to(get_viewport().get_mouse_position()) >  get_viewport().size.x/(4*4) :
			var dir = (mstartpos - get_viewport().get_mouse_position()).normalized()
			#print("its a swipe")
			#print(dir)
			if abs(dir.x) > abs(dir.y):
				if dir.x > 0 :
					print("swiped left")
					SetRot("left")
				else:
					print("swiped right")
					SetRot("right")
			else:
				if dir.y > 0 :
					print("swiped up")
					SetRot("up")
				else:
					print("swiped down")
					SetRot("down")
		else:
			print("its a click")
			ProcessClicks()


	if Input.is_action_just_pressed("MouseL"):
		mpresd = true
		mstartpos = get_viewport().get_mouse_position()

func RotateClockwise():
	print("clockwise")
	SetRot("clockwise")

func RotateCounterClockwise():
	print("counterClockwise")
	SetRot("counter_clockwise")

func ProcessClicks():
	var ray_lenght = 200
	var from = camera.project_ray_origin(mstartpos)
	var to = from + camera.project_ray_normal(mstartpos) * ray_lenght
	
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray( from, to )
	if !result.empty():

		var p = result['collider'].get_parent()
		for x in squareSize:
			for y in squareSize:
				if p == matrix[x][y].spt:
					#print(p.name, " is box x:", x, " y:", y )
					#print("img: ",matrix[x][y].ic, " ix:", matrix[x][y].ix, " iy:", matrix[x][y].iy)
					SelectBox(x,y);
					break
	else:
		print("Clicked in empty space")
