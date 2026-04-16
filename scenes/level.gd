class_name MultiplayerLevel
extends Node3D

@export var player_scene: PackedScene
var player_list: Dictionary[int, Player] = {}

func _ready():
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int):
	spawn_player(id)
	
func _on_peer_disconnected(id: int):
	despawn_player(id)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func spawn_player(id: int):
	print("spawn player for %d" % id)
	var player: Player = player_scene.instantiate()
	player.name = "player_%d" % id
	player.player_id = id
	$Players.add_child(player)
	
	player_list[id] = player

func despawn_player(id: int):
	print("despanw player for %d" % id)
	if player_list.has(id):
		if is_instance_valid(player_list[id]):
			player_list[id].queue_free()
		player_list.erase(id)
