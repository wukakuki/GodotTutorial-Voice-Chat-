class_name UserLogin
extends Control


var game_instance: GameInstance = null


var srp_helper: SRPHelper


var confirm_code_regex = RegEx.create_from_string("^\\d{6}$")


func _init():
	game_instance = GameInstance.singleton
	
	if game_instance.cognito_region.is_empty():
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito region is empty. ")
		return
		
	for region in game_instance.cognito_identity_provider_clients:
		var client_configuration: AWSSDKCore_Client_ClientConfiguration = AWSSDKCore_Client_ClientConfiguration.new()
		client_configuration.region = region
		client_configuration.scheme = AWSSDKCore_Http_Schema.HTTPS
		client_configuration.disable_imds = true
		client_configuration.disable_imds_v1 = true
		if OS.has_feature("macos"):
			client_configuration.ca_file = "/etc/ssl/cert.pem"
		elif OS.has_feature("android"):
			client_configuration.ca_path = "/system/etc/security/cacerts"
			
		game_instance.cognito_identity_provider_clients[region] = CognitoIdentityProviderClient.new(null, client_configuration)
	
#	just in case if we missed the cognito_region
	if not game_instance.cognito_identity_provider_clients.has(game_instance.cognito_region):
		var client_configuration: AWSSDKCore_Client_ClientConfiguration = AWSSDKCore_Client_ClientConfiguration.new()
		client_configuration.region = game_instance.cognito_region
		client_configuration.scheme = AWSSDKCore_Http_Schema.HTTPS
		client_configuration.disable_imds = true
		client_configuration.disable_imds_v1 = true
		if OS.has_feature("macos"):
			client_configuration.ca_file = "/etc/ssl/cert.pem"
		elif OS.has_feature("android"):
			client_configuration.ca_file = "/system/etc/security/cacerts"
			
		game_instance.cognito_identity_provider_clients[game_instance.cognito_region] = CognitoIdentityProviderClient.new(null, client_configuration)
		
	srp_helper = SRPHelper.new()
		
	for region in game_instance.cognito_identity_clients:
		var client_configuration: AWSSDKCore_Client_ClientConfiguration = AWSSDKCore_Client_ClientConfiguration.new()
		client_configuration.region = region
		client_configuration.scheme = AWSSDKCore_Http_Schema.HTTPS
		client_configuration.disable_imds = true
		client_configuration.disable_imds_v1 = true
		if OS.has_feature("macos"):
			client_configuration.ca_file = "/etc/ssl/cert.pem"
		elif OS.has_feature("android"):
			client_configuration.ca_file = "/system/etc/security/cacerts"
			
		game_instance.cognito_identity_clients[region] = CognitoIdentityClient.new(null, client_configuration)
		
#	just in case if we missed the cognito_region
	if not game_instance.cognito_identity_clients.has(game_instance.cognito_region):
		var client_configuration: AWSSDKCore_Client_ClientConfiguration = AWSSDKCore_Client_ClientConfiguration.new()
		client_configuration.region = game_instance.cognito_region
		client_configuration.scheme = AWSSDKCore_Http_Schema.HTTPS
		client_configuration.disable_imds = true
		client_configuration.disable_imds_v1 = true
		if OS.has_feature("macos"):
			client_configuration.ca_file = "/etc/ssl/cert.pem"
		elif OS.has_feature("android"):
			client_configuration.ca_file = "/system/etc/security/cacerts"
			
		game_instance.cognito_identity_clients[game_instance.cognito_region] = CognitoIdentityClient.new(null, client_configuration)


