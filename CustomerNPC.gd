extends CharacterBody3D

signal reached_destination

const SPEED = 1.3
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ==========================================
# ชื่อคนพูด: อยากเปลี่ยนชื่อ แก้ตรงนี้ที่เดียว บทด้านล่างจะเปลี่ยนตามทั้งหมด
# ==========================================
const MANAGER_BEFORE := "Manager"   # ชื่อที่โชว์ก่อนเขาแนะนำตัว
const MANAGER := "Vanes"              # ชื่อหลังแนะนำตัวแล้ว
const HERO := "Big Judy"              # ชื่อตัวเอกหลังบอกชื่อแล้ว

# ชื่องาน (ต้องตรงกับใน DAY_PLAN ของ StoryManager) คุยตามลำดับงานที่ค้างอยู่
const TASK_TALK := "talk_manager"          # คุยแนะนำงานครั้งแรก
const TASK_LEAVE := "talk_manager_leave"   # คุยเล่นแล้ววาเนสขอตัวกลับ

@export var target_day: int = 1
@export var prompt_message: String = "Press [E] to Talk"

## คุยบทหลักจบแล้ว แต่ยังมีงานอื่นค้าง ถ้าผู้เล่นกดคุยอีกจะพูดประโยคนี้
## (ถ้าคลิกโหนดใน Inspector แล้วช่องนี้ไม่ใช่ "วาเนส" ให้พิมพ์แก้ตรงนั้นด้วย ค่าใน Inspector ชนะค่าในสคริปต์)
@export var reminder_speaker: String = MANAGER
@export_multiline var reminder_text: String = "Go clock in at the back of the store first, then come start your shift."

## คุยจบแล้วให้ NPC เดินตาม route_points หรือไม่
@export var walk_route_after_talk: bool = false

# จุดหมายเดียวที่ NPC จะเดินไป
# ลาก Marker3D / Node3D จุดปลายทางมาใส่ช่องนี้ใน Inspector ได้เลย
@export var walk_target: Node3D

# ระบบเดิมสำหรับกรณีที่ต้องการให้เดินหลายจุด
@export var route_points: Array[Node3D] = []

## เปิด = เดินตามจุดที่กำหนดตรงๆ (ไม่พึ่ง navmesh)
## ปิด = ให้ NPC หาทางเองด้วย navmesh
@export var follow_markers_directly: bool = true

@export_group("ตอนวาเนสกลับบ้าน")
## ลาก Marker3D เรียงตามเส้นทางที่วาเนสเดินไปที่รถ (จุดสุดท้ายอยู่ข้างประตูรถ)
@export var leave_route_points: Array[Node3D] = []
## รถที่วาเนสจะขึ้น (โหนดที่แปะสคริปต์ Car.gd)
@export var car: Node3D

# ==========================================
# บทสนทนาหลัก: แต่ละบรรทัด = [ชื่อคนพูด, ข้อความ]
# กด E เพื่อไปบรรทัดถัดไป แก้/เพิ่ม/ลบบรรทัดได้ที่นี่เลย
# ==========================================
var talk_lines: Array = [
	[MANAGER_BEFORE, "Well, well, well! You finally made it, rookie. Even if you're only five minutes late, I'm not letting it slide."],
	[HERO, "Uh, uh, I'm really sorry, sir. There was an accident on the way here. I honestly didn't mean to be late, Manager."],
	[MANAGER_BEFORE, "And how am I supposed to know..."],
	[MANAGER_BEFORE, "...that what you're saying is true, rookie?"],
	[MANAGER_BEFORE, "Because if it is... then you're a very lucky man."],
	[HERO, "Huh? What do you mean, Manager?"],
	[MANAGER_BEFORE, "Check the time."],
	[HERO, "Wait... are you messing with me?"],
	[MANAGER_BEFORE, "Hahaha! Sorry, sorry, I'm just joking around."],
	[MANAGER_BEFORE, "It's not often someone actually wants to work the night shift at this station."],
	[MANAGER_BEFORE, "So I couldn't help myself. You should have seen your face."],
	[MANAGER_BEFORE, "It was just too funny, haha. Ah, sorry, sorry."],
	[HERO, "I'm not laughing, sir!!!"],
	[MANAGER_BEFORE, ". . . . Okay, okay, I said I was sorry. Welcome to the long, long night shift."],
	[HERO, "Yes, sir."],
	[MANAGER_BEFORE, "Oh, relax. You're actually ten minutes early. Good. I'll show you the ropes for a bit."],
	[MANAGER_BEFORE, "There's not much to the job. Just work until 5 a.m., then close up and head home."],
	[MANAGER_BEFORE, "Someone else will come in at 8 to take over."],
	[MANAGER_BEFORE, "Oh, I haven't even introduced myself. I'm Vanes. And you, rookie? I'm guessing you don't want me calling you 'rookie' forever, right?"],
	[HERO, "Oh, it's Big Judy, Mr. Vanes."],
	[HERO, "So... what do I need to do?"],
	[MANAGER, "First things first. Do you know how to ring up customers?"],
	[HERO, "Yes, sir. I used to work at a department store, so I know the basics, Mr. Vanes."],
	[MANAGER, "Perfect. That'll make training you a lot faster."],
	[MANAGER, "Greet customers, ring up purchases, restock the shelves, mop the floor if it gets dirty, take the trash from the coffee station out to the bin next to the restrooms, and turn off the store lights at closing."],
	[MANAGER, "Got all that, Big Judy?"],
	[HERO, "Got it."],
	[MANAGER, "Alright, go clock in now. You'll be late otherwise."],
	[HERO, "Why are you only telling me this now?"],
]

