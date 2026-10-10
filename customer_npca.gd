extends CharacterBody3D
# ลูกค้า A: หลังสำรวจเสร็จ วาร์ปมาที่ TargetPointA1 หันหน้าไปทางเคาน์เตอร์
#   1) ผู้เล่นเดินเข้า "วงสแกร์" (Area3D2) -> จั๊มสแกร์ด้วยเสียง + จอวาบ + กล้องสะดุ้ง -> ลูกค้าพูด "แฮะ ตกใจละสิ"
#   2) หลังจากนั้นผู้เล่นมองที่ตัวลูกค้าแล้วกด E -> บทคุยคิดเงิน
#   3) คุยจบ ลูกค้าเดินออกไปตามจุด TargetPointAOut1, 2, ... พอถึงจุดสุดท้ายก็หายไป -> งาน customer_a เสร็จ
# แปะสคริปต์นี้ที่โหนดรากของฉาก CustomerNPCA (CharacterBody3D) ไม่ต้องมีโหนดควบคุมเพิ่ม

const HERO := "Big Judy"
const CUSTOMER := "Customer"   # เปลี่ยนชื่อลูกค้าที่นี่ที่เดียว

## ชื่องานใน DAY_PLAN ของ StoryManager
@export var task_id: String = "customer_a"
## งานที่ต้องเสร็จก่อนลูกค้าจะวาร์ปมา
@export var after_task_id: String = "explore"
## หน่วงกี่วินาทีหลังสำรวจเสร็จ ก่อนลูกค้าโผล่
@export var appear_delay: float = 1.0

@export_group("ตำแหน่ง")
## จุดที่วาร์ปมา (เว้นว่าง = หา Marker3D ชื่อ TargetPointA1 ในแมพ)
@export var spawn_point: Node3D
## ลูกค้าหันหน้าไปทางจุดนี้ (วาง Marker3D ไว้ที่เคาน์เตอร์แล้วลากมาใส่)
## เว้นว่าง = หันตามแกน Z (ลูกศรสีน้ำเงิน) ของ TargetPointA1
@export var look_target: Node3D
## โมเดลหันหน้าไปทาง +Z (เหมือนลูกค้า B) ถ้าลูกค้าหันหลังให้เคาน์เตอร์ ให้ลองติ๊กออก หรือใส่ Yaw Offset 180
@export var model_faces_plus_z: bool = true
@export var yaw_offset_deg: float = 0.0

@export_group("วงจั๊มสแกร์")
## วง Area3D ที่ผู้เล่นเดินเข้าแล้วโดนสแกร์ (เว้นว่าง = หาโหนดชื่อ Area3D2 ในตัวลูกค้า)
@export var scare_zone: Area3D
## เสียงจั๊มสแกร์ (ลากไฟล์เสียงมาใส่)
@export var snd_jumpscare: AudioStream
@export var jumpscare_volume_db: float = 6.0
@export var flash_color: Color = Color(1, 1, 1, 1)
@export var flash_time: float = 0.35
## กล้องสั่น (หน่วยเมตร) และเวลา
@export var shake_strength: float = 0.25
@export var shake_time: float = 0.5
## กล้องซูมเข้ากี่องศาตอนสะดุ้ง (0 = ไม่ซูม)
@export var fov_punch: float = 15.0
## หลังสแกร์กี่วินาทีลูกค้าถึงเริ่มพูด
@export var scare_dialogue_delay: float = 0.7

@export_group("เดินออกหลังคิดเงิน")
## เส้นทางที่ลูกค้าเดินออกไป เรียงตามลำดับ จุดสุดท้ายคือจุดที่หายไป
## (เว้นว่าง = หา Marker3D ชื่อ TargetPointAOut1, TargetPointAOut2, ... ในแมพ)
@export var exit_points: Array[Node3D] = []
@export var walk_speed: float = 1.3
## คุยจบแล้วรอกี่วินาทีก่อนเดินออก
@export var pause_before_leave: float = 0.8
## ถ้าไม่มีจุดเดินออกเลย ให้ลูกค้าหายไปทันทีหลังคุยจบหรือไม่ (ไม่ติ๊ก = ยืนอยู่ที่เดิม)
@export var disappear_after_talk: bool = false