func _login(username: String, password: String) -> AWSSDKCognitoIdentityProvider_Model_AuthenticationResultType:
	if (
		game_instance.cognito_region.is_empty() 
		or not game_instance.cognito_identity_provider_clients.has(game_instance.cognito_region)
	):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Can't find cognito idp client object for region: %s" % game_instance.cognito_region)
		return null
		
	var cognito_identity_provider_client: CognitoIdentityProviderClient = game_instance.cognito_identity_provider_clients[game_instance.cognito_region]
	
	if (cognito_identity_provider_client == null):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Cognito idp client object for region: %s is not initiated" % game_instance.cognito_region)
		return null
	
	var srp_a: String = srp_helper.compute_srp_a()
	
	var request: AWSSDKCognitoIdentityProvider_Model_InitiateAuthRequest = AWSSDKCognitoIdentityProvider_Model_InitiateAuthRequest.new()
	request.auth_flow = AWSSDKCognitoIdentityProvider_Model_AuthFlowType.USER_SRP_AUTH
	request.auth_parameters = {
		"USERNAME": username,
		"SRP_A": srp_a,
		"SECRET_HASH": AWSSDKCognitoIdentityProvider_SecretHashHelper.compute_secret_hash(
			username,
			game_instance.cognito_client_id, 
			game_instance.cognito_client_secret_key,
			)
	}
	request.client_id = game_instance.cognito_client_id
	var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_InitiateAuthResponseReceivedHandler = cognito_identity_provider_client.initiate_auth(request)
	
	if response_receive_handler == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito identity provider client is not init properly.")
		return null
	
	var outcome: AWSSDKCognitoIdentityProvider_Model_InitiateAuthOutcome = await response_receive_handler.complete
	
	if !outcome.success or outcome.result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, outcome.error_message)
		return null
		
	if outcome.result.challenge_name == AWSSDKCognitoIdentityProvider_Model_ChallengeNameType.NOT_SET:
		return outcome.result.authentication_result
		
	return await _response_auth_challenge(
		username,
		password,
		outcome.result.challenge_name, 
		outcome.result.challenge_parameters, 
		outcome.result.session
		)


