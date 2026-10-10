extends Area3D
# เครื่องตอกบัตร (แบบโซนตรวจจับ)
# วาง Area3D + CollisionShape3D ไว้ "หน้าเครื่อง" ตรงที่ผู้เล่นยืนกด
# ผู้เล่นเดินเข้าโซน -> ขึ้นป้าย [E] -> กด E -> เล่นมินิเกม -> งาน task_id เสร็จ

## งานที่เครื่องนี้ทำให้เสร็จ (ชื่อต้องตรงกับใน DAY_PLAN ของ StoryManager)
@export var task_id: String = "clock_in"
## ต้องทำงานนี้ให้เสร็จก่อนถึงจะใช้เครื่องได้ (เว้นว่าง = ใช้ได้เลย)
@export var after_task_id: String = "talk_manager"
@export var success_text: String = "Click! Your clock-in has been recorded."
@export var not_ready_text: String = "I haven't talked to the manager yet. I should get my instructions first."

@export_group("ป้าย [E]")
@export var label_text: String = "[E] Clock in"
## ตำแหน่งป้ายเทียบกับโซน (ยกขึ้นกี่เมตร)
@export var label_offset: Vector3 = Vector3(0, 0.6, 0)

@export_group("มินิเกม")
## ปิดไว้ = กด E แล้วตอกบัตรผ่านเลย (ไว้ทดสอบ)
@export var use_minigame: bool = true
## จำนวนตัวอักษรที่ต้องกดให้ครบ
@export var minigame_length: int = 5
## เวลาต่อ 1 ตัวอักษร (วินาที) ยิ่งน้อยยิ่งยาก
@export var minigame_time_per_key: float = 2.5

var _player_in_range: bool = false
var _busy: bool = false
var _label: Label3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	StoryManager.task_done.connect(_on_task_done)
	_make_label()
	_refresh_label()

# สร้างป้าย [E] ด้วยโค้ด ไม่ต้องเพิ่มโหนดเอง
func _make_label() -> void:
	_label = Label3D.new()
	_label.text = label_text
	_label.font_size = 48
	_label.pixel_size = 0.004
	_label.outline_size = 12
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = label_offset
	_label.visible = false
	add_child(_label)

func _refresh_label() -> void:
	if _label:
		_label.visible = _player_in_range and not _busy and StoryManager.is_task_pending(task_id)

func _on_task_done(_id: String) -> void:
	_refresh_label()

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("Player"):
		_player_in_range = true
		_refresh_label()

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("Player"):
		_player_in_range = false
		_refresh_label()

func _can_use() -> bool:
	if not StoryManager.is_task_pending(task_id):
		return false
	return after_task_id == "" or not StoryManager.is_task_pending(after_task_id)

func _unhandled_input(event: InputEvent) -> void:
	if not (_player_in_range and not _busy and event.is_action_pressed("interact")):
		return
	if not StoryManager.is_task_pending(task_id):
		return   # ตอกไปแล้ว
	if DialogueUi.panel.visible:
		return   # มีบทสนทนาอื่นเปิดอยู่
	_start_clock_in()

func _start_clock_in() -> void:
	_busy = true
	_refresh_label()

	if _can_use():
		var passed: bool = true
		if use_minigame:
			passed = await _play_minigame()
		if passed:
			await _say("Time Clock", success_text)
			StoryManager.complete_task(task_id)
	else:
		await _say("Big Judy", not_ready_text)

	_busy = false
	_refresh_label()

func _say(speaker: String, text: String) -> void:
	DialogueUi.show_dialogue(speaker, text)
	await get_tree().create_timer(2.5).timeout
	DialogueUi.hide_dialogue()

