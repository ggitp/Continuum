extends Node

var starting_area := 1
var current_level := 1
var area_path := "res://Scenes/Levels/"


var collectible_cells := 0
var area_container : Node2D
var player : PlayerController
var hud : HUD


func _ready():
	area_container = get_tree().get_first_node_in_group("area_container")
	player = get_tree().get_first_node_in_group("player")
	hud = get_tree().get_first_node_in_group("HUD")
	_load_level(starting_area)

func _next_level():
	current_level += 1
	_load_level(current_level)

func _load_level(level_to_load):
	#checking new scene path
	var full_path = area_path + "level_" + str(level_to_load) + ".tscn"
	#get_tree().call_deferred(
		#"change_scene_to_file",
		#full_path
	#)
	var scene = load(full_path) as PackedScene
	if !scene:
		return
	print("Area changed to : " + full_path)
	
	#removing previous scene
	for child in area_container.get_children():
		child.queue_free()
		await child.tree_exited
	
	#setting up the new scene
	var instance = scene.instantiate()
	area_container.add_child(instance)
	_reset_collectible_cells()
	hud._update_portal_close()
	var load_pos_values = get_tree().get_first_node_in_group("player_start_position") as Node2D
	player._teleport_to_location(load_pos_values.position)
	

func _collectible_cell_picked():
	collectible_cells += 1
	print("collectible picked" + str(collectible_cells))
	hud._update_gold_coin_count(collectible_cells)
	if collectible_cells == 4 :
		var portal = get_tree().get_first_node_in_group("area_exits") as AreaExit
		print(portal)
		portal._open()
		hud._update_portal_open()


func _reset_collectible_cells():
	collectible_cells = 0
	hud._update_gold_coin_count(collectible_cells)
