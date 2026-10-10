extends Node3D
# ภารกิจสำรวจรอบร้าน (วันที่ 1 หลังรถลูกค้า B ออกไปแล้ว)
# - จูดี้พูดว่าคนที่นี่แปลกๆ แล้วออกไปเดินสำรวจ
# - ระบบชี้ทีละจุด (มีป้ายลอย + ข้อความมุมซ้ายบน) เดินไปที่จุดแล้วกด E -> สำรวจสักครู่ -> จูดี้พูดความเห็นของจุดนั้น
# - ครบ 6 จุด -> จูดี้สรุป -> งาน "explore" เสร็จ
#
# วิธีวาง: ลากฉาก explore_task.tscn ไปไว้ใน Map_1 แล้วเปิด Editable Children (คลิกขวา)
#   Point1 .. Point6 = จุดที่ผู้เล่นยืนสำรวจ (สำรวจตามลำดับเลข) ย้ายไปไว้ตามจุดที่ต้องการ

const HERO := "Big Judy"

## ชื่องาน (ต้องตรงกับใน DAY_PLAN ของ StoryManager)
@export var task_id: String = "explore"
## งานที่ต้องเสร็จก่อนภารกิจนี้จะเริ่ม (รถลูกค้า B ออกไปแล้ว)
@export var after_task_id: String = "customer_b"
## หน่วงกี่วินาทีหลังงานก่อนหน้าจบ ก่อนจูดี้เริ่มพูด
@export var start_delay: float = 1.5

@export_group("ชื่อจุดที่ขึ้นบนหน้าจอ (เรียงตาม Point1, Point2, ...)")
## เช่น ["ประตูหลังร้าน", "หน้าห้องน้ำ"] เว้นว่าง = ใช้ "จุดสำรวจที่ N"
@export var point_labels: PackedStringArray = []

@export_group("การสำรวจ")
## ยืนใกล้จุดกี่เมตรถึงจะกด E ได้
@export var interact_radius: float = 1.8
## ใช้เวลาสำรวจกี่วินาทีหลังกด E (ผู้เล่นขยับไม่ได้ระหว่างนี้)
@export var explore_time: float = 1.6

@export_group("เสียง (ลากไฟล์เสียงมาใส่ ไม่ใส่ก็ได้)")
## เสียงตอนเริ่มสำรวจ
@export var snd_explore: AudioStream
## เสียงตอนสำรวจเสร็จแต่ละจุด
@export var snd_done: AudioStream

@export_group("ป้ายลอย")
@export var hint_height: float = 1.8
@export var hint_through_walls: bool = true

# ==========================================
# บทพูดตอนเริ่ม และตอนสรุป: [ชื่อ, ข้อความ] เปลี่ยนบรรทัดเองตามเวลา (แก้ได้เลย)
# ==========================================
var intro_lines: Array = [
	[HERO, "Hey, is everyone around here just weird?"],
	[HERO, "If someone in a jumpsuit walks in to buy something next time, I won't even be surprised."],
	[HERO, "I'll take a walk around the store first. It doesn't hurt to scout the escape routes."],
]

var outro_lines: Array = [
	[HERO, "With my fast feet and the power of this stick, anyone who comes at me is in for it."],
	[HERO, "Better get back inside..."],
]

# ==========================================
# บทพูดหลังสำรวจเสร็จแต่ละจุด (ลำดับตรงกับ Point1..6): [[ชื่อ, ข้อความ], ...] ต่อจุด
# ตัวอย่างเขียนไว้ให้ ปรับให้ตรงกับตำแหน่งที่คุณวางจริง
# ==========================================
var point_lines: Array = [
	[[HERO, "Whoa. If I ran into this forest, I'd probably never find my way out. Let's keep that as a last resort."]],
	[[HERO, "Seriously? I'd freeze to death first."]],
	[[HERO, "But if I ever had to fight the killer, I could blast him with the fuel hose, pew pew, and the ground would get slippery. I might actually get away. Born smart, what can I say."]],
	[[HERO, "Ew, just the thought of hiding in here... it already stinks."]],
	[[HERO, "Let's see what's over here."]],
	[[HERO, "Huh, this stick fits my hand perfectly."]],
]

var _active: bool = false
var _busy: bool = false
var _started: bool = false
var _count: int = 0
var _points: Array[Node3D] = []
var _player: Node3D

var _objective: Label
var _prompt: Label
var _hint: Label3D
var _bar_layer: CanvasLayer
var _bar: ProgressBar

func _ready() -> void:
	_collect_points()
	if _points.is_empty():
		push_warning("ExploreTask: ต้องมี Marker3D ชื่อ Point1, Point2, ... เป็นลูกของโหนดนี้")
		set_process(false)
		set_process_input(false)
		return
	_build_hud()
	_build_hint()

	# Map_1 เรียก StoryManager.begin_map() ใน _ready ของตัวเอง ซึ่งรันหลังลูกๆ จึงต้องรอ 1 เฟรม
	await get_tree().process_frame

	_count = int(StoryManager.flags.get(_count_key(), 0))

	if not StoryManager.is_task_pending(task_id):
		set_process(false)
		set_process_input(false)
		return

	if StoryManager.is_task_done(after_task_id):
		_begin(StoryManager.has_flag(_intro_key()))
	else:
		StoryManager.task_done.connect(_on_task_done)