@export_group("ป้ายกด E")
@export var prompt_text: String = "Press [E] to check out"

# ==========================================
# บทพูดหลังโดนสแกร์ (เปลี่ยนบรรทัดเองตามเวลา) ตัวอย่างเขียนไว้ให้ แก้ได้เลย
# ==========================================
var scare_lines: Array = [
	[CUSTOMER, "Hehehe... gave you a scare, didn't I?"],
	[HERO, "Gah! Y-you scared me half to death! When did you even come in?"],
	[CUSTOMER, "Just now. Sorry about that, I thought you'd seen me."],
	[CUSTOMER, "I'm not some kind of suspicious person, you know."],
	[CUSTOMER, "It's just a hobby. No hard feelings, okay?"],
	[HERO, "Doing that to someone? Of course I got scared."],
	[CUSTOMER, "Okay, okay, calm down. I get it."],
	[CUSTOMER, "Anyway, sorry. Vanes and I mess around like this all the time."],
	[CUSTOMER, "I just didn't expect it to be someone other than Vanes tonight."],
	[HERO, "Sorry that I'm not Vanes."],
]

# ==========================================
# บทคุยคิดเงิน (ตอนกด E) กด E ไปบรรทัดถัดไป ตัวอย่างเขียนไว้ให้ แก้ได้เลย
# ==========================================
var talk_lines: Array = [
	[CUSTOMER, "How much is it all together?"],
	[HERO, "That'll be 67 baht."],
	[HERO, "Scan or cash?"],
	[CUSTOMER, "Cash. Keep the change."],
	[HERO, "Thank you. Please come again."],
	[CUSTOMER, "Hmm... it's nice and quiet here. I like it."],
	[HERO, "I don't, though."],
	[CUSTOMER, "Haha, see you around."],
	[HERO, "Thanks for stopping by. Come again soon!"],
]

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _anim: AnimationPlayer
var _orig_layer: int = 1
var _orig_mask: int = 1
var _appeared: bool = false
var _scared: bool = false
var _scaring: bool = false
var _dialoguing: bool = false
var _line_index: int = 0
var _started_frame: int = -1

# เดินออก
const ARRIVE_DISTANCE := 0.4
const STUCK_SECONDS := 1.2
const GHOST_DISTANCE := 2.0
var _leaving: bool = false
var _walking: bool = false
var _queue: Array[Vector3] = []
var _target: Vector3
var _stuck_time: float = 0.0
var _ghost: bool = false
var _ghost_start: Vector3
signal _route_finished

# player.gd อ่านค่านี้ไปโชว์เป็นป้ายตอนมองตัวลูกค้า (ยังคุยไม่ได้ = ไม่โชว์อะไร)
var prompt_message: String:
	get:
		var ready_to_talk := _appeared and _scared and not _scaring and not _dialoguing and not _leaving
		return prompt_text if ready_to_talk and StoryManager.is_task_pending(task_id) else ""

func _ready() -> void:
	_orig_layer = collision_layer
	_orig_mask = collision_mask
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if scare_zone == null:
		scare_zone = get_node_or_null("Area3D2") as Area3D
	if scare_zone:
		scare_zone.body_entered.connect(_on_scare_body_entered)
	hide_npc()

	# Map_1 เรียก StoryManager.begin_map() ใน _ready ของตัวเอง ซึ่งรันหลังลูกๆ จึงต้องรอ 1 เฟรม
	await get_tree().process_frame
	if not StoryManager.is_task_pending(task_id):
		return   # งานนี้ทำไปแล้ว (หรือวันนี้ไม่มี)
	_scared = StoryManager.has_flag(_scared_key())
	if StoryManager.is_task_done(after_task_id):
		_appear()
	else:
		StoryManager.task_done.connect(_on_task_done)

func _scared_key() -> String:
	return "ca_scared_day_%d" % StoryManager.current_day

func _on_task_done(id: String) -> void:
	if id != after_task_id:
		return
	await get_tree().create_timer(appear_delay).timeout
	_appear()

