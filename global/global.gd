extends Node


### Globally available enums
enum PACKET_TYPES {LOBBY_UPDATE}
enum NETWORK_MODE {NONE, DIRECT, STEAM}


### Global variables
var current_node_size_multiplier: Vector2 = Vector2(1, 1)
var network_mode: int
const GAME_PRELOAD: Resource = preload("res://scene/game/game.tscn")


### Default functions
func _ready():
	_initialize_Steam()
	pass


func _process(_delta):
	Steam.run_callbacks()
	pass


### Steam integration functions
func _initialize_Steam() -> void:
	var INIT: Dictionary = Steam.steamInit()
	print("Init Status: " + str(INIT)) #Debug
	pass


### Networking functions
# Valid modes:
# 0: None (We are not connected to anything)
# 1: Direct connection
# 2: Steam P2P

func set_network_mode(new_network_mode: int) -> void:
	network_mode = new_network_mode
	pass


func get_network_mode() -> int:
	return network_mode
