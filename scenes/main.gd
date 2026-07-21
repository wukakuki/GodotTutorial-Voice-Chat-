class_name GameInstance
extends Node3D


enum NotificationLevel {
	Fatal,
	Error,
	Warning,
	Log,
	Verbose,
}
## triggered when there is a notification from code
@warning_ignore("unused_signal")
signal notification(level: NotificationLevel, notification_message: String)


const SERVER_PORT: int = 7777
const SERVER_PORT_MAX: int = 8777
const MAX_CLIENT: int = 20

var server_level: MultiplayerLevel

var process_parameter: AmazonGameLiftServerProcessParameter
const SETTING_LOG_PATH: String = "debug/file_logging/log_path"

@export var default_client_map: PackedScene
var client_level: UserLogin

## voice chat
@export var default_server_map: PackedScene
@export var server_port: int = 7777
@export var stun_server_port: int = 19302
@export var turn_server_credentials: String = "embeddedVoiceChat:embeddedVoiceChatUSER_2019"
@export var turn_server_port_range_begin = 49152
@export var turn_server_port_range_end = 60000

## cognito
@export var cognito_region: String
var cognito_identity_provider_clients: Dictionary[String, CognitoIdentityProviderClient] = {
	"us-east-1": null,
	"us-east-2": null,
	"us-west-1": null,
	"us-west-2": null,
	"af-south-1": null,
	"ap-east-1": null,
	"ap-south-2": null,
	"ap-southeast-3": null,
	"ap-southeast-5": null,
	"ap-southeast-4": null,
	"ap-south-1": null,
	"ap-southeast-6": null,
	"ap-northeast-3": null,
	"ap-northeast-2": null,
	"ap-southeast-1": null,
	"ap-southeast-2": null,
	"ap-east-2": null,
	"ap-southeast-7": null,
	"ap-northeast-1": null,
	"ca-central-1": null,
	"ca-west-1": null,
	"eu-central-1": null,
	"eu-west-1": null,
	"eu-west-2": null,
	"eu-south-1": null,
	"eu-west-3": null,
	"eu-south-2": null,
	"eu-north-1": null,
	"eu-central-2": null,
	"il-central-1": null,
	"mx-central-1": null,
	"me-south-1": null,
	"me-central-1": null,
	"sa-east-1": null,
}
var cognito_identity_clients: Dictionary[String, CognitoIdentityClient] = {
	"us-east-1": null,
	"us-east-2": null,
	"us-west-1": null,
	"us-west-2": null,
	"af-south-1": null,
	"ap-east-1": null,
	"ap-south-2": null,
	"ap-southeast-3": null,
	"ap-southeast-5": null,
	"ap-southeast-4": null,
	"ap-south-1": null,
	"ap-southeast-6": null,
	"ap-northeast-3": null,
	"ap-northeast-2": null,
	"ap-southeast-1": null,
	"ap-southeast-2": null,
	"ap-east-2": null,
	"ap-southeast-7": null,
	"ap-northeast-1": null,
	"ca-central-1": null,
	"ca-west-1": null,
	"eu-central-1": null,
	"eu-west-1": null,
	"eu-west-2": null,
	"eu-south-1": null,
	"eu-west-3": null,
	"eu-south-2": null,
	"eu-north-1": null,
	"eu-central-2": null,
	"il-central-1": null,
	"mx-central-1": null,
	"me-south-1": null,
	"me-central-1": null,
	"sa-east-1": null,
}
@export var cognito_client_id: String
@export var cognito_client_secret_key: String
@export var cognito_user_pool_id: String
@export var cognito_identity_pool_id: String
var auth_result: AWSSDKCognitoIdentityProvider_Model_AuthenticationResultType = null
var logins: Dictionary[String, String]
var username: String
var user_caches: Dictionary[String, UserCache]