# ---------- ซ่อน / วาร์ปมา ----------
func hide_npc() -> void:
	_appeared = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	if scare_zone:
		scare_zone.set_deferred("monitoring", false)

func _appear() -> void:
	var sp: Node3D = spawn_point
	if sp == null:
		sp = get_tree().current_scene.get_node_or_null("TargetPointA1") as Node3D
	if sp == null:
		push_warning("CustomerNPCA: หา Marker3D ชื่อ TargetPointA1 ไม่เจอ (ตั้งชื่อให้ตรง หรือลากใส่ช่อง Spawn Point)")
		return

	global_position = sp.global_position
	velocity = Vector3.ZERO

	# หันหน้าไปทางเคาน์เตอร์ (หรือทิศแกน Z ของ Marker)
	var dir: Vector3
	if look_target != null:
		dir = look_target.global_position - global_position
	else:
		dir = sp.global_transform.basis.z
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		var yaw := atan2(dir.x, dir.z) if model_faces_plus_z else atan2(-dir.x, -dir.z)
		rotation.y = yaw + deg_to_rad(yaw_offset_deg)

	collision_layer = _orig_layer
	collision_mask = _orig_mask
	visible = true
	set_physics_process(true)
	_appeared = true
	_play_anim("Idle")
	if scare_zone:
		scare_zone.set_deferred("monitoring", true)

func _physics_process(delta: float) -> void:
	if not is_on_floor() and not _ghost:
		velocity.y -= gravity * delta

	if not _walking:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var flat := _target - global_position
	flat.y = 0.0
	if flat.length() < ARRIVE_DISTANCE:
		if _queue.size() > 0:
			_target = _queue.pop_front()
			flat = _target - global_position
			flat.y = 0.0
		else:
			_walking = false
			if _ghost:
				_end_ghost()
			velocity.x = 0.0
			velocity.z = 0.0
			_route_finished.emit()
			return

	var want_move := flat.length() > 0.01
	if want_move:
		var dir := flat.normalized()
		velocity.x = dir.x * walk_speed
		velocity.z = dir.z * walk_speed
		_play_anim("Walking")
		var yaw := atan2(dir.x, dir.z) if model_faces_plus_z else atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw + deg_to_rad(yaw_offset_deg), minf(1.0, 8.0 * delta))
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if _ghost:
		velocity.y = 0.0   # ระหว่างทะลุสิ่งกีดขวาง ไม่ให้ตกหรือลอย
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
	if Vector2(real.x, real.z).length() < walk_speed * 0.25:
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

# ---------- จั๊มสแกร์ ----------
func _on_scare_body_entered(body: Node3D) -> void:
	if not _appeared or _scared or _scaring:
		return
	if not body.has_method("set_can_move"):
		return   # ไม่ใช่ผู้เล่น
	_jumpscare()

func _jumpscare() -> void:
	_scaring = true
	_scared = true
	StoryManager.set_flag(_scared_key())
	_set_player_can_move(false)
	DialogueUi.hide_prompt()

	_play_scare_sound()
	_flash()
	_shake_camera()

	await get_tree().create_timer(scare_dialogue_delay).timeout
	await _say_lines(scare_lines)
	_scaring = false

func _play_scare_sound() -> void:
	if snd_jumpscare == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = snd_jumpscare
	p.volume_db = jumpscare_volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var r := ColorRect.new()
	r.color = flash_color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, flash_time)
	tw.tween_callback(layer.queue_free)

func _shake_camera() -> void:
	var pl := _find_player()
	if pl == null:
		return
	var cam := pl.get("camera") as Camera3D
	if cam == null:
		return
	var base_fov := cam.fov
	cam.fov = base_fov - fov_punch
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var k := 1.0 - t
		cam.h_offset = randf_range(-1.0, 1.0) * shake_strength * k
		cam.v_offset = randf_range(-1.0, 1.0) * shake_strength * k
		cam.fov = lerpf(base_fov - fov_punch, base_fov, t),
		0.0, 1.0, shake_time)
	tw.tween_callback(func():
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		cam.fov = base_fov)

