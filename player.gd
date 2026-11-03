extends CharacterBody3D
class_name Player

@export var model: Node3D
@export var camera: Camera3D
@export var climbing_raycast: RayCast3D
@export var use_cam_basis: bool

@export var SPEED = 5
@export var JUMP_VELOCITY: float = 4.0

@export_range(0, 20, .5) var gravity_multiplier: float = 1

var last_ground_input: Vector2

enum PlayerState { IDLE, WALKING, JUMPING, CLIMBING }

@export var state: PlayerState = PlayerState.IDLE

var target_basis: Basis

func _ready() -> void:
	target_basis = transform.basis

func can_climb() -> bool:
	return climbing_raycast.is_colliding()

func process_walking_state(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_multiplier * delta
	
	if state == PlayerState.JUMPING and is_on_floor():
		state = PlayerState.IDLE

	## Handle jump.
	var can_jump = is_on_floor() and not can_climb() and Input.is_action_just_pressed("action")
	if can_jump:
		state = PlayerState.JUMPING
		velocity.y = JUMP_VELOCITY

	var speed_multiplier = 1

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_basis = transform.basis
	if use_cam_basis:
		var cam_basis: Basis = camera.transform.basis
		var angles = cam_basis.get_euler()
		angles.x = 0
		move_basis = Basis.from_euler(angles)
	var direction := (move_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if not is_on_floor():
		var fall_direction := (camera.transform.basis * Vector3(last_ground_input.x, 0, last_ground_input.y)).normalized()
		direction = direction.slerp(fall_direction, .6)
	
	var moving_speed = SPEED * input_dir.length() * speed_multiplier
	velocity.x = lerp(velocity.x, direction.x * moving_speed, .2)
	velocity.z = lerp(velocity.z, direction.z * moving_speed, .2)
	
	var forward = Vector2(0, 1)
	var direction_rotation = forward.angle_to(Vector2(-direction.x, direction.z))
	direction_rotation += PI
	
	var target_rotation = rotation.y
	if input_dir.length() > 0:
		target_rotation = direction_rotation
	
	rotation.y = lerp_angle(rotation.y, target_rotation, .1)
	
	move_and_slide()
	if is_on_floor():
		last_ground_input = input_dir

func process_climbing_state(delta: float) -> void:
	var normal = climbing_raycast.get_collision_normal()
	if not climbing_raycast.is_colliding() or normal.dot(Vector3.UP) > 0.8:
		var player_angles = transform.basis.get_euler()
		player_angles.x = 0
		target_basis = Basis.from_euler(player_angles)
		state = PlayerState.JUMPING
		return
	target_basis = Basis.looking_at(-normal)
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (target_basis * Vector3(input_dir.x, -input_dir.y, 0)).normalized()
	velocity = direction * SPEED * 20 * delta
	move_and_slide()

func _physics_process(delta: float) -> void:
	if state != PlayerState.CLIMBING:
		process_walking_state(delta)
	else:
		process_climbing_state(delta)

	transform.basis = transform.basis.slerp(target_basis, 0.2)


func _input(event: InputEvent) -> void:
	if can_climb() and is_on_floor() and event.is_action("action"):
		_on_climb_input()

func _on_climb_input() -> void:
	state = PlayerState.CLIMBING
