extends Control
# หน้าเริ่มเกม: ปุ่ม "เล่น" ไปที่ Map 2 และปุ่ม "เครดิต"
# สร้างหน้าจอด้วยโค้ดทั้งหมด แค่แปะสคริปต์นี้ที่โหนด Control ราก (ใช้ main_menu.tscn ได้เลย)
# ใช้ฟอนต์ตามที่ตั้งไว้ใน Project Settings (GUI > Theme > Custom Font) อัตโนมัติ

## ฉากที่จะไปเมื่อกดเล่น
@export_file("*.tscn") var play_scene: String = "res://แมพ/Map_2.tscn"

@export_group("ข้อความ")
@export var game_title: String = "Your Game Title"
@export var subtitle: String = "Night Shift"
@export var play_text: String = "Play"
@export var credits_text_button: String = "Credits"
@export var back_text: String = "Back"

@export_group("พื้นหลัง")
## ลากรูปมาใส่ได้ (ไม่ใส่ = พื้นหลังสีเข้ม)
@export var background: Texture2D
@export var background_color: Color = Color(0.04, 0.04, 0.07)
## ติ๊กถ้าหลังเมนูเป็นฉาก 3 มิติ (ไม่สร้างพื้นหลังทึบทับฉาก)
@export var transparent_background: bool = false
## ความมืดทับรูปพื้นหลัง (0 = ไม่ทับ) ช่วยให้ตัวหนังสืออ่านง่าย
@export_range(0.0, 1.0) var background_dim: float = 0.45

@export_group("เครดิต")
@export var credits_title: String = "Credits"
@export_multiline var credits_body: String = "Developers\nYour Name\n\nSound\nSound source name\n\nModels and scenes\nModel source name\n\nThanks for playing!"

@export_group("เสียง (ไม่ใส่ก็ได้)")
@export var snd_click: AudioStream
@export var music: AudioStream

var _play_button: Button
var _credits_button: Button
var _credits_layer: Control
var _starting: bool = false

func _ready() -> void:
	# ผู้เล่นในแมพล็อกเมาส์ไว้ เมนูต้องเห็นเมาส์
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	_build_credits()
	_play_button.grab_focus()
	if music:
		var m := AudioStreamPlayer.new()
		m.stream = music
		add_child(m)
		m.play()

func _build_background() -> void:
	if transparent_background:
		return
	if background:
		var tex := TextureRect.new()
		tex.texture = background
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tex)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, background_dim)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
	else:
		var bg := ColorRect.new()
		bg.color = background_color
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = game_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(title)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 28)
		sub.modulate = Color(1, 1, 1, 0.7)
		box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)

	_play_button = _make_button(play_text)
	_play_button.pressed.connect(_on_play_pressed)
	box.add_child(_play_button)

	_credits_button = _make_button(credits_text_button)
	_credits_button.pressed.connect(_on_credits_pressed)
	box.add_child(_credits_button)

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 60)
	b.add_theme_font_size_override("font_size", 30)
	return b

func _build_credits() -> void:
	_credits_layer = Control.new()
	_credits_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_layer.visible = false
	add_child(_credits_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title := Label.new()
	title.text = credits_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	var body := Label.new()
	body.text = credits_body
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 0)
	body.add_theme_font_size_override("font_size", 24)
	box.add_child(body)

	var back := _make_button(back_text)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)

func _unhandled_input(event: InputEvent) -> void:
	# กด Esc ปิดหน้าเครดิต
	if _credits_layer.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _click() -> void:
	if snd_click == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = snd_click
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _on_credits_pressed() -> void:
	_click()
	_credits_layer.visible = true

func _on_back_pressed() -> void:
	_click()
	_credits_layer.visible = false
	_credits_button.grab_focus()

func _on_play_pressed() -> void:
	if _starting:
		return
	_starting = true
	_click()
	_play_button.disabled = true
	_credits_button.disabled = true

	# เริ่มเกมใหม่ตั้งแต่วันที่ 1 (ล้างงานและสถานะที่เคยทำไว้)
	StoryManager.set_day(1)
	StoryManager.flags.clear()
	StoryManager.done_tasks.clear()

	if SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(play_scene)
	else:
		get_tree().change_scene_to_file(play_scene)