## gamelift
@export var gamelift_region: String
var gamelift_clients: Dictionary[String, GameLiftClient] = {
	"us-east-1": null,
	"us-east-2": null,
	"us-west-1": null,
	"us-west-2": null,
	"af-south-1": null,
	"ap-east-1": null,
	"ap-south-2": null,
	"ap-southeast-3": null,
	"ap-southeast-5": null,
	"ap-southeast-4": null,
	"ap-south-1": null,
	"ap-southeast-6": null,
	"ap-northeast-3": null,
	"ap-northeast-2": null,
	"ap-southeast-1": null,
	"ap-southeast-2": null,
	"ap-east-2": null,
	"ap-southeast-7": null,
	"ap-northeast-1": null,
	"ca-central-1": null,
	"ca-west-1": null,
	"eu-central-1": null,
	"eu-west-1": null,
	"eu-west-2": null,
	"eu-south-1": null,
	"eu-west-3": null,
	"eu-south-2": null,
	"eu-north-1": null,
	"eu-central-2": null,
	"il-central-1": null,
	"mx-central-1": null,
	"me-south-1": null,
	"me-central-1": null,
	"sa-east-1": null,
}
@export var alias_id: String
@export var location: String

static var singleton: GameInstance = null


func _init():
	if singleton != null:
		notification.emit(NotificationLevel.Warning, "there is already another game instance initialized, overiding singleton.")
		
	singleton = self


func _notification(p_what: int):
	if p_what == NOTIFICATION_PREDELETE or p_what == NOTIFICATION_WM_CLOSE_REQUEST or p_what == NOTIFICATION_EXIT_TREE:
		if OS.has_feature("dedicated_server"):
			shut_down_server()


func _on_notification(_level, notification_message):
	print(notification_message)


func _ready():
	if OS.has_feature("dedicated_server"):
		if !start_server():
			get_tree().quit()
		initialize_server()
	else:
		#if !start_client(server_ip_address, server_port):
			#get_tree().quit()
		
		initialize_client()


func start_server(port: int = SERVER_PORT) -> bool:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_CLIENT)
	if error:
		if error == ERR_ALREADY_IN_USE:
			notification.emit(NotificationLevel.Warning, "peer is already in use")
			return false
		elif error == ERR_CANT_CREATE:
			if port >= SERVER_PORT_MAX or port > 65535:
				notification.emit(NotificationLevel.Error, "port from %d to %d are already in use" % [SERVER_PORT, SERVER_PORT_MAX])
				return false
			notification.emit(NotificationLevel.Warning, "failed to open port %d, trying %d" % [port, port + 1])
			return start_server(port + 1)
		notification.emit(NotificationLevel.Warning, "faled to create server: %d" % error)
		return false
	
	notification.emit(NotificationLevel.Log, "server is listening on port %d" % port)
	server_port = port
	multiplayer.multiplayer_peer = peer
	return true


func start_client(ip_address: String, port: int) -> bool:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(ip_address, port)
	if error:
		if error == ERR_ALREADY_IN_USE:
			notification.emit(NotificationLevel.Error, "peer is already in use")
			return false
		notification.emit(NotificationLevel.Error, "faled to create client: %d" % error)
		return false
	
	notification.emit(NotificationLevel.Log, "client connected to %s:%d" % [ip_address, port])
	multiplayer.multiplayer_peer = peer
		
	EmbeddedVoiceChatCustomGroup._ice_servers = [
		"stun:%s:%d" % [
			ip_address, 
			stun_server_port
			],
		"turn:%s@%s:%d" % [
			turn_server_credentials, 
			ip_address, 
			stun_server_port
			] if not turn_server_credentials.is_empty() 
		else "turn:%s:%d" % [
			ip_address, 
			stun_server_port
			]
		]
	EmbeddedVoiceChatCustomGroup._port_range_begin = turn_server_port_range_begin
	EmbeddedVoiceChatCustomGroup._port_range_end = turn_server_port_range_end
		
	return true