# ==========================================
# บทสนทนาครั้งที่ 2: หลังตอกบัตรแล้วกลับมาคุยเล่น แล้ววาเนสขอตัวกลับ
# (ผมเขียนตัวอย่างไว้ให้ แก้เป็นบทของคุณได้เลย)
# ==========================================
var leave_lines: Array = [
	[HERO, "I'm clocked in, Mr. Vanes."],
	[MANAGER, "Good! Right on time. No pay cut for you. Haha!"],
	[HERO, "Please stop messing with me, Mr. Vanes."],
	[MANAGER, "Haha, sorry, sorry. So how is it? Is the place bigger than you expected?"],
	[HERO, "Well... it's quieter than I expected. But I think I can handle it."],
	[MANAGER, "Quiet is good. For night-shift folks like us, if nothing happens at all, that's the best luck you can ask for."],
	[MANAGER, "Alright, I should head home. I've been here since morning and I'm about to fall over."],
	[HERO, "Oh, you're leaving already, Mr. Vanes?"],
	[MANAGER, "Yep. I'll leave the rest to you. Just do what I told you."],
	[HERO, "Yes, sir. Drive safe."],
	[MANAGER, "See you. Work hard."],
	[MANAGER, ". . . ."],
	[MANAGER, "Be careful out here at night, though."],
	[MANAGER, "Strange things have been happening lately. I heard there was something like a murder not long ago."],
	[MANAGER, "Anyway, I'm off! Good luck, Big Judy. Hahaha!"],
	[HERO, "Mr. Vanes, come on, don't scare me like that!"],
]

# งาน -> บทสนทนาของงานนั้น (สร้างใน _ready)
var conversations: Dictionary = {}

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $Character_Female_03/AnimationPlayer

var is_dialoguing: bool = false
var is_moving: bool = false
var current_path_queue: Array[Vector3] = []

var _current_lines: Array = []
var _line_index: int = 0
var _current_task: String = ""

# เก็บ Marker ตัวสุดท้าย เพื่อเอาองศาการหันหน้าตอนเดินถึงเป้าหมาย
var final_target_marker: Node3D = null

# เดินตรงๆ: จุดที่กำลังเดินไปหา และระยะที่ถือว่า "ถึงแล้ว"
var _direct_target: Vector3 = Vector3.ZERO
var _route_total: int = 0
var _route_done: int = 0

# กันค้าง: ถ้าเดินไม่ไปไหน จะปิดการชนชั่วคราวให้เดินทะลุสิ่งกีดขวางสั้นๆ แล้วเปิดกลับ
const STUCK_SECONDS := 1.2        # เดินไม่ไปไหนนานเท่านี้ถือว่าค้าง
const GHOST_DISTANCE := 2.0       # ทะลุสิ่งกีดขวางไปไกลเท่านี้แล้วเปิดการชนกลับ
var _stuck_time: float = 0.0
var _ghost: bool = false
var _ghost_start: Vector3 = Vector3.ZERO
var _orig_mask: int = 1
const ARRIVE_DISTANCE := 0.4