func _collect_points() -> void:
	_points.clear()
	for c in get_children():
		if c is Marker3D and str(c.name).begins_with("Point"):
			_points.append(c as Node3D)
	_points.sort_custom(func(a: Node3D, b: Node3D): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)

func _on_task_done(id: String) -> void:
	if id == after_task_id:
		_begin(false)

func _begin(skip_intro: bool) -> void:
	if _started:
		return
	_started = true
	if not skip_intro:
		StoryManager.set_flag(_intro_key())
		await get_tree().create_timer(start_delay).timeout
		await _say_lines(intro_lines)
	_active = true
	_refresh_objective()

# ---------- ตัวช่วย ----------
func _count_key() -> String:
	return "explore_count_%d" % StoryManager.current_day

func _intro_key() -> String:
	return "explore_intro_%d" % StoryManager.current_day

func _target() -> Node3D:
	return _points[mini(_count, _points.size() - 1)]

func _point_name(i: int) -> String:
	if i < point_labels.size() and point_labels[i] != "":
		return point_labels[i]
	return "Scout point %d" % (i + 1)

func _near(p: Node3D) -> bool:
	if p == null:
		return false
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return false
	var d := _player.global_position - p.global_position
	return Vector2(d.x, d.z).length() <= interact_radius and absf(d.y) < 3.0

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

func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# แสดงบทพูดทีละบรรทัด เปลี่ยนเองตามเวลา
func _say_lines(lines: Array) -> void:
	for line in lines:
		DialogueUi.show_dialogue(line[0], line[1])
		await get_tree().create_timer(maxf(2.5, str(line[1]).length() * 0.09)).timeout
	DialogueUi.hide_dialogue()

# ---------- HUD ----------
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)

	_objective = Label.new()
	_objective.position = Vector2(24, 24)
	_objective.add_theme_font_size_override("font_size", 22)
	_objective.add_theme_constant_override("outline_size", 8)
	_objective.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective.visible = false
	layer.add_child(_objective)

	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.75
	_prompt.anchor_bottom = 0.75
	_prompt.offset_left = -350
	_prompt.offset_right = 350
	_prompt.offset_top = -20
	_prompt.offset_bottom = 20
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 26)
	_prompt.add_theme_constant_override("outline_size", 10)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.visible = false
	layer.add_child(_prompt)

	# แถบความคืบหน้าตอนกำลังสำรวจ
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 41
	_bar_layer.visible = false
	add_child(_bar_layer)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.6
	box.anchor_bottom = 0.6
	box.offset_left = -200
	box.offset_right = 200
	box.add_theme_constant_override("separation", 8)
	_bar_layer.add_child(box)
	var title := Label.new()
	title.text = "Scouting..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(title)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 18)
	box.add_child(_bar)

func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.font_size = 64
	_hint.pixel_size = 0.005
	_hint.outline_size = 14
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.no_depth_test = hint_through_walls
	_hint.modulate = Color(1.0, 0.9, 0.3)
	_hint.visible = false
	_hint.top_level = true   # ไม่ให้ป้ายยืดตามสเกลของโหนดแม่
	add_child(_hint)

func _refresh_objective() -> void:
	if not _active:
		_objective.visible = false
		return
	_objective.text = "Task: Scout around the store (%d/%d)\nGo to: %s (follow the yellow marker)" % [_count, _points.size(), _point_name(_count)]
	_objective.visible = true

func _process(_delta: float) -> void:
	if not _active or _busy:
		_prompt.visible = false
		_hint.visible = false
		return

	var target := _target()
	_hint.text = "Scout here\n%s\nV" % _point_name(_count)
	_hint.global_position = target.global_position + Vector3(0, hint_height, 0)
	_hint.visible = true

	_prompt.text = "[E] Scout" if _near(target) else ""
	_prompt.visible = _prompt.text != "" and not DialogueUi.panel.visible

# ---------- รับปุ่ม ----------
func _input(event: InputEvent) -> void:
	if not _active or _busy or not event.is_action_pressed("interact", false):
		return
	if DialogueUi.panel.visible:
		return
	if _near(_target()):
		get_viewport().set_input_as_handled()
		_explore()

func _explore() -> void:
	_busy = true
	_set_player_can_move(false)
	_play(snd_explore)

	# กำลังสำรวจ: แถบเต็มตามเวลา
	_bar.value = 0.0
	_bar_layer.visible = true
	var tw := create_tween()
	tw.tween_property(_bar, "value", 1.0, explore_time)
	await tw.finished
	_bar_layer.visible = false
	_play(snd_done)

	# สำรวจเสร็จ จูดี้พูดความเห็นของจุดนี้
	var idx := mini(_count, point_lines.size() - 1)
	if idx >= 0 and point_lines.size() > 0:
		await _say_lines(point_lines[idx])
	_set_player_can_move(true)

	_count += 1
	StoryManager.flags[_count_key()] = _count

	if _count >= _points.size():
		_objective.text = "All points scouted (%d/%d)" % [_count, _points.size()]
		await get_tree().create_timer(1.0).timeout
		await _say_lines(outro_lines)
		_active = false
		_objective.visible = false
		_busy = false
		StoryManager.complete_task(task_id)
		return

	_busy = false
	_refresh_objective()
