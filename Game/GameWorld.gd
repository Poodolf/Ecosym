extends Node2D

signal started
signal finished

var _rng = RandomNumberGenerator.new()
var d = {"map_data": {}}
var new_map := false
var tile_pos
var firebase_db_map_data
var listener_map_data
var firestore_map_data
var firestore_users

onready var _tilemap = $Navigation2D/TileMap
onready var _tilemap_obj = $Navigation2D/TileMapObj
onready var _tilemap_img = $Navigation2D/TileMapImg
onready var _tile_view = preload("res://Game/ui/TileView.tscn")

export var size_units = Vector2(32,18)

const CUSTOM_OFFSET_X = 0
const CUSTOM_OFFSET_Y = 36
const ressource = {
	0: "can",
	1: "cargo",
	2: "crystal",
	3: "wheat",
	4: "wood",
	5: "oil",
	6: "coal",
	7: "stone",
	8: "",
	9: "",
}

func _ready() -> void:
	#firebase_db_map_data = Firebase.Database.get_database_reference("game/map_data", {})
	listener_map_data = Firebase.Database.get_database_reference("game", { })
	listener_map_data.connect("patch_data_update", self, "on_received_updated_map")
	listener_map_data.connect("new_data_update", self, "on_received_new_map")
	#firestore_map_data = Firebase.Firestore.collection("map_data")
	firestore_users = Firebase.Firestore.collection("users")
	#firestore_map_data.connect("get_document", self, "_on_get_doc_received")
	#firestore_map_data.connect("error", self, "on_error_received")
	#firestore_map_data.get("world")

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and not $CanvasLayer/TileView.visible and Input.is_action_pressed("main_click"):
			var pos = event.position
			var camera_pos = $KinematicBody2D.position
			tile_pos = getSelectedHexagon(pos + camera_pos)
			var tile_index = _tilemap.get_cell(tile_pos.x, tile_pos.y)
			#var resource_index = d[str(tile_pos.x)][str(tile_pos.y)].ressource
			print(pos,"tile_pos",tile_pos)
			$CanvasLayer/TileView.popup()
			$CanvasLayer/TileView/Content/Body/TileInfo/TileImage.texture = _tilemap.tile_set.tile_get_texture(tile_index)
			$CanvasLayer/TileView/Content/Body/TileInfo/TilePosition.text = str(tile_pos.x) + ", " + str(tile_pos.y)
			#$CanvasLayer/TileView/Content/Body/Ressources/HBoxContainer/TextureRect.texture = _tilemap_img.tile_set.tile_get_texture(int(resource_index))
			#$CanvasLayer/TileView/Content/Body/Ressources/HBoxContainer/Label.text = ressource[int(resource_index)]
			#Debug Hex Cells
			#$Navigation2D/TileMap.set_cell(tile_pos.x,tile_pos.y,tile_index+1)

func on_received_new_map(data):
	if data.data:            
		d.map_data = data.data
		print("keyyyy ", data.key, " data", data.data[0][0], data.data)
		
func on_received_updated_map(data):
	if data.data:
		d.map_data = data.data
		print("keyyyy ", data.key, " data", data.data[0][0], data.data)

func _on_get_doc_received(doc):
	print(doc.doc_fields)
	self.d = doc.doc_fields
	load_map()

func on_error_received(code,status,message):
	new_map = true

func load_map():
	for x in range(0,size_units.x):
		for y in range(0,size_units.y):
			_tilemap.set_cell(x,y, int(d.map_data[x][y].tile_index))
			_tilemap_obj.set_cell(x,y, int(d.map_data[x][y].building))

func setup() -> void:
	var map_size_px = (size_units+Vector2(0.5,0)) * _tilemap.cell_size
	generate_simplex()

func generate() -> void:
	emit_signal("started")
	_rng.randomize()    
	for x in range(0,size_units.x):
		for y in range(0,size_units.y):
			var cell = get_random_tile()
			_tilemap.set_cell(x,y,cell)
	emit_signal("finished")
	