## The authentication token generated by Amazon GameLift Servers that authenticates your server to Amazon GameLift Servers.
@export var game_server_auth_token: String
## The region of the fleet that the compute is registered to. 
@export var game_server_region: String
## The unique identifier of the fleet that the compute is registered to. 
@export var game_server_fleet_id: String
## The HostID is the ComputeName used when you registered your compute.
@export var game_server_host_id: String
## The GameLiftServerSdkEndpoint Amazon GameLift Servers returns when you RegisterCompute   for a Amazon GameLift Servers Anywhere compute resource.
@export var game_server_web_socket_url: String


func initialize_server():
	var sdk_version_result: AmazonGameLiftServer_GetSdkVersionResult = AmazonGameLiftServer_GetSdkVersionResult.new()
	sdk_version_result.sdk_version = ""
	var get_sdk_version_outcome: AmazonGameLiftServer_Outcome = AmazonGameLiftServer_Outcome.new();
	get_sdk_version_outcome.success = false
	AmazonGameLiftServer_GameLiftServerAPI.get_sdk_version(sdk_version_result, get_sdk_version_outcome)
	
	if not get_sdk_version_outcome.success:
		notification.emit(NotificationLevel.Error, "get sdk version failed: %s" % get_sdk_version_outcome.error_message)
	else:
		notification.emit(NotificationLevel.Log, "sdk version: %s" % sdk_version_result.sdk_version)
		
	var server_parameters: AmazonGameLiftServer_ServerParameters = AmazonGameLiftServer_ServerParameters.new()
	server_parameters.auth_token = game_server_auth_token
	server_parameters.aws_region = game_server_region
	server_parameters.fleet_id = game_server_fleet_id
	server_parameters.host_id = game_server_host_id
	server_parameters.process_id = str(OS.get_process_id())
	server_parameters.web_socket_url = game_server_web_socket_url
	
	var init_sdk_outcome: AmazonGameLiftServer_Outcome = AmazonGameLiftServer_Outcome.new();
	AmazonGameLiftServer_GameLiftServerAPI.init_sdk(server_parameters, init_sdk_outcome)
	
	if not init_sdk_outcome.success:
		notification.emit(NotificationLevel.Error, "init sdk failed: %s" % init_sdk_outcome.error_message)
		return
	
	if default_server_map.can_instantiate():
		server_level = default_server_map.instantiate()
		$Level.add_child(server_level)
	
	process_parameter = AmazonGameLiftServerProcessParameter.new()
	process_parameter.port = server_port
	if AmazonGameLiftServerCustomLogger.log_path:
		process_parameter.log_paths = [
			ProjectSettings.globalize_path(AmazonGameLiftServerCustomLogger.log_path)
		]
	else:
		process_parameter.log_paths = []
	process_parameter.on_process_parameter_start_game_session.connect(on_start_game_session)
	process_parameter.on_process_parameter_update_game_session.connect(on_update_game_session)
	process_parameter.on_process_parameter_process_terminate.connect(on_process_terminate)
	
	var process_ready_outcome: AmazonGameLiftServer_Outcome = AmazonGameLiftServer_Outcome.new();
	AmazonGameLiftServer_GameLiftServerAPI.process_ready(process_parameter, process_ready_outcome)
	
	if not process_ready_outcome.success:
		notification.emit(NotificationLevel.Error, "process ready failed: %s" % process_ready_outcome.error_message)
		return


func on_start_game_session(_game_session: AmazonGameLiftServer_GameSession):
	var activate_game_session_outcome: AmazonGameLiftServer_Outcome = AmazonGameLiftServer_Outcome.new()
	AmazonGameLiftServer_GameLiftServerAPI.activate_game_session(activate_game_session_outcome)
	if not activate_game_session_outcome.success:
		notification.emit(NotificationLevel.Error, "activate game session failed: %s" % activate_game_session_outcome.error_message)