func _response_auth_challenge(
	username: String, 
	password: String,
	challenge_name: AWSSDKCognitoIdentityProvider_Model_ChallengeNameType.AWSSDKCognitoIdentityProvider_Model_ChallengeNameType_Enum,
	challenge_parameters: Dictionary[String, String],
	session: String) -> AWSSDKCognitoIdentityProvider_Model_AuthenticationResultType:
	if (
		game_instance.cognito_region.is_empty() 
		or not game_instance.cognito_identity_provider_clients.has(game_instance.cognito_region)
	):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Can't find cognito idp client object for region: %s" % game_instance.cognito_region)
		return null
	
	var cognito_identity_provider_client: CognitoIdentityProviderClient = game_instance.cognito_identity_provider_clients[game_instance.cognito_region]	
	
	if (cognito_identity_provider_client == null):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Cognito idp client object for region: %s is not initiated" % game_instance.cognito_region)
		return null
	
	match challenge_name:
		AWSSDKCognitoIdentityProvider_Model_ChallengeNameType.SOFTWARE_TOKEN_MFA:
			add_user_signal("confirm_mfa", [
				{ "name": "code", "type": TYPE_STRING }
			])
			
			tab_container.current_tab = 5
				
			var code: String = await Signal(self, "confirm_mfa")
			
			remove_user_signal("confirm_mfa")
				
			if code.is_empty():
				return null
				
			var request: AWSSDKCognitoIdentityProvider_Model_RespondToAuthChallengeRequest = AWSSDKCognitoIdentityProvider_Model_RespondToAuthChallengeRequest.new()
			request.client_id = game_instance.cognito_client_id
			request.challenge_name = AWSSDKCognitoIdentityProvider_Model_ChallengeNameType.SOFTWARE_TOKEN_MFA
			request.session = session
			request.challenge_responses = {
				"SOFTWARE_TOKEN_MFA_CODE": code,
				"USERNAME": username,
				"SECRET_HASH": AWSSDKCognitoIdentityProvider_SecretHashHelper.compute_secret_hash(
					username,
					game_instance.cognito_client_id, 
					game_instance.cognito_client_secret_key,
					)
			}
			var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_RespondToAuthChallengeResponseReceivedHandler = cognito_identity_provider_client.respond_to_auth_challenge(request)
			
			if response_receive_handler == null:
				game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito identity provider client is not init properly.")
				return null
	
			var outcome: AWSSDKCognitoIdentityProvider_Model_RespondToAuthChallengeOutcome = await response_receive_handler.complete
	
			if !outcome.success or outcome.result == null:
				game_instance.notification.emit(game_instance.NotificationLevel.Error, "respond to auth challenge error: %d %s" % [outcome.error, outcome.error_message])
				return null
		
			if outcome.result.challenge_name == AWSSDKCognitoIdentityProvider_Model_ChallengeNameType.NOT_SET:
				return outcome.result.authentication_result
			
			return await _response_auth_challenge(
				username,
				password,
				outcome.result.challenge_name, 
				outcome.result.challenge_parameters, 
				outcome.result.session
				)
		AWSSDKCognitoIdentityProvider_Model_ChallengeNameType.PASSWORD_VERIFIER:
			if challenge_parameters.has("USER_ID_FOR_SRP"):
				username = challenge_parameters["USER_ID_FOR_SRP"]
				
			if not challenge_parameters.has_all(["SRP_B", "SALT", "SECRET_BLOCK"]):
				game_instance.notification.emit(game_instance.NotificationLevel.Error, "%s is missing in challenge parameters: %s" % [", ".join(["SRP_B", "SALT", "SECRET_BLOCK"]), ", ".join(challenge_parameters.keys())])
				return null
				
			var timestamp: String = AWSSDKCognitoIdentityProvider_SrpHelper.format_timestamp(Time.get_unix_time_from_system())
			
			var password_claim_signature: String = srp_helper.compute_password_claim_signature(
				challenge_parameters["SECRET_BLOCK"],
				challenge_parameters["SALT"],
				challenge_parameters["SRP_B"],
				timestamp,
				game_instance.cognito_user_pool_id.get_slice("_", 1),
				username,
				password
			)
			
			var request: AWSSDKCognitoIdentityProvider_Model_RespondToAuthChallengeRequest = AWSSDKCognitoIdentityProvider_Model_RespondToAuthChallengeRequest.new()
			request.client_id = game_instance.cognito_client_id
			request.challenge_name = AWSSDKCognitoIdentityProvider_Model_ChallengeNameType.PASSWORD_VERIFIER
			request.session = session
			request.challenge_responses = {
				"PASSWORD_CLAIM_SIGNATURE": password_claim_signature,
				"PASSWORD_CLAIM_SECRET_BLOCK": challenge_parameters["SECRET_BLOCK"],
				"TIMESTAMP": timestamp,
				"USERNAME": username,
				"SECRET_HASH": AWSSDKCognitoIdentityProvider_SecretHashHelper.compute_secret_hash(
					username,
					game_instance.cognito_client_id, 
					game_instance.cognito_client_secret_key,
					)
			}
			var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_RespondToAuthChallengeResponseReceivedHandler = cognito_identity_provider_client.respond_to_auth_challenge(request)
			
			if response_receive_handler == null:
				game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito identity provider client is not init properly.")
				return null
	
			var outcome: AWSSDKCognitoIdentityProvider_Model_RespondToAuthChallengeOutcome = await response_receive_handler.complete
	
			if !outcome.success or outcome.result == null:
				game_instance.notification.emit(game_instance.NotificationLevel.Error, outcome.error_message)
				return null
		
			if outcome.result.challenge_name == AWSSDKCognitoIdentityProvider_Model_ChallengeNameType.NOT_SET:
				return outcome.result.authentication_result
			
			return await _response_auth_challenge(
				username,
				password,
				outcome.result.challenge_name, 
				outcome.result.challenge_parameters, 
				outcome.result.session
				)
		_:
			game_instance.notification.emit(GameInstance.NotificationLevel.Error, "unknown challenge: %d" % challenge_name)
			return null


