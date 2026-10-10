extends CharacterBody3D

const SPEED = 3
const MOUSE_SENSITIVITY = 0.003

@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var camera: Camera3D = $Camera3D

# อ้างอิง Node AnimationPlayer
@onready var anim_player: AnimationPlayer = $Character_Male_36/AnimationPlayer

var can_move: bool = true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event.is_action_pressed("interact"):
		check_interaction()
		return

	# ล็อกเมาส์หมุนกล้องเมื่อ can_move เป็น false
	if not can_move:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- เช็ก Raycast เพื่ออัปเดตป้าย Press [E] to Talk ทุกเฟรม ---
	update_interaction_prompt()

	# ล็อกการเคลื่อนที่แนวระนาบ X/Z สั่งหยุดนิ่งทันที
	if not can_move:
		velocity.x = 0
		velocity.z = 0
		if anim_player and anim_player.current_animation != "Idle":
			anim_player.play("Idle", 0.25)
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# --- ระบบสลับอนิเมชัน Idle / Walking แบบผสมทรานซิชันนุ่มนวล ---
	if anim_player:
		if direction != Vector3.ZERO:
			if anim_player.current_animation != "Walking":
				anim_player.play("Walking", 0.25)
		else:
			if anim_player.current_animation != "Idle":
				anim_player.play("Idle", 0.25)

	move_and_slide()

func check_interaction() -> void:
	if raycast.is_colliding():
		var target = raycast.get_collider()
		if target and target.has_method("interact"):
			velocity.x = 0
			velocity.z = 0
			target.interact()

func update_interaction_prompt() -> void:
	if raycast.is_colliding():
		var target = raycast.get_collider()
		if target and target.has_method("interact"):
			# ตรวจสอบว่า NPC แสดงตัวอยู่หรือไม่ (ตาม StoryManager)
			if "visible" in target and not target.visible:
				DialogueUi.hide_prompt()
				return
				
			# แสดงข้อความ
			var msg = "Press [E] to Talk"
			if "prompt_message" in target:
				msg = target.prompt_message
				
			DialogueUi.show_prompt(msg)
			return

	# ถ้าไม่ได้มอง NPC ให้ซ่อน
	DialogueUi.hide_prompt()
	
func set_can_move(value: bool) -> void:
	can_move = value
	if not can_move:
		velocity.x = 0
		velocity.z = 0
		velocity.z = 0
