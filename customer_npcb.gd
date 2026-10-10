extends CharacterBody3D
# ลูกค้า B: ลงจากรถ เดินตามจุด Marker แล้วหยุดรอให้ผู้เล่นกด E คุย จากนั้นเดินกลับขึ้นรถ
# แปะสคริปต์นี้ที่โหนดรากของฉาก CustomerNPCB (CharacterBody3D)
# ปกติไม่ต้องเรียกเอง node.gd (ตัวควบคุมเหตุการณ์ในโฟลเดอร์แมพ) จะสั่งให้เอง

signal reached_destination
## ผู้เล่นกด E คุยกับลูกค้า (หลังเรียก enable_talk)
signal interacted

@export_group("เส้นทาง (ลาก Marker3D มาใส่ได้เลย)")
## เส้นทางที่เดินหลังลงรถ จุดสุดท้าย = จุดที่ยืนรอผู้เล่น (เว้นว่าง = หา Marker ชื่อ TargetPointB1, 2, ...)
@export var walk_points: Array[Node3D] = []
## เส้นทางที่เดินกลับไปขึ้นรถ (เว้นว่าง = หา TargetPointBBack1, 2, ... ถ้าไม่มีก็เดินย้อนทางเดิม)
@export var back_points: Array[Node3D] = []

## โมเดลลูกค้าหันหน้าไปทาง +Z เลยต้องหมุน 180 องศา ไม่งั้นจะเดินหันหลัง (ถ้าเดินถอยหลัง/ข้างๆ ลอง 0, 90, -90)
@export var model_yaw_offset_deg: float = 180.0

const SPEED := 1.3
const ARRIVE_DISTANCE := 0.4
const STUCK_SECONDS := 1.2
const GHOST_DISTANCE := 2.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _anim: AnimationPlayer
var _queue: Array[Vector3] = []
var _target: Vector3
var _moving: bool = false
var _final_marker: Node3D

var _orig_mask: int = 1
var _orig_layer: int = 1
var _stuck_time: float = 0.0
var _ghost: bool = false
var _ghost_start: Vector3

# คุยกับผู้เล่น: ผู้เล่นมองที่ตัวลูกค้าแล้วกด E (player.gd เรียก interact ให้เอง)
var _talk_ready: bool = false
var _hint: Label3D
var _t: float = 0.0

# player.gd อ่านค่านี้ไปโชว์เป็นป้ายตอนมองตัวลูกค้า (ยังคุยไม่ได้ = ไม่โชว์อะไร)
var prompt_message: String:
	get:
		return "Press [E] to talk / check out" if _talk_ready else ""

func _ready() -> void:
	_orig_mask = collision_mask
	_orig_layer = collision_layer
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	hide_npc()

func hide_npc() -> void:
	_talk_ready = false
	_hide_hint()
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

# โผล่ที่ตำแหน่งนี้ (เช่น ข้างประตูรถ)
func appear_at(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos
	rotation.y = yaw + deg_to_rad(model_yaw_offset_deg)
	collision_layer = _orig_layer
	collision_mask = _orig_mask
	visible = true
	set_physics_process(true)
	_play_anim("Idle")

# เดินตามจุด รอจนถึงจุดสุดท้าย
func walk_route(points: Array[Node3D]) -> void:
	_queue.clear()
	_final_marker = null
	for p in points:
		if p != null:
			_queue.append(p.global_position)
			_final_marker = p
	if _queue.is_empty():
		return
	_target = _queue.pop_front()
	_moving = true
	await reached_destination

# เปิดให้ผู้เล่นกด E คุยได้ (มีป้ายลอยเหนือหัว)
func enable_talk(hint_text: String = "Checkout\nV") -> void:
	_talk_ready = true
	_show_hint(hint_text)

# player.gd เรียกฟังก์ชันนี้ตอนผู้เล่นมองตัวลูกค้าแล้วกด E
func interact() -> void:
	if not _talk_ready:
		return
	_talk_ready = false
	_hide_hint()
	interacted.emit()

func _show_hint(text: String) -> void:
	if _hint == null:
		_hint = Label3D.new()
		_hint.font_size = 64
		_hint.pixel_size = 0.005
		_hint.outline_size = 14
		_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hint.no_depth_test = true
		_hint.modulate = Color(1.0, 0.9, 0.3)
		_hint.position = Vector3(0, 2.7, 0)
		add_child(_hint)
	_hint.text = text
	_hint.visible = true

func _hide_hint() -> void:
	if _hint:
		_hint.visible = false

func _physics_process(delta: float) -> void:
	_t += delta
	if _hint and _hint.visible:
		_hint.position.y = 2.7 + sin(_t * 3.0) * 0.08

	if not is_on_floor() and not _ghost:
		velocity.y -= gravity * delta

	if not _moving:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim("Idle")
		move_and_slide()
		return

	var flat := _target - global_position
	flat.y = 0.0
	if flat.length() < ARRIVE_DISTANCE:
		if _queue.size() > 0:
			_target = _queue.pop_front()
		else:
			_finish()
			return
		flat = _target - global_position
		flat.y = 0.0

	var want_move := flat.length() > 0.01
	if want_move:
		var dir := flat.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		_play_anim("Walking")
		var angle := atan2(-dir.x, -dir.z) + deg_to_rad(model_yaw_offset_deg)
		rotation.y = rotate_toward(rotation.y, angle, 6.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if _ghost:
		velocity.y = 0.0
	move_and_slide()
	_update_stuck(delta, want_move)

# ถ้าเดินไม่ไปไหน ปิดการชนชั่วคราวให้ทะลุสิ่งกีดขวางสั้นๆ
func _update_stuck(delta: float, want_move: bool) -> void:
	if _ghost:
		if global_position.distance_to(_ghost_start) > GHOST_DISTANCE:
			_end_ghost()
		return
	if not want_move:
		_stuck_time = 0.0
		return
	var real := get_real_velocity()
	if Vector2(real.x, real.z).length() < SPEED * 0.25:
		_stuck_time += delta
		if _stuck_time > STUCK_SECONDS:
			_ghost = true
			_ghost_start = global_position
			collision_mask = 0
	else:
		_stuck_time = 0.0

func _end_ghost() -> void:
	_ghost = false
	_stuck_time = 0.0
	collision_mask = _orig_mask

func _finish() -> void:
	if _ghost:
		_end_ghost()
	_moving = false
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim("Idle")
	# หันหน้าตามแกน Z ของ Marker สุดท้าย (ถ้าหันผิดด้านให้หมุน Marker 180 องศา)
	if _final_marker:
		var f := _final_marker.global_transform.basis.z
		f.y = 0.0
		if f.length_squared() > 0.001:
			rotation.y = atan2(f.x, f.z)
	reached_destination.emit()

func _play_anim(anim_name: String) -> void:
	if _anim and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.2)