func _sign_up(username: String, password: String, email: String) -> AWSSDKCognitoIdentityProvider_Model_AuthenticationResultType:
	if (
		game_instance.cognito_region.is_empty() 
		or not game_instance.cognito_identity_provider_clients.has(game_instance.cognito_region)
	):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Can't find cognito idp client object for region: %s" % game_instance.cognito_region)
		return null
		
	var cognito_identity_provider_client: CognitoIdentityProviderClient = game_instance.cognito_identity_provider_clients[game_instance.cognito_region]	
	
	if (cognito_identity_provider_client == null):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Cognito idp client object for region: %s is not initiated" % game_instance.cognito_region)
		return null
	
	var request: AWSSDKCognitoIdentityProvider_Model_SignUpRequest = AWSSDKCognitoIdentityProvider_Model_SignUpRequest.new()
	request.client_id = game_instance.cognito_client_id
	request.secret_hash = AWSSDKCognitoIdentityProvider_SecretHashHelper.compute_secret_hash(
		username,
		game_instance.cognito_client_id, 
		game_instance.cognito_client_secret_key,
		)
	request.username = username
	request.password = password
	var email_attribute: AWSSDKCognitoIdentityProvider_Model_AttributeType = AWSSDKCognitoIdentityProvider_Model_AttributeType.new()
	email_attribute.name = "email"
	email_attribute.value = email
	request.user_attributes = [email_attribute]
	
	var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_SignUpResponseReceivedHandler = cognito_identity_provider_client.sign_up(request)
	
	if response_receive_handler == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito identity provider client is not init properly.")
		return null
	
	var outcome: AWSSDKCognitoIdentityProvider_Model_SignUpOutcome = await response_receive_handler.complete
	
	if !outcome.success or outcome.result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, outcome.error_message)
		return null
	
	add_user_signal("confirm_sign_up", [
		{ "name": "code", "type": TYPE_STRING }
	])
	
	tab_container.current_tab = 2
	
	var confirmed: bool = false
	
	while !confirmed:
		var code: String = await Signal(self, "confirm_sign_up")
		
		if code.is_empty():
			remove_user_signal("confirm_sign_up")
			return null
	
		confirmed = await _confirm_sign_up(username, code)
	
	remove_user_signal("confirm_sign_up")
	
	if not confirmed:
		return null
	
	tab_container.current_tab = 0
	
	return await _login(username, password)


func _sign_up_resend(username: String) -> bool:
	if (
		game_instance.cognito_region.is_empty() 
		or not game_instance.cognito_identity_provider_clients.has(game_instance.cognito_region)
	):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Can't find cognito idp client object for region: %s" % game_instance.cognito_region)
		return false
		
	var cognito_identity_provider_client: CognitoIdentityProviderClient = game_instance.cognito_identity_provider_clients[game_instance.cognito_region]	
	
	if (cognito_identity_provider_client == null):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Cognito idp client object for region: %s is not initiated" % game_instance.cognito_region)
		return false
	
	var request: AWSSDKCognitoIdentityProvider_Model_ResendConfirmationCodeRequest = AWSSDKCognitoIdentityProvider_Model_ResendConfirmationCodeRequest.new()
	request.client_id = game_instance.cognito_client_id
	request.secret_hash = AWSSDKCognitoIdentityProvider_SecretHashHelper.compute_secret_hash(
		username,
		game_instance.cognito_client_id, 
		game_instance.cognito_client_secret_key,
		)
	request.username = username
	var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_ResendConfirmationCodeResponseReceivedHandler = cognito_identity_provider_client.resend_confirmation_code(request)
	
	if response_receive_handler == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito identity provider client is not init properly.")
		return false
	
	var outcome: AWSSDKCognitoIdentityProvider_Model_ResendConfirmationCodeOutcome = await response_receive_handler.complete
	
	if !outcome.success or outcome.result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, outcome.error_message)
		return false
		
	return true


func _confirm_sign_up(username: String, code: String) -> bool:
	if (
		game_instance.cognito_region.is_empty() 
		or not game_instance.cognito_identity_provider_clients.has(game_instance.cognito_region)
	):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Can't find cognito idp client object for region: %s" % game_instance.cognito_region)
		return false
		
	var cognito_identity_provider_client: CognitoIdentityProviderClient = game_instance.cognito_identity_provider_clients[game_instance.cognito_region]	
	
	if (cognito_identity_provider_client == null):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Cognito idp client object for region: %s is not initiated" % game_instance.cognito_region)
		return false
	
	var request: AWSSDKCognitoIdentityProvider_Model_ConfirmSignUpRequest = AWSSDKCognitoIdentityProvider_Model_ConfirmSignUpRequest.new()
	request.client_id = game_instance.cognito_client_id
	request.secret_hash = AWSSDKCognitoIdentityProvider_SecretHashHelper.compute_secret_hash(
		username,
		game_instance.cognito_client_id, 
		game_instance.cognito_client_secret_key,
		)
	request.username = username
	request.confirmation_code = code
	var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_ConfirmSignUpResponseReceivedHandler = cognito_identity_provider_client.confirm_sign_up(request)
	
	if response_receive_handler == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito identity provider client is not init properly.")
		return false
	
	var outcome: AWSSDKCognitoIdentityProvider_Model_ConfirmSignUpOutcome = await response_receive_handler.complete
	
	if !outcome.success or outcome.result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, outcome.error_message)
		return false
		
	return true


