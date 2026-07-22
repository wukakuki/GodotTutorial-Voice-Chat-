class_name MultiplayerLevel
extends Node3D


var game_instance: GameInstance = null


func _init():
	game_instance = GameInstance.singleton


@export var player_scene: PackedScene
var player_list: Dictionary[int, Player] = {}


func _ready():
	if multiplayer.is_server():
		game_instance.on_player_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(player_session_id: String, id: int):
	spawn_player(player_session_id, id)


func _on_peer_disconnected(id: int):
	despawn_player(id)


func spawn_player(player_session_id: String, id: int):
	game_instance.notification.emit(game_instance.NotificationLevel.Verbose, "spawn player for %d" % id)
	var player: Player = player_scene.instantiate()
	player.name = "player_%d" % id
	player.player_id = id
	player.player_session_id = player_session_id
	$Players.add_child(player)
	
	player_list[id] = player


func despawn_player(id: int):
	game_instance.notification.emit(game_instance.NotificationLevel.Verbose, "despanw player for %d" % id)
	if player_list.has(id):
		if is_instance_valid(player_list[id]):
			game_instance.on_player_disconnected(player_list[id].player_session_id)
			player_list[id].queue_free()
		player_list.erase(id)


func _on_area_3d_body_entered(body: Node3D):
	if body is Player:
		body.enter_water()

func _on_area_3d_body_exited(body: Node3D):
	if body is Player:
		body.exit_water()