func on_update_game_session(_update_game_session: AmazonGameLiftServer_UpdateGameSession):
	pass


func on_process_terminate():
	shut_down_server()
	
	get_tree().quit()


func shut_down_server():
	var process_ending_outcome: AmazonGameLiftServer_Outcome = AmazonGameLiftServer_Outcome.new();
	AmazonGameLiftServer_GameLiftServerAPI.process_ending(process_ending_outcome)
	
	if not process_ending_outcome.success:
		notification.emit(NotificationLevel.Error, "process ending failed: %s" % process_ending_outcome.error_message)
		return
	
	var destroy_outcome: AmazonGameLiftServer_Outcome = AmazonGameLiftServer_Outcome.new();
	AmazonGameLiftServer_GameLiftServerAPI.destroy(destroy_outcome)
	
	if not destroy_outcome.success:
		notification.emit(NotificationLevel.Error, "destroy failed: %s" % destroy_outcome.error_message)
		return


func initialize_client():
	if default_client_map.can_instantiate():
		client_level = default_client_map.instantiate()
		$Level.add_child(client_level)


func enter_game() -> bool:
	if (
		gamelift_region.is_empty() 
		or not gamelift_clients.has(gamelift_region)
	):
		notification.emit(NotificationLevel.Error, "Can't find gamelift client object for region: %s" % gamelift_region)
		return false
		
	var gamelift_client: GameLiftClient = gamelift_clients[gamelift_region]
	
	if (gamelift_client == null):
		notification.emit(NotificationLevel.Error, "Gamelift client object for region: %s is not initiated" % gamelift_region)
		return false
	
	var game_session_id: String = await get_game_session()
	
	if game_session_id.is_empty():
		return false
		
	var request: AWSSDKGameLift_Model_CreatePlayerSessionRequest = AWSSDKGameLift_Model_CreatePlayerSessionRequest.new()
	request.game_session_id = game_session_id
	request.player_id = username
	var response_receive_handler: AWSSDKGameLift_Model_CreatePlayerSessionResponseReceivedHandler = gamelift_client.create_player_session(request)
		
	if response_receive_handler == null:
		notification.emit(NotificationLevel.Error, "gamelift client is not init properly.")
		return false
	
	var outcome: AWSSDKGameLift_Model_CreatePlayerSessionOutcome = await response_receive_handler.complete
	
	if !outcome.success or outcome.result == null:
		notification.emit(NotificationLevel.Error, outcome.error_message)
		return false
	
	client_level.queue_free()
	if !start_client(outcome.result.player_session.ip_address, outcome.result.player_session.port):
		get_tree().quit()
		return false
	
	return true


