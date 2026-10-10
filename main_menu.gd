extends Node3D
## Main Menu
## ลำดับ:
## 1) เล่นอนิเมชันกล้อง
## 2) ประมาณ 2 วินาที -> ชื่อเกมตึมเข้ามาพร้อมเสียง
## 3) อีก 0.5 วินาที -> ปุ่ม Play / Credits ค่อย ๆ ปรากฏ
## 4) ปุ่มจะกระพริบแบบจางเล็กน้อยเพื่อให้ยังอ่านได้ชัด

@export_file("*.tscn") var play_scene: String = "res://แมพ/Map_2.tscn"

@export_group("Animation / Timing")
@export var camera_animation: StringName = &"กล้อง"
@export var title_delay: float = 2.0
@export var buttons_delay: float = 0.5
@export var title_pulse_scale: float = 1.055
@export var title_pulse_time: float = 0.8
@export var button_blink_min_alpha: float = 0.55
@export var button_blink_time: float = 0.8

@export_group("Sounds")
@export var title_slam_sound: AudioStream
@export var click_sound: AudioStream

@export_group("Nodes")
@export var animation_player: AnimationPlayer
@export var title_node: CanvasItem
@export var play_button: Button
@export var credits_button: Button
@export var scene_sfx: AudioStreamPlayer

@export_group("Credits")
@export_multiline var credits_text: String = "CLOSING TIME\n\nCreated by\nNattaphum Phadnok\nSirawit Niyomwong\nChunchak Srichanto"

var _title_sfx: AudioStreamPlayer
var _click_sfx: AudioStreamPlayer
var _credits_panel: ColorRect
var _intro_started := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var ui := $CanvasLayer/Control
	if animation_player == null:
		animation_player = $AnimationPlayer
	if title_node == null:
		title_node = ui.get_node("Ba527c9cBd534d969bc2B0fcd121f075RemovebgPreview") as CanvasItem
	if play_button == null:
		play_button = ui.get_node("Button") as Button
	if credits_button == null:
		credits_button = ui.get_node("Button2") as Button
	if scene_sfx == null:
		scene_sfx = get_node_or_null("SceneSfx") as AudioStreamPlayer
	if scene_sfx == null:
		scene_sfx = AudioStreamPlayer.new()
		scene_sfx.name = "SceneSfx"
		add_child(scene_sfx)

	_title_sfx = _get_or_make_sfx("TitleSfx", title_slam_sound)
	_click_sfx = _get_or_make_sfx("ClickSfx", click_sound)

	_hide_menu()
	_build_credits_panel()

	if not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if not credits_button.pressed.is_connected(_on_credits_pressed):
		credits_button.pressed.connect(_on_credits_pressed)

	_play_camera_animation()
	_run_intro()