func _forgot_password(username: String) -> AWSSDKCognitoIdentityProvider_Model_AuthenticationResultType:
	if (
		game_instance.cognito_region.is_empty() 
		or not game_instance.cognito_identity_provider_clients.has(game_instance.cognito_region)
	):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Can't find cognito idp client object for region: %s" % game_instance.cognito_region)
		return null
		
	var cognito_identity_provider_client: CognitoIdentityProviderClient = game_instance.cognito_identity_provider_clients[game_instance.cognito_region]	
	
	if (cognito_identity_provider_client == null):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Cognito idp client object for region: %s is not initiated" % game_instance.cognito_region)
		return null
	
	var request: AWSSDKCognitoIdentityProvider_Model_ForgotPasswordRequest = AWSSDKCognitoIdentityProvider_Model_ForgotPasswordRequest.new()
	request.client_id = game_instance.cognito_client_id
	request.secret_hash = AWSSDKCognitoIdentityProvider_SecretHashHelper.compute_secret_hash(
		username,
		game_instance.cognito_client_id, 
		game_instance.cognito_client_secret_key,
		)
	request.username = username
	
	var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_ForgotPasswordResponseReceivedHandler = cognito_identity_provider_client.forgot_password(request)
	
	if response_receive_handler == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito identity provider client is not init properly.")
		return null
	
	var outcome: AWSSDKCognitoIdentityProvider_Model_ForgotPasswordOutcome = await response_receive_handler.complete
	
	if !outcome.success or outcome.result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, outcome.error_message)
		return null
		
	add_user_signal("confirm_forgot_password", [
		{ "name": "code", "type": TYPE_STRING },
		{ "name": "password", "type": TYPE_STRING},
	])
	
	tab_container.current_tab = 4
	
	var confirmed: bool = false
	var confirmed_infos: Array
	
	while !confirmed:
		confirmed_infos = await Signal(self, "confirm_forgot_password")
		
		if confirmed_infos.size() != 2:
			remove_user_signal("confirm_forgot_password")
			return null
	
		confirmed = await _confirm_forgot_password(username, confirmed_infos[0], confirmed_infos[1])
	
	
	remove_user_signal("confirm_forgot_password")
	
	if not confirmed:
		return null
	
	tab_container.current_tab = 0
	
	return await _login(username, confirmed_infos[1])


func _confirm_forgot_password(username: String, code: String, password: String) -> bool:
	if (
		game_instance.cognito_region.is_empty() 
		or not game_instance.cognito_identity_provider_clients.has(game_instance.cognito_region)
	):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Can't find cognito idp client object for region: %s" % game_instance.cognito_region)
		return false
		
	var cognito_identity_provider_client: CognitoIdentityProviderClient = game_instance.cognito_identity_provider_clients[game_instance.cognito_region]	
	
	if (cognito_identity_provider_client == null):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Cognito idp client object for region: %s is not initiated" % game_instance.cognito_region)
		return false
	
	var request: AWSSDKCognitoIdentityProvider_Model_ConfirmForgotPasswordRequest = AWSSDKCognitoIdentityProvider_Model_ConfirmForgotPasswordRequest.new()
	request.client_id = game_instance.cognito_client_id
	request.secret_hash = AWSSDKCognitoIdentityProvider_SecretHashHelper.compute_secret_hash(
		username,
		game_instance.cognito_client_id, 
		game_instance.cognito_client_secret_key,
		)
	request.username = username
	request.confirmation_code = code
	request.password = password
	var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_ConfirmForgotPasswordResponseReceivedHandler = cognito_identity_provider_client.confirm_forgot_password(request)
	
	if response_receive_handler == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito identity provider client is not init properly.")
		return false
	
	var outcome: AWSSDKCognitoIdentityProvider_Model_ConfirmForgotPasswordOutcome = await response_receive_handler.complete
	
	if !outcome.success or outcome.result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, outcome.error_message)
		return false
		
	return true


