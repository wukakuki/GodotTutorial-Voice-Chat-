class_name PlayerInput
extends MultiplayerSynchronizer

@export var jumping := false
@export var direction := Vector2()
@export var look_direction := Vector2()

@export_range(0.0, 1.0) var mouse_sensitivity = 0.01
@export_range(0.0, 1.0) var joystick_sensitivity = 0.05
@export var tilt_limit_up = deg_to_rad(75)
@export var tilt_limit_down = -deg_to_rad(75)

var is_local_player: bool = false

func _ready():
	is_local_player = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(is_local_player)

func _process(_delta):
	direction = Input.get_vector("move_leftward", "move_rightward", "move_forward", "move_backward")
	if Input.is_action_just_pressed("jump"):
		jump.rpc()
		
	var temp_look_direction: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
		
	if temp_look_direction.length() > 0.1:
		look.rpc(Vector2(
			-temp_look_direction.y * joystick_sensitivity,
			-temp_look_direction.x * joystick_sensitivity
			))
		
	
func _input(event):
	if not is_local_player:
		return
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event.is_action_pressed("click") and not OS.has_feature("mobile"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			
func _unhandled_input(event):
	if not is_local_player:
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look.rpc(Vector2(
			-event.screen_relative.y * mouse_sensitivity, 
			-event.screen_relative.x * mouse_sensitivity
			))

@rpc("authority", "call_local")
func jump():
	jumping = true

@rpc("authority", "call_local")
func look(temp_look_direction: Vector2):
	look_direction = temp_look_direction