func _ready() -> void:
	_orig_mask = collision_mask
	conversations = {TASK_TALK: talk_lines, TASK_LEAVE: leave_lines}

	# วาเนสกลับบ้านไปแล้ว (เช่นกลับเข้าแมพมาใหม่) ไม่ต้องอยู่ในฉาก
	if StoryManager.is_task_done(TASK_LEAVE):
		hide_for_cutscene()
		return

	nav_agent.target_desired_distance = 0.8
	nav_agent.path_desired_distance = 0.8
	await get_tree().physics_frame

	if StoryManager.current_day != target_day:
		visible = false
		set_physics_process(false)
	else:
		visible = true
		set_physics_process(true)
		_play_anim("Idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor() and not _ghost:
		velocity.y -= gravity * delta

	if not is_moving:
		_play_anim("Idle")
		move_and_slide()
		return

	# เลือกจุดที่จะเดินไปหา
	var move_target: Vector3
	if follow_markers_directly:
		var flat := _direct_target - global_position
		flat.y = 0.0
		if flat.length() < ARRIVE_DISTANCE:
			_route_done += 1
			print("[NPC] ถึงจุดที่ ", _route_done, " / ", _route_total)
			if current_path_queue.size() > 0:
				_direct_target = current_path_queue.pop_front()
			else:
				_finish_route()
				return
		move_target = _direct_target
	else:
		if nav_agent.is_navigation_finished():
			if current_path_queue.size() > 0:
				nav_agent.target_position = current_path_queue.pop_front()
			else:
				_finish_route()
				return
		move_target = nav_agent.get_next_path_position()

	var dir: Vector3 = move_target - global_position
	dir.y = 0
	var want_move := dir.length() > 0.01

	if want_move:
		dir = dir.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		_play_anim("Walking")

		# ค่อยๆ หันหน้าไปตามทิศทางที่กำลังเดิน
		var target_angle = atan2(-dir.x, -dir.z)
		rotation.y = rotate_toward(rotation.y, target_angle, 6.0 * delta)

		rotation.x = 0
		rotation.z = 0
	else:
		velocity.x = 0
		velocity.z = 0
		_play_anim("Idle")

	if _ghost:
		velocity.y = 0.0   # ระหว่างทะลุสิ่งกีดขวาง ไม่ให้ตกหรือลอย

	move_and_slide()

	if follow_markers_directly:
		_update_stuck(delta, want_move)

# ตรวจว่าค้างหรือเปล่า ถ้าค้างให้ทะลุสิ่งกีดขวางสั้นๆ
func _update_stuck(delta: float, want_move: bool) -> void:
	if _ghost:
		if global_position.distance_to(_ghost_start) > GHOST_DISTANCE:
			_end_ghost()
		return

	if not want_move:
		_stuck_time = 0.0
		return

	var real := get_real_velocity()
	var horizontal_speed := Vector2(real.x, real.z).length()
	if horizontal_speed < SPEED * 0.25:
		_stuck_time += delta
		if _stuck_time > STUCK_SECONDS:
			_ghost = true
			_ghost_start = global_position
			collision_mask = 0
			print("[NPC] ติดขัดระหว่างทางไปจุดที่ ", _route_done + 1, " → เดินทะลุสิ่งกีดขวาง")
	else:
		_stuck_time = 0.0

func _end_ghost() -> void:
	_ghost = false
	_stuck_time = 0.0
	collision_mask = _orig_mask

# เดินถึงจุดสุดท้ายแล้ว
func _finish_route() -> void:
	if _ghost:
		_end_ghost()
	is_moving = false
	velocity.x = 0
	velocity.z = 0
	_play_anim("Idle")
	print("เดินถึงจุดหมายปลายทางเรียบร้อย!")

	# หันหน้าตามทิศทางแกน Z ของ Marker3D ตัวสุดท้าย
	if final_target_marker:
		var forward_dir = final_target_marker.global_transform.basis.z
		forward_dir.y = 0
		if forward_dir.length_squared() > 0.001:
			# ปรับสลับเครื่องหมาย +/- ตรงนี้ได้ ถ้าตัวละครหันผิดด้านหลัง
			var target_angle = atan2(forward_dir.x, forward_dir.z)
			rotation.y = target_angle

	reached_destination.emit()

func start_route(points: Array[Node3D]) -> void:
	current_path_queue.clear()
	final_target_marker = null

	for p in points:
		if p:
			current_path_queue.append(p.global_position)

	if current_path_queue.size() > 0:
		# บันทึก Marker ตัวสุดท้ายไว้ใช้หันหน้าตอนเดินถึง
		final_target_marker = points[points.size() - 1]
		_route_total = current_path_queue.size()
		_route_done = 0

		var first: Vector3 = current_path_queue.pop_front()
		if follow_markers_directly:
			_direct_target = first
		else:
			nav_agent.target_position = first
		is_moving = true
		print("--- เริ่มออกเดินทางตาม Route ---")

func interact() -> void:
	# ถ้ากำลังเดินอยู่ ห้ามคุย
	if is_moving:
		return

	# กำลังคุยอยู่: กด E = ข้ามตัวพิมพ์ หรือไปบรรทัดถัดไป
	if is_dialoguing:
		if DialogueUi.is_typing:
			DialogueUi.finish_typing()
			return
		_line_index += 1
		if _line_index < _current_lines.size():
			_show_line()
		else:
			_end_dialogue()
		return

	# มีบทสนทนาอื่นเปิดอยู่ (เช่นบทตอนมาถึงปั๊ม) ห้ามคุยซ้อน
	if DialogueUi.panel.visible:
		return
	if StoryManager.current_day != target_day:
		return

	# คุยตามลำดับงาน: ดูงานแรกที่ยังค้างอยู่ ถ้ามีบทสนทนาของงานนั้นก็คุยบทนั้น
	var task: String = StoryManager.current_task()
	if conversations.has(task):
		_current_lines = conversations[task]
		_current_task = task
	elif task != "" and reminder_text != "":
		_current_lines = [[reminder_speaker, reminder_text]]
		_current_task = ""
	else:
		return   # ไม่มีอะไรต้องคุยแล้ว

	_line_index = 0
	is_dialoguing = true
	_show_line()

func _show_line() -> void:
	var line: Array = _current_lines[_line_index]
	DialogueUi.show_dialogue(line[0], line[1])

func _end_dialogue() -> void:
	DialogueUi.hide_dialogue()
	is_dialoguing = false
	if _current_task != "":
		var finished_task := _current_task
		_current_task = ""
		StoryManager.complete_task(finished_task)
		if finished_task == TASK_LEAVE:
			_leave_sequence()
		elif walk_route_after_talk:
			if walk_target:
				var one: Array[Node3D] = [walk_target]
				start_route(one)
			elif route_points.size() > 0:
				start_route(route_points)

# วาเนสเดินไปที่รถ แล้วขึ้นรถ (รถจะสตาร์ทและขับออกไปเอง)
func _leave_sequence() -> void:
	var path: Array[Node3D] = _find_leave_path()
	print("[วาเนส] เดินไปที่รถ ใช้ ", path.size(), " จุด")
	if path.size() > 0:
		start_route(path)
		await reached_destination
	else:
		push_warning("วาเนสไม่มีจุดให้เดินไปรถ (ตั้ง Leave Route Points หรือวาง Marker3D ชื่อ TargetPoint1, 2, 3...)")

	# ถ้าไม่ได้ลากรถใส่ช่อง Car จะหาโหนดชื่อ CarA ในแมพให้เอง
	var the_car: Node = car if car else get_parent().get_node_or_null("CarA")
	if the_car and the_car.has_method("board_and_depart"):
		await the_car.board_and_depart(self)
	else:
		hide_for_cutscene()

# หาจุดเดินไปตามลำดับความสำคัญ:
# 1) Leave Route Points
# 2) Walk Target (จุดเดียว)
# 3) Route Points
# 4) Marker3D ชื่อ TargetPoint1, 2, 3... (ชื่อลงท้ายด้วยตัวเลขล้วน ไม่รวม TargetPointA1, TargetPointB1, TargetPointCar...)
func _find_leave_path() -> Array[Node3D]:
	var path: Array[Node3D] = []

	if leave_route_points.size() > 0:
		for n in leave_route_points:
			if n != null:
				path.append(n)
		return path

	if walk_target:
		path.append(walk_target)
		return path

	var source: Array[Node3D] = route_points
	for n in source:
		if n != null:
			path.append(n)
	if path.size() > 0:
		return path

	var re := RegEx.create_from_string("^TargetPoint\\d+$")
	for child in get_parent().get_children():
		if child is Marker3D and re.search(str(child.name)) != null:
			path.append(child)
	path.sort_custom(func(a: Node3D, b: Node3D): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return path

# หายจากฉาก (ขึ้นรถไปแล้ว)
func hide_for_cutscene() -> void:
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

func _play_anim(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)