func _get_or_make_sfx(node_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := get_node_or_null(node_name) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = node_name
		add_child(player)
	if stream != null:
		player.stream = stream
	return player

func _play_camera_animation() -> void:
	if animation_player == null:
		push_warning("ไม่พบ AnimationPlayer สำหรับอนิเมชันกล้อง")
		return

	var anim := camera_animation
	if anim == &"" or not animation_player.has_animation(anim):
		for name in animation_player.get_animation_list():
			if name != &"RESET":
				anim = name
				break

	if anim == &"":
		push_warning("ไม่พบอนิเมชันกล้อง")
		return

	animation_player.play(anim)

func _hide_menu() -> void:
	if title_node:
		title_node.modulate.a = 0.0
	if play_button:
		play_button.modulate.a = 0.0
		play_button.disabled = true
	if credits_button:
		credits_button.modulate.a = 0.0
		credits_button.disabled = true

func _run_intro() -> void:
	if _intro_started:
		return
	_intro_started = true

	# รอให้กล้องเล่นไปประมาณ 2 วิ ก่อนเริ่ม UI
	await get_tree().create_timer(title_delay).timeout
	if not is_inside_tree():
		return
	_slam_title()

	# ชื่อเกมตึมเข้ามาก่อน 0.5 วิ แล้วค่อยให้ปุ่มมา
	await get_tree().create_timer(buttons_delay).timeout
	if not is_inside_tree():
		return
	_show_buttons()

func _slam_title() -> void:
	if title_node == null:
		return

	title_node.modulate.a = 0.0
	title_node.scale = Vector2.ONE * 1.55
	if _title_sfx:
		_title_sfx.play()

	# ตึมเข้า: ใหญ่ -> เล็กลงพร้อมเด้งนิด ๆ
	var t := create_tween()
	t.tween_property(title_node, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(title_node, "modulate:a", 1.0, 0.10)
	t.tween_callback(_start_title_pulse)

func _start_title_pulse() -> void:
	if title_node == null:
		return

	var t := create_tween().set_loops()
	t.tween_property(title_node, "scale", Vector2.ONE * title_pulse_scale, title_pulse_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(title_node, "scale", Vector2.ONE, title_pulse_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _show_buttons() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(play_button, "modulate:a", 1.0, 0.55)
	t.tween_property(credits_button, "modulate:a", 1.0, 0.55)
	t.chain().tween_callback(_on_buttons_shown)

func _on_buttons_shown() -> void:
	play_button.disabled = false
	credits_button.disabled = false
	_start_button_blink(play_button)
	_start_button_blink(credits_button)

func _start_button_blink(node: CanvasItem) -> void:
	var t := create_tween().set_loops()
	t.tween_property(node, "modulate:a", button_blink_min_alpha, button_blink_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "modulate:a", 1.0, button_blink_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_play_pressed() -> void:
	if play_scene.is_empty() or not ResourceLoader.exists(play_scene):
		push_error("หาฉาก Map 2 ไม่เจอ: " + play_scene)
		return

	play_button.disabled = true
	credits_button.disabled = true
	_stop_menu_tweens()

	# Node นี้คือเสียงตอนกดเล่น/เปลี่ยนฉาก
	if scene_sfx and scene_sfx.stream:
		scene_sfx.play()
	elif _click_sfx:
		_click_sfx.play()

	# ใช้ SceneTransition ที่มีอยู่แล้วในโปรเจกต์ เพื่อเฟดฉากให้เนียน
	if SceneTransition != null and SceneTransition.has_method("change_scene"):
		SceneTransition.change_scene(play_scene)
	else:
		await get_tree().create_timer(0.25).timeout
		get_tree().change_scene_to_file(play_scene)

func _stop_menu_tweens() -> void:
	# การเปลี่ยนฉากจะล้าง node อยู่แล้ว จึงไม่จำเป็นต้องเก็บ Tween ไว้
	pass

func _build_credits_panel() -> void:
	_credits_panel = ColorRect.new()
	_credits_panel.name = "CreditsPanel"
	_credits_panel.color = Color(0.015, 0.015, 0.02, 0.94)
	_credits_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_credits_panel.visible = false
	_credits_panel.modulate.a = 0.0

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_panel.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var heading := Label.new()
	heading.text = "CLOSING TIME"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	box.add_child(heading)

	var label := Label.new()
	label.text = credits_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(150, 45)
	back.pressed.connect(_on_credits_back_pressed)
	box.add_child(back)

	$CanvasLayer.add_child(_credits_panel)

func _on_credits_pressed() -> void:
	if scene_sfx and scene_sfx.stream:
		scene_sfx.play()
	elif _click_sfx:
		_click_sfx.play()

	_credits_panel.visible = true
	_credits_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_credits_panel, "modulate:a", 1.0, 0.35)

func _on_credits_back_pressed() -> void:
	if scene_sfx and scene_sfx.stream:
		scene_sfx.play()
	elif _click_sfx:
		_click_sfx.play()

	var t := create_tween()
	t.tween_property(_credits_panel, "modulate:a", 0.0, 0.25)
	t.tween_callback(func() -> void:
		_credits_panel.visible = false
	)

func _unhandled_input(event: InputEvent) -> void:
	if _credits_panel != null and _credits_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_credits_back_pressed()