func _set_player_can_move(value: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("set_can_move"):
		player.set_can_move(value)

func _play_minigame() -> bool:
	_set_player_can_move(false)
	var game := ClockInGame.new()
	game.length = minigame_length
	game.time_per_key = minigame_time_per_key
	get_tree().current_scene.add_child(game)
	var success: bool = await game.finished
	_set_player_can_move(true)
	return success

# ==========================================
# มินิเกม: กดตามตัวอักษรที่สุ่มขึ้นบนหน้าจอ
# สร้างหน้าจอด้วยโค้ดทั้งหมด ไม่ต้องทำ Scene เพิ่ม
# ==========================================
class ClockInGame extends CanvasLayer:
	signal finished(success: bool)

	const HINT := "Press the keys shown on screen"

	var length: int = 5
	var time_per_key: float = 2.5
	# ไม่ใส่ตัว E เพราะเป็นปุ่มโต้ตอบของเกม
	var letters: String = "QWRTYUIOPASDFGHJKLZXCVBNM"

	var _sequence: Array[String] = []
	var _index: int = 0
	var _time_left: float = 0.0
	var _done: bool = false

	var _letter_label: Label
	var _progress_label: Label
	var _hint_label: Label
	var _bar: ProgressBar

	func _ready() -> void:
		layer = 90   # ต่ำกว่า SceneTransition (100) แต่อยู่เหนือ UI อื่น

		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.65)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(560, 360)
		center.add_child(panel)

		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 24)
		panel.add_child(margin)

		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 12)
		margin.add_child(box)

		var title := _make_label("Clock In", 30)
		_hint_label = _make_label(HINT, 20)
		_letter_label = _make_label("", 110)
		_progress_label = _make_label("", 26)
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(0, 18)

		for n in [title, _hint_label, _letter_label, _progress_label, _bar]:
			box.add_child(n)

		_start_sequence()

	func _make_label(text: String, size: int) -> Label:
		var l := Label.new()
		l.text = text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", size)
		return l

	func _start_sequence() -> void:
		_sequence.clear()
		var prev := ""
		for i in length:
			var c := prev
			while c == prev:   # ไม่ให้ตัวอักษรซ้ำกันติดกัน
				c = letters[randi() % letters.length()]
			_sequence.append(c)
			prev = c
		_index = 0
		_show_current()

	func _show_current() -> void:
		_letter_label.text = _sequence[_index]
		_time_left = time_per_key
		_bar.max_value = time_per_key
		_bar.value = time_per_key
		var dots: Array[String] = []
		for i in length:
			dots.append("#" if i < _index else "-")
		_progress_label.text = " ".join(dots)

	func _process(delta: float) -> void:
		if _done:
			return
		_time_left -= delta
		_bar.value = maxf(_time_left, 0.0)
		if _time_left <= 0.0:
			_flash(Color(1, 0.35, 0.35))
			_start_sequence()
			_hint_label.text = "Time's up! Try again"

	func _input(event: InputEvent) -> void:
		if _done:
			return
		if not (event is InputEventKey and event.pressed and not event.echo):
			return
		# physical_keycode = ตำแหน่งปุ่มจริงบนคีย์บอร์ด ใช้ได้แม้เปิดแป้นพิมพ์ภาษาไทยอยู่
		var code: int = event.physical_keycode
		if code < KEY_A or code > KEY_Z:
			return
		get_viewport().set_input_as_handled()

		if code == _sequence[_index].unicode_at(0):
			_index += 1
			_hint_label.text = HINT
			_flash(Color(0.4, 1, 0.4))
			if _index >= length:
				_finish()
			else:
				_show_current()
		else:
			_flash(Color(1, 0.35, 0.35))

	func _flash(color: Color) -> void:
		_letter_label.modulate = color
		var tw := create_tween()
		tw.tween_property(_letter_label, "modulate", Color.WHITE, 0.25)

	func _finish() -> void:
		_done = true
		_letter_label.text = "OK"
		_letter_label.modulate = Color(0.4, 1, 0.4)
		_hint_label.text = "Success!"
		await get_tree().create_timer(0.7).timeout
		finished.emit(true)
		queue_free()
