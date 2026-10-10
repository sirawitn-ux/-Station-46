extends Node

signal step_changed(step: int)
signal task_done(task_id: String)
signal tasks_completed(map_id: String)

# ===== แผนเนื้อเรื่องรายวัน: แก้เนื้อเรื่องที่นี่ที่เดียว =====
# วัน -> แมพ -> { tasks: งานที่ต้องทำให้ครบ, next_scene: ไปฉากไหนต่อ }
const DAY_PLAN := {
	1: {
		"map_2": {
			"tasks": ["take_bus"],
			"next_scene": "res://แมพ/Map_1.tscn",
		},
		"map_1": {
			"tasks": ["talk_manager", "clock_in", "talk_manager_leave", "restock", "customer_b", "explore", "customer_a", "trash"],
			"next_scene": "",
		},
	},
	2: {
		"map_2": {
			"tasks": ["take_bus"],
			"next_scene": "res://แมพ/Map_1.tscn",
		},
	},
}

var current_day: int = 1
var current_step: int = 0
var flags: Dictionary = {}
var pending_tasks: Dictionary = {}   # งานที่ยังเหลือในแมพปัจจุบัน
var done_tasks: Dictionary = {}      # งานที่ทำแล้ว คีย์ "วัน:งาน" เช่น "1:take_bus"
var _active_map: String = ""

func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value

func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func set_day(day: int) -> void:
	current_day = day
	current_step = 0
	pending_tasks.clear()
	_active_map = ""
	print("เปลี่ยนเป็นวันที่: ", current_day)

func next_step() -> void:
	current_step += 1
	print("เนื้อเรื่องขยับไปสเตป: ", current_step)
	step_changed.emit(current_step)

func get_plan(map_id: String) -> Dictionary:
	var day_plan: Dictionary = DAY_PLAN.get(current_day, {})
	return day_plan.get(map_id, {})

# แมพเรียกตอนเริ่มฉาก: โหลดงานของวันนี้ ข้ามงานที่เคยทำไปแล้ว
func begin_map(map_id: String) -> void:
	_active_map = map_id
	pending_tasks.clear()
	for id in get_plan(map_id).get("tasks", []):
		if not done_tasks.has(_key(str(id))):
			pending_tasks[str(id)] = true

func is_task_pending(id: String) -> bool:
	return pending_tasks.has(id)

# งานแรกที่ยังค้างอยู่ตามลำดับใน DAY_PLAN ("" = ไม่มีงานค้าง)
func current_task() -> String:
	if pending_tasks.is_empty():
		return ""
	return str(pending_tasks.keys()[0])

# งานนี้ของวันนี้ทำเสร็จไปแล้วหรือยัง
func is_task_done(id: String) -> bool:
	return done_tasks.has(_key(id))

# งานแต่ละอย่างเรียกตอนทำเสร็จ ครบทุกอย่างแล้วสเตปเดินต่อเอง
func complete_task(id: String) -> void:
	if not pending_tasks.has(id):
		return
	pending_tasks.erase(id)
	done_tasks[_key(id)] = true
	task_done.emit(id)
	if pending_tasks.is_empty():
		next_step()
		tasks_completed.emit(_active_map)

func _key(id: String) -> String:
	return "%d:%s" % [current_day, id]

# ==========================================
# เครื่องมือดีบั๊ก: เร่ง/หน่วงความเร็วเกม ไว้เทสเนื้อเรื่องเร็วๆ
#   +  (ปุ่ม = / + หรือ + ใน Numpad)  เร็วขึ้น
#   -  (ปุ่ม - หรือ - ใน Numpad)      ช้าลง
#   0                                 กลับเป็นความเร็วปกติ
# ทำงานเฉพาะตอนกด Play จากโปรแกรม Godot เท่านั้น (เกมที่ Export แล้วจะไม่มีผล)
# อยากลบทิ้ง: ลบตั้งแต่บรรทัดนี้ถึงท้ายไฟล์
# ==========================================
const SPEED_STEPS := [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
const NORMAL_SPEED_INDEX := 2

var _speed_index: int = NORMAL_SPEED_INDEX
var _speed_layer: CanvasLayer
var _speed_label: Label

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# physical_keycode = ตำแหน่งปุ่มจริง ใช้ได้แม้เปิดแป้นพิมพ์ภาษาไทยอยู่
	var code: int = event.physical_keycode
	if code == KEY_EQUAL or code == KEY_KP_ADD:
		_set_speed_index(_speed_index + 1)
	elif code == KEY_MINUS or code == KEY_KP_SUBTRACT:
		_set_speed_index(_speed_index - 1)
	elif code == KEY_0 or code == KEY_KP_0:
		_set_speed_index(NORMAL_SPEED_INDEX)

func _set_speed_index(i: int) -> void:
	_speed_index = clampi(i, 0, SPEED_STEPS.size() - 1)
	Engine.time_scale = SPEED_STEPS[_speed_index]
	_update_speed_label()

func _update_speed_label() -> void:
	if _speed_layer == null:
		_speed_layer = CanvasLayer.new()
		_speed_layer.layer = 110
		add_child(_speed_layer)
		_speed_label = Label.new()
		_speed_label.anchor_left = 1.0
		_speed_label.anchor_right = 1.0
		_speed_label.offset_left = -320
		_speed_label.offset_right = -20
		_speed_label.offset_top = 16
		_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_speed_label.add_theme_font_size_override("font_size", 26)
		_speed_label.add_theme_constant_override("outline_size", 8)
		_speed_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_speed_layer.add_child(_speed_label)
	var s: float = Engine.time_scale
	_speed_label.text = "Game speed ×%s  (0 = normal)" % str(s)
	_speed_layer.visible = not is_equal_approx(s, 1.0)