func _get_user_info(auth_result: AWSSDKCognitoIdentityProvider_Model_AuthenticationResultType) -> AWSSDKCognitoIdentityProvider_Model_GetUserResult:
	if (
		game_instance.cognito_region.is_empty() 
		or not game_instance.cognito_identity_provider_clients.has(game_instance.cognito_region)
	):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Can't find cognito idp client object for region: %s" % game_instance.cognito_region)
		return null
		
	var cognito_identity_provider_client: CognitoIdentityProviderClient = game_instance.cognito_identity_provider_clients[game_instance.cognito_region]
	
	if (cognito_identity_provider_client == null):
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "Cognito idp client object for region: %s is not initiated" % game_instance.cognito_region)
		return null
	
	var request: AWSSDKCognitoIdentityProvider_Model_GetUserRequest = AWSSDKCognitoIdentityProvider_Model_GetUserRequest.new()
	request.access_token = auth_result.access_token
	
	var response_receive_handler: AWSSDKCognitoIdentityProvider_Model_GetUserResponseReceivedHandler = cognito_identity_provider_client.get_user(request)
	
	if response_receive_handler == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "cognito identity provider client is not init properly.")
		return null
	
	var outcome: AWSSDKCognitoIdentityProvider_Model_GetUserOutcome = await response_receive_handler.complete
	
	if !outcome.success or outcome.result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, outcome.error_message)
		return null
		
	return outcome.result


@export var tab_container: TabContainer

@export var login_username: LineEdit
@export var login_password: LineEdit
@export var login_password_switch: CheckButton
@export var login_confirm: Button


func _on_login_panel_password_visibility_switch_pressed():
	login_password.secret = !login_password_switch.button_pressed


func _on_login_panel_login_pressed():
	game_instance.auth_result = await _login(login_username.text, login_password.text)
	if game_instance.auth_result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Warning, "login failed")
		return
		
	game_instance.cache_logged_in_user(await _get_user_info(game_instance.auth_result))
	
	if game_instance.refresh_clients(await game_instance.get_credentials_for_clients()):
		game_instance.enter_game()


func _on_login_panel_navigate_forgot_password_pressed():
	tab_container.current_tab = 3


func _on_login_panel_navigate_sign_up_pressed():
	tab_container.current_tab = 1


func _on_login_panel_input_text_changed(_new_text):
	if login_username.text.is_empty() or login_password.text.is_empty():
		login_confirm.disabled = true
	else:
		login_confirm.disabled = false

@export var sign_up_username: LineEdit
@export var sign_up_password: LineEdit
@export var sign_up_password_switch: CheckButton
@export var sign_up_email: LineEdit
@export var sign_up_confirm: Button


func _on_sign_up_panel_password_visibility_switch_pressed():
	sign_up_password.secret = !sign_up_password_switch.button_pressed


func _on_sign_up_panel_sign_up_pressed():
	game_instance.auth_result = await _sign_up(sign_up_username.text, sign_up_password.text, sign_up_email.text)
	if game_instance.auth_result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Warning, "sign up failed")
		return
		
	game_instance.cache_logged_in_user(await _get_user_info(game_instance.auth_result))
	
	if game_instance.refresh_clients(await game_instance.get_credentials_for_clients()):
		game_instance.enter_game()


func _on_sign_up_panel_navigate_login_pressed():
	tab_container.current_tab = 0


func _on_sign_up_panel_input_text_changed(_new_text):
	if sign_up_username.text.is_empty() or sign_up_password.text.is_empty() or sign_up_email.text.is_empty():
		sign_up_confirm.disabled = true
	else:
		sign_up_confirm.disabled = false


@export var confirm_sign_up_code: LineEdit
@export var confirm_sign_up_confirm: Button


