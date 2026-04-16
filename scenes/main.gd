class_name GameMode
extends Node3D

const SERVER_PORT: int = 7777
const SERVER_PORT_MAX: int = 7777
const MAX_CLIENT: int = 20

@export var default_server_map: PackedScene
@export var server_ip_address: String
@export var server_port: int
@export var stun_server_port: int = 19302
@export var turn_server_credentials: String = "embeddedVoiceChat:embeddedVoiceChatUSER_2019"
@export var turn_server_port_range_begin = 49152
@export var turn_server_port_range_end = 60000

var server_level: MultiplayerLevel

func _ready():
	if OS.has_feature("dedicated_server"):
		if !start_server():
			get_tree().quit()
		initialize_server()
	else:
		if !start_client(server_ip_address, server_port):
			get_tree().quit()
			
		EmbeddedVoiceChatCustomGroup._ice_servers = [
			"stun:%s:%d" % [server_ip_address, stun_server_port],
			"turn:%s@%s:%d" % [turn_server_credentials, server_ip_address, stun_server_port] if not turn_server_credentials.is_empty() else "turn:%s:%d" % [server_ip_address, stun_server_port]
			]
		EmbeddedVoiceChatCustomGroup._port_range_begin = turn_server_port_range_begin
		EmbeddedVoiceChatCustomGroup._port_range_end = turn_server_port_range_end
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func start_server(port: int = SERVER_PORT) -> bool:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_CLIENT)
	if error:
		if error == ERR_ALREADY_IN_USE:
			print("peer is already in use")
			return false
		elif error == ERR_CANT_CREATE:
			if port > SERVER_PORT_MAX or port > 65535:
				print("port from %d to %d are already in use" % [SERVER_PORT, SERVER_PORT_MAX])
				return false
			print("failed to open port %d, trying %d" % [port, port + 1])
			return start_server(port + 1)
		print("faled to create server: %d" % error)
		return false
	
	print("server is listening on port %d" % port)
	multiplayer.multiplayer_peer = peer
	return true
	
func start_client(ip_address: String, port: int) -> bool:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(ip_address, port)
	if error:
		if error == ERR_ALREADY_IN_USE:
			print("peer is already in use")
			return false
		print("faled to create client: %d" % error)
		return false
	
	print("client connected to %s:%d" % [ip_address, port])
	multiplayer.multiplayer_peer = peer
	return true
		
		
func initialize_server():
	if default_server_map.can_instantiate():
		server_level = default_server_map.instantiate()
		$Level.add_child(server_level)