func get_game_session() -> String:
	if (
		gamelift_region.is_empty() 
		or not gamelift_clients.has(gamelift_region)
	):
		notification.emit(NotificationLevel.Error, "Can't find gamelift client object for region: %s" % gamelift_region)
		return String()
		
	var gamelift_client: GameLiftClient = gamelift_clients[gamelift_region]
	
	if (gamelift_client == null):
		notification.emit(NotificationLevel.Error, "Gamelift client object for region: %s is not initiated" % gamelift_region)
		return String()
		
	if true:
		var request: AWSSDKGameLift_Model_SearchGameSessionsRequest = AWSSDKGameLift_Model_SearchGameSessionsRequest.new()
		request.alias_id = alias_id
		request.location = location
		request.filter_expression = "hasAvailablePlayerSessions=true"
		var response_receive_handler: AWSSDKGameLift_Model_SearchGameSessionsResponseReceivedHandler = gamelift_client.search_game_sessions(request)
		
		if response_receive_handler == null:
			notification.emit(NotificationLevel.Error, "gamelift client is not init properly.")
			return String()
	
		var outcome: AWSSDKGameLift_Model_SearchGameSessionsOutcome = await response_receive_handler.complete
	
		if !outcome.success or outcome.result == null:
			notification.emit(NotificationLevel.Error, outcome.error_message)
			return String()
			
		if outcome.result.game_sessions.size() > 0:
			return outcome.result.game_sessions[0].game_session_id
			
		print("search game session returns: %d" % outcome.result.game_sessions.size())
	
	var game_session_id: String
	if true:
		var request: AWSSDKGameLift_Model_CreateGameSessionRequest = AWSSDKGameLift_Model_CreateGameSessionRequest.new()
		request.alias_id = alias_id
		request.location = location
		request.maximum_player_session_count = MAX_CLIENT
		var response_receive_handler: AWSSDKGameLift_Model_CreateGameSessionResponseReceivedHandler = gamelift_client.create_game_session(request)
		
		if response_receive_handler == null:
			notification.emit(NotificationLevel.Error, "gamelift client is not init properly.")
			return String()
	
		var outcome: AWSSDKGameLift_Model_CreateGameSessionOutcome = await response_receive_handler.complete
	
		if !outcome.success or outcome.result == null:
			notification.emit(NotificationLevel.Error, "create game session error: %d %s" % [outcome.error, outcome.error_message])
			return String()
			
		game_session_id = outcome.result.game_session.game_session_id
		
	return game_session_id


func cache_logged_in_user(logged_in_user: AWSSDKCognitoIdentityProvider_Model_GetUserResult):
	if logged_in_user == null:
		return
		
	username = logged_in_user.username
	user_caches[logged_in_user.username] = UserCache.new()


func refresh_auth() -> bool:
	if (
		cognito_region.is_empty() 
		or not cognito_identity_provider_clients.has(cognito_region)
	):
		notification.emit(NotificationLevel.Error, "Can't find cognito idp client object for region: %s" % cognito_region)
		return false
		
	var cognito_identity_provider_client: CognitoIdentityProviderClient = cognito_identity_provider_clients[cognito_region]
	
	if (cognito_identity_provider_client == null):
		notification.emit(NotificationLevel.Error, "Cognito idp client object for region: %s is not initiated" % cognito_region)
		return false
	
	var request: AWSSDKCognitoIdentityProvider_Model_InitiateAuthRequest = AWSSDKCognitoIdentityProvider_Model_InitiateAuthRequest.new()
	request.auth_flow = AWSSDKCognitoIdentityProvider_Model_AuthFlowType.REFRESH_TOKEN_AUTH
	request.auth_parameters = {
		"REFRESH_TOKEN": auth_result.refresh_token,
		"SECRET_HASH": AWSSDKCognitoIdentityProvider_SecretHashHelper.compute_secret_hash(
			username,
			cognito_client_id, 
			cognito_client_secret_key,
			)
	}
	request.client_id = cognito_client_id
	var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_InitiateAuthResponseReceivedHandler = cognito_identity_provider_client.initiate_auth(request)
	
	if response_receive_handler == null:
		notification.emit(NotificationLevel.Error, "cognito identity provider client is not init properly.")
		return false
	
	var outcome: AWSSDKCognitoIdentityProvider_Model_InitiateAuthOutcome = await response_receive_handler.complete
	
	if !outcome.success or outcome.result == null:
		notification.emit(NotificationLevel.Error, outcome.error_message)
		return false
		
	if outcome.result.challenge_name != AWSSDKCognitoIdentityProvider_Model_ChallengeNameType.NOT_SET:
		notification.emit(NotificationLevel.Error, "refresh auth challenge is set to: %d" % outcome.result.challenge_name)
		return false
		
		
	auth_result.access_token = outcome.result.authentication_result.access_token
	auth_result.id_token = outcome.result.authentication_result.id_token
	auth_result.expires_in = outcome.result.authentication_result.expires_in
	
	return refresh_clients(await get_credentials_for_clients())


