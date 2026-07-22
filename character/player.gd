class_name Player
extends CharacterBody3D


var game_instance: GameInstance = null


func _init():
	game_instance = GameInstance.singleton


const SPEED = 5.0
const TURN_SPEED = 30
const JUMP_VELOCITY = 4.5

@export_range(0.0, 1.0) var mouse_sensitivity = 0.01
@export_range(0.0, 1.0) var joystick_sensitivity = 0.05
@export var tilt_limit_up = deg_to_rad(75)
@export var tilt_limit_down = -deg_to_rad(75)

@export var audio_recorder_scene: PackedScene
@export var record_bus: StringName = "Record"
var audio_recorder: EmbeddedVoiceChatAudioCapture
@export var audio_listener_3d_scene: PackedScene
var audio_listener: EmbeddedVoiceChatAudioPlayback
@onready var input: PlayerInput = $PlayerInput

var is_local_player: bool = false
@export var player_id: int = -1:
	set(id):
		player_id = id
		$PlayerInput.set_multiplayer_authority(player_id)
		$RPCGroup.owning_client_id = player_id
		
@export var player_session_id: String
		
var master_low_pass_filter: AudioEffectLowPassFilter
var master_reverb: AudioEffectReverb
var master_phaser: AudioEffectPhaser
var record_low_pass_filter: AudioEffectLowPassFilter
var record_reverb: AudioEffectReverb
var record_phaser: AudioEffectPhaser


func _ready():
	if player_id == -1:
		game_instance.notification.emit(game_instance.NotificationLevel.Error, "didn't receive player id")
		queue_free()
		return
		
	is_local_player = (player_id == multiplayer.get_unique_id())
	game_instance.notification.emit(game_instance.NotificationLevel.Verbose, "player %d ready" % player_id)
	if is_local_player:
		$RPCGroup.join_group("Default")
		audio_recorder = audio_recorder_scene.instantiate()
		audio_recorder.bus = record_bus
		# to debug audio, enable below line
		# it will generate a pcm file for Post-mortem Debugging
		#audio_recorder.debug_audio = true
		$CollisionShape3D/MeshInstance3D.add_child(audio_recorder)
		audio_listener = audio_listener_3d_scene.instantiate()
		# to debug audio, enable below line
		# it will generate a pcm file for Post-mortem Debugging
		#audio_listener.debug_audio = true
		$CameraPivot/SpringArm3D/Camera3D.add_child(audio_listener)
		audio_listener.make_current()
		
		master_low_pass_filter = AudioEffectLowPassFilter.new()
		master_reverb = AudioEffectReverb.new()
		master_phaser = AudioEffectPhaser.new()
		
		master_low_pass_filter.cutoff_hz = 500
		master_reverb.predelay_msec = 20
		master_reverb.room_size = 0.2
		master_reverb.damping = 0.2
		master_phaser.rate_hz = 0.1
		master_phaser.depth = 0.2
		
		record_low_pass_filter = AudioEffectLowPassFilter.new()
		record_reverb = AudioEffectReverb.new()
		record_phaser = AudioEffectPhaser.new()
		
		record_low_pass_filter.cutoff_hz = 500
		record_reverb.predelay_msec = 20
		record_reverb.room_size = 0.2
		record_reverb.damping = 0.2
		record_phaser.rate_hz = 0.1
		record_phaser.depth = 0.2
		
	# only update physics on server side
	set_physics_process(multiplayer.get_unique_id() == 1)
	$CameraPivot/SpringArm3D/Camera3D.current = is_local_player
	
func _exit_tree():
	if audio_recorder != null:
		audio_recorder.queue_free()
		audio_recorder = null
	if audio_listener != null:
		audio_listener.queue_free()
		audio_listener = null

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if input.jumping and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	input.jumping = false
	
	var look_direction: Vector2 = input.look_direction
	if look_direction.length() > 0.1:
		$CameraPivot.rotation.x += look_direction.x
		$CameraPivot.rotation.x = clampf($CameraPivot.rotation.x, tilt_limit_down, tilt_limit_up)
		$CameraPivot.rotation.y += look_direction.y
		
	input.look_direction = Vector2.ZERO

	# Get the input direction and handle the movement/deceleration.
	var direction: Vector3 = Vector3(input.direction.x, 0, input.direction.y)
	if direction != Vector3.ZERO:
		direction = direction.normalized().rotated(Vector3.UP, $CameraPivot.rotation.y)
		
		$CollisionShape3D.rotation.y = lerp_angle(
			$CollisionShape3D.rotation.y,
			Basis.looking_at(direction).get_euler().y,
			TURN_SPEED * delta
		)
		
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
func enter_water():
	if is_local_player:
		var master_bus_idx = AudioServer.get_bus_index("Master")
		if master_bus_idx == -1:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "there is no Master bus")
			return
			
		AudioServer.add_bus_effect(master_bus_idx, master_phaser, 0)
		AudioServer.add_bus_effect(master_bus_idx, master_reverb, 0)
		AudioServer.add_bus_effect(master_bus_idx, master_low_pass_filter, 0)
		
		var record_bus_idx = AudioServer.get_bus_index("Record")
		if record_bus_idx == -1:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "there is no Master bus")
			return
			
		AudioServer.add_bus_effect(record_bus_idx, record_phaser, 0)
		AudioServer.add_bus_effect(record_bus_idx, record_reverb, 0)
		AudioServer.add_bus_effect(record_bus_idx, record_low_pass_filter, 0)
		
	
func exit_water():
	if is_local_player:
		var master_bus_idx = AudioServer.get_bus_index("Master")
		if master_bus_idx == -1:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "there is no Master bus")
			return
			
		remove_audio_effect(master_bus_idx, master_phaser)
		remove_audio_effect(master_bus_idx, master_reverb)
		remove_audio_effect(master_bus_idx, master_low_pass_filter)
		
		var record_bus_idx = AudioServer.get_bus_index("Record")
		if record_bus_idx == -1:
			game_instance.notification.emit(game_instance.NotificationLevel.Error, "there is no Master bus")
			return
			
		remove_audio_effect(record_bus_idx, master_phaser)
		remove_audio_effect(record_bus_idx, master_reverb)
		remove_audio_effect(record_bus_idx, master_low_pass_filter)
		
func remove_audio_effect(bus_idx: int, audio_effect: AudioEffect):
	var effect_count = AudioServer.get_bus_effect_count(bus_idx)
	for i in range(effect_count - 1, -1, -1):
		if AudioServer.get_bus_effect(bus_idx, i) == audio_effect:
			AudioServer.remove_bus_effect(bus_idx, i)
