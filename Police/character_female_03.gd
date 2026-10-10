extends CharacterBody3D

@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_running: bool = false # Tracks if we are running or walking

@onready var camera: Camera3D = $Camera3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
	
	# Toggle between Walking and Running on Shift key press (not holding)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SHIFT:
			is_running = not is_running

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump
	var just_jumped := false
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity
		just_jumped = true

	# Direct WASD Movement
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
		
	var direction := (transform.basis * input_dir).normalized()
	
	# Determine current speed based on whether toggle is active
	var current_speed = run_speed if is_running else walk_speed
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed)
		velocity.z = move_toward(velocity.z, 0, walk_speed)

	# --- ANIMATION LOGIC ---
	if just_jumped:
		animation_player.play("Jump")
	elif is_on_floor():
		if direction:
			if is_running:
				if animation_player.current_animation != "Run":
					animation_player.play("Run")
			else:
				if animation_player.current_animation != "Walking":
					animation_player.play("Walking")
		else:
			if animation_player.current_animation != "Idle":
				animation_player.play("Idle")
	else:
		if animation_player.current_animation == "Jump" and animation_player.is_playing():
			pass 
		elif animation_player.current_animation != "Idle":
			animation_player.play("Idle")

	move_and_slide()