func get_credentials_for_clients() -> AWSSDKCore_Auth_AWSCredentials:
	if (
		cognito_region.is_empty() 
		or not cognito_identity_clients.has(cognito_region)
	):
		notification.emit(NotificationLevel.Error, "Can't find cognito identity client object for region: %s" % cognito_region)
		return null
		
	var cognito_identity_client: CognitoIdentityClient = cognito_identity_clients[cognito_region]
	
	if (cognito_identity_client == null):
		notification.emit(NotificationLevel.Error, "Cognito identity client object for region: %s is not initiated" % cognito_region)
		return null
	
	logins = {
		"cognito-idp.{cognito_region}.amazonaws.com/{cognito_user_pool_id}".format({
			"cognito_region": cognito_region,
			"cognito_user_pool_id": cognito_user_pool_id,
		}): auth_result.id_token,
	}
	
	var identity_id: String
#	dummy scope
	if true:
		var request: AWSSDKCognitoIdentity_Model_GetIdRequest = AWSSDKCognitoIdentity_Model_GetIdRequest.new()
		request.identity_pool_id = cognito_identity_pool_id
		request.logins = logins
		var response_receive_handler: AWSSDKCognitoIdentity_Model_GetIdResponseReceivedHandler = cognito_identity_client.get_id(request)
		
		if response_receive_handler == null:
			notification.emit(NotificationLevel.Error, "cognito identity client is not init properly.")
			return null
		
		var outcome: AWSSDKCognitoIdentity_Model_GetIdOutcome = await response_receive_handler.complete
		
		if !outcome.success or outcome.result == null:
			notification.emit(NotificationLevel.Error, outcome.error_message)
			return null
			
		identity_id = outcome.result.identity_id
	
	var credetials: AWSSDKCore_Auth_AWSCredentials = null
#	dummy scope
	if true:
		var request: AWSSDKCognitoIdentity_Model_GetCredentialsForIdentityRequest = AWSSDKCognitoIdentity_Model_GetCredentialsForIdentityRequest.new()
		request.identity_id = identity_id
		request.logins = logins
		var response_receive_handler: AWSSDKCognitoIdentity_Model_GetCredentialsForIdentityResponseReceivedHandler = cognito_identity_client.get_credentials_for_identity(request)
		
		if response_receive_handler == null:
			notification.emit(NotificationLevel.Error, "cognito identity client is not init properly.")
			return null
		
		var outcome: AWSSDKCognitoIdentity_Model_GetCredentialsForIdentityOutcome = await response_receive_handler.complete
		
		if !outcome.success or outcome.result == null:
			notification.emit(NotificationLevel.Error, "get credentials for identity error: %d %s" % [outcome.error, outcome.error_message])
			return null
			
		credetials = AWSSDKCore_Auth_AWSCredentials.new()
		credetials.access_key_id = outcome.result.credentials.access_key_id
		credetials.secret_key = outcome.result.credentials.secret_key
		credetials.session_token  = outcome.result.credentials.session_token
		credetials.expiration = outcome.result.credentials.expiration
	
	return credetials


func refresh_clients(credentials: AWSSDKCore_Auth_AWSCredentials) -> bool:
	if (credentials == null):
		notification.emit(NotificationLevel.Error, "credentials are missing.")
		return false
	
	for region in gamelift_clients:
		var client_configuration: AWSSDKCore_Client_ClientConfiguration = AWSSDKCore_Client_ClientConfiguration.new()
		client_configuration.region = region
		client_configuration.scheme = AWSSDKCore_Http_Schema.HTTPS
		client_configuration.disable_imds = true
		client_configuration.disable_imds_v1 = true
		if OS.has_feature("macos"):
			client_configuration.ca_file = "/etc/ssl/cert.pem"
		elif OS.has_feature("android"):
			client_configuration.ca_path = "/system/etc/security/cacerts"
			
		gamelift_clients[region] = GameLiftClient.new(credentials, client_configuration)
		
	return true