# ---------- คุยคิดเงิน (กด E) ----------
# player.gd เรียกฟังก์ชันนี้เมื่อผู้เล่นมองที่ตัวลูกค้าแล้วกด E
func interact() -> void:
	if not _appeared or _scaring or _dialoguing or _leaving:
		return
	if DialogueUi.panel.visible:
		return
	if not _scared:
		_jumpscare()   # กด E ก่อนเดินเข้าวง ให้โดนสแกร์ก่อนเสมอ
		return
	if not StoryManager.is_task_pending(task_id):
		return
	_line_index = 0
	_dialoguing = true
	_started_frame = Engine.get_process_frames()
	_show_line()

func _show_line() -> void:
	var line: Array = talk_lines[_line_index]
	DialogueUi.show_dialogue(line[0], line[1])

# กด E เปลี่ยนบรรทัดตอนคุย (ไม่ต้องเล็งที่ตัวลูกค้า)
func _input(event: InputEvent) -> void:
	if not _dialoguing or not event.is_action_pressed("interact", false):
		return
	if Engine.get_process_frames() == _started_frame:
		return   # กด E ครั้งเดียวกับที่เริ่มคุย ไม่นับ
	get_viewport().set_input_as_handled()
	if DialogueUi.is_typing:
		DialogueUi.finish_typing()
		return
	_line_index += 1
	if _line_index < talk_lines.size():
		_show_line()
	else:
		_end_talk()

func _end_talk() -> void:
	DialogueUi.hide_dialogue()
	_dialoguing = false
	_leaving = true
	await get_tree().create_timer(pause_before_leave).timeout

	# เดินออกไปตามจุด พอถึงจุดสุดท้ายก็หายไป
	var route := _exit_route()
	if route.size() > 0:
		_queue.clear()
		for m in route:
			_queue.append(m.global_position)
		_target = _queue.pop_front()
		_walking = true
		await _route_finished
		await get_tree().create_timer(0.2).timeout
		hide_npc()
	elif disappear_after_talk:
		hide_npc()
	else:
		push_warning("CustomerNPCA: ไม่มีจุดเดินออก (วาง Marker3D ชื่อ TargetPointAOut1, 2, ... หรือลากใส่ช่อง Exit Points)")

	# ลูกค้าเดินหายไปแล้ว -> จูดี้พูดขึ้นมา แล้วค่อยจบงาน customer_a
	if not is_instance_valid(self) or not visible:
		await _say_lines([
			[HERO, "That really scared me. What kind of lunatic wanders around in a jumpsuit in the middle of the night?"],
			[HERO, "Am I ever going to meet a normal person here?"],
		])

	_leaving = false
	StoryManager.complete_task(task_id)

# จุดเดินออก: ถ้าลากใส่ Inspector ใช้ตามนั้น ไม่งั้นหา Marker3D ชื่อ TargetPointAOut<เลข> ในแมพ
func _exit_route() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in exit_points:
		if n != null:
			out.append(n)
	if out.size() > 0:
		return out
	var re := RegEx.create_from_string("^TargetPointAOut\\d+$")
	for child in get_tree().current_scene.get_children():
		if child is Marker3D and re.search(str(child.name)) != null:
			out.append(child)
	out.sort_custom(func(a: Node3D, b: Node3D): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out

# ---------- ตัวช่วย ----------
# แสดงบทพูดทีละบรรทัด เปลี่ยนเองตามเวลา
func _say_lines(lines: Array) -> void:
	for line in lines:
		DialogueUi.show_dialogue(line[0], line[1])
		await get_tree().create_timer(maxf(2.5, str(line[1]).length() * 0.09)).timeout
	DialogueUi.hide_dialogue()

# ผู้เล่นตัวจริงมีฟังก์ชัน set_can_move (ในกลุ่ม Player มีโหนดอื่นปนอยู่ด้วย)
func _find_player() -> Node3D:
	for n in get_tree().get_nodes_in_group("Player"):
		if n is Node3D and n.has_method("set_can_move"):
			return n
	return null

func _set_player_can_move(value: bool) -> void:
	var pl := _find_player()
	if pl:
		pl.set_can_move(value)

func _play_anim(anim_name: String) -> void:
	if _anim and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.2)
