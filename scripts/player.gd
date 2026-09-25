extends CharacterBody3D
class_name Player

@export var move_vel : float = 5.0
@export var jump_vel : float = 4.5
@export var mouse_sens : float = 0.002
@export var gamepad_sens : float = 0.025
@export var cam_x_min_deg : float = -70.0
@export var cam_x_max_deg : float = 70.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var cam_x_min_rad : float;
var cam_x_max_rad : float;

func _ready():
	$Camera3D.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cam_x_min_rad = deg_to_rad(cam_x_min_deg)	
	cam_x_max_rad = deg_to_rad(cam_x_max_deg)	
	
func rotate_camera(axis_x, axis_y, sensitivity):	
	rotate_y(-axis_x * sensitivity)
	$Camera3D.rotate_x(-axis_y * sensitivity)
	$Camera3D.rotation.x = clampf($Camera3D.rotation.x, cam_x_min_rad, cam_x_max_rad)	

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_camera(event.relative.x, event.relative.y, mouse_sens)

func _process(_delta):
	var input_dir = Input.get_vector("rotate_left", "rotate_right", "rotate_up", "rotate_down")
	if input_dir.length() > 0.0:
		rotate_camera(input_dir.x, input_dir.y, gamepad_sens)
		
func _physics_process(delta):
	# its on the floor?
	if not is_on_floor():
		# add gravity
		velocity.y -= gravity * delta		
	else:
		# handle jump
		if Input.is_action_just_pressed("action_jump") and is_on_floor():
			velocity.y = jump_vel				

	# get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * move_vel
		velocity.z = direction.z * move_vel
	else:
		velocity.x = move_toward(velocity.x, 0, move_vel)
		velocity.z = move_toward(velocity.z, 0, move_vel)

	# procesamos el movimiento
	move_and_slide()			