func generate_simplex():
	d = {"map_data": {}}
	print(d)
	emit_signal("started")
	_rng.randomize()
	var simplexNoise = OpenSimplexNoise.new()
	#configuring noise properties
	simplexNoise.seed = _rng.randi()
	simplexNoise.octaves = 10
	simplexNoise.period = 20.0
	simplexNoise.persistence = 1
	simplexNoise.lacunarity = 2
	var matrix=[]
	for x in range(0,size_units.x):
		matrix.append([])
		for y in range(0,size_units.y):
			var cell = get_random_tile_simplex(simplexNoise.get_noise_2d(x,y))
			matrix[x].append({
				"tile_index": cell,
				"ressource": _rng.randi_range(0,7),
				"owner": "none",
				"building": -1,
			})
			_tilemap.set_cell(x,y,cell)
	_tilemap_obj.clear()
	d = matrix
	print("test matrix", d.map_data)
	emit_signal("finished")

func set_tile_owner():
	#davor noch updaten sonst race condition bzw. in eigenes document packen
	d.map_data[tile_pos.x][tile_pos.y].owner = Local.userdata.local_id
	listener_map_data.put(d)
	#firestore_map_data.update("world", {"fields": d})
	Local.set_credit(-150)
	#cloud function für credits setzen/ builden
	firestore_users.update(Local.userdata.local_id, Local.profile)

func set_map_obj(cell):
	if d.map_data[tile_pos.x][tile_pos.y].owner == Local.userdata.local_id:
		_tilemap_obj.set_cell(tile_pos.x,tile_pos.y,cell)
		d.map_data[tile_pos.x][tile_pos.y].building = cell
		listener_map_data.put(d)
		#firestore_map_data.update("world", {"fields": d})
		#weiterer http node wird benötigt. sonst wird nur der erste request abgeschickt
		Local.set_credit(-100)
		#cloud function für credits setzen/ builden
		firestore_users.update(Local.userdata.local_id, Local.profile)
	else:
		print("You have to own the tile first")

func set_map():
	pass
	#match new_map:
		#true:
			#firebase_db_map_data.push(d)
			#firestore_map_data.add("world", {"fields": d})
		#false:
			#firebase_db_map_data.push(d)
			#firestore_map_data.update("world", {"fields": d})

func get_random_tile() -> int:
	return _rng.randi_range(0,9)
	
func get_random_tile_simplex(noise_value:float) -> int:
	if(noise_value<-0.6):
		#print("sand")
		return _rng.randi_range(0,7)
	elif(noise_value<-0.2):
		#print("clay")
		return _rng.randi_range(8,16)
	elif(noise_value<0.2):
		#print("sand")
		return _rng.randi_range(0,7)
	elif(noise_value<0.6):
		#print("grass")
		return _rng.randi_range(17,24)
	else:
		#print("sand")
		return _rng.randi_range(0,7)

func getSelectedHexagon(pos):
	var gridHeight = $Navigation2D/TileMap.cell_size.y
	var gridWidth = $Navigation2D/TileMap.cell_size.x
	var halfWidth = gridWidth/2
	var c = 140 - gridHeight
	var m = float(c)/halfWidth
	var y = pos.y
	var x = pos.x
	var row = _tilemap.world_to_map(pos).y#int(y / gridHeight)
	var column
	var rowIsOdd = abs(fmod(row,2)) == 1;
	
	column = _tilemap.world_to_map(pos).x
	
	var relY = y - (row * gridHeight)
	var relX
	
	if rowIsOdd:
		relX = (x - (column * gridWidth)) - halfWidth
	else:
		relX = x - (column * gridWidth)
	
	print(relY, " ", -m,  " ", m, " ", relX, " ", c, " ", (-m * relX) + c, " ", (m * relX) - c, " ", _tilemap.world_to_map(pos))
	if (relY < (-m * relX) + c):
		row = row - 1
		if !rowIsOdd:
			column = column - 1
			
	else: if (relY < (m * relX) - c):
		row = row - 1
		if rowIsOdd:
			column = column + 1
	return Vector2(column,row);

func getDictionary():
	return d