func _on_confirm_sign_up_panel_confirm_pressed():
	if has_user_signal("confirm_sign_up"):
		var error: Error = emit_signal("confirm_sign_up", confirm_sign_up_code.text)
		if error != Error.OK:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "emit confirm_sign_up signal failed: %d" % error)


func _on_confirm_sign_up_panel_resend_pressed():
	await _sign_up_resend(sign_up_username.text)


func _on_confirm_sign_up_panel_back_pressed():
	tab_container.current_tab = 1
	if has_user_signal("confirm_sign_up"):
		var error: Error = emit_signal("confirm_sign_up", "")
		if error != Error.OK:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "emit confirm_sign_up signal failed: %d" % error)


func _on_confirm_sign_up_panel_input_text_changed(_new_text):
	if confirm_sign_up_code.text.is_empty() or confirm_code_regex.search(confirm_sign_up_code.text) == null:
		confirm_sign_up_confirm.disabled = true
	else:
		confirm_sign_up_confirm.disabled = false


@export var forgot_password_username: LineEdit
@export var forgot_password_confirm: Button


func _on_forgot_password_panel_forgot_password_pressed():
	game_instance.auth_result = await _forgot_password(forgot_password_username.text)
	if game_instance.auth_result == null:
		game_instance.notification.emit(game_instance.NotificationLevel.Warning, "forget password failed")
		return
		
	game_instance.cache_logged_in_user(await _get_user_info(game_instance.auth_result))
	
	if game_instance.refresh_clients(await game_instance.get_credentials_for_clients()):
		game_instance.enter_game()


func _on_forgot_password_panel_navigate_login_pressed():
	tab_container.current_tab = 0


func _on_forgot_password_panel_input_text_changed(_new_text):
	if forgot_password_username.text.is_empty():
		forgot_password_confirm.disabled = true
	else:
		forgot_password_confirm.disabled = false


@export var confirm_forgot_password_code: LineEdit
@export var confirm_forgot_password_password: LineEdit
@export var confirm_forgot_password_visibility_switch: CheckButton
@export var confirm_forgot_password_confirm: Button


func _on_confirm_forgot_password_panel_confirm_pressed():
	if has_user_signal("confirm_forgot_password"):
		var error: Error = emit_signal(
			"confirm_forgot_password", 
			confirm_forgot_password_code.text, 
			confirm_forgot_password_password.text
			)
		if error != Error.OK:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "emit confirm_forgot_password signal failed: %d" % error)


func _on_confirm_forgot_password_resend_pressed():
	await _forgot_password(forgot_password_username.text)


func _on_confirm_forgot_password_panel_back_pressed():
	tab_container.current_tab = 3
	if has_user_signal("confirm_forgot_password"):
		var error: Error = emit_signal("confirm_forgot_password")
		if error != Error.OK:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "emit confirm_forgot_password signal failed: %d" % error)


func _on_confirm_forgot_password_password_visibility_switch_pressed():
	confirm_forgot_password_password.secret = !confirm_forgot_password_visibility_switch.button_pressed


func _on_confirm_forgot_password_panel_input_text_changed(_new_text):
	if confirm_forgot_password_code.text.is_empty() or confirm_code_regex.search(confirm_forgot_password_code.text) == null or confirm_forgot_password_password.text.is_empty():
		confirm_forgot_password_confirm.disabled = true
	else:
		confirm_forgot_password_confirm.disabled = false


@export var mfa_code: LineEdit
@export var mfa_confirm: Button


func _on_mfa_panel_login_pressed():
	if has_user_signal("confirm_mfa"):
		var error: Error = emit_signal("confirm_mfa", mfa_code.text)
		if error != Error.OK:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "emit confirm_mfa signal failed: %d" % error)


func _on_mfa_panel_back_pressed():
	tab_container.current_tab = 0
	if has_user_signal("confirm_mfa"):
		var error: Error = emit_signal("confirm_mfa", "")
		if error != Error.OK:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "emit confirm_mfa signal failed: %d" % error)


func _on_mfa_panel_input_text_changed(_new_text):
	if mfa_code.text.is_empty() or not mfa_code.text.match("\\d{6}"):
		mfa_confirm.disabled = true
	else:
		mfa_confirm.disabled = false
