class_name Player
extends CharacterBody3D

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

func _ready():
	if player_id == -1:
		print("didn't receive player id")
		queue_free()
		return
		
	is_local_player = (player_id == multiplayer.get_unique_id())
	print("player %d ready" % player_id)
	if is_local_player:
		$RPCGroup.join_group("Default")
		audio_recorder = audio_recorder_scene.instantiate()
		audio_recorder.bus = record_bus
		# to debug audio, enable below line, it will generate a pcm file for Post-mortem Debugging
		#audio_recorder.debug_audio = true
		$CollisionShape3D/MeshInstance3D.add_child(audio_recorder)
		audio_listener = audio_listener_3d_scene.instantiate()
		# to debug audio, enable below line, it will generate a pcm file for Post-mortem Debugging
		#audio_listener.debug_audio = true
		$CameraPivot/SpringArm3D/Camera3D.add_child(audio_listener)
		audio_listener.make_current()
		
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
