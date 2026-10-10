extends Node
## ระบบต่อสู้ ตัวเอก vs ฆาตกร ในแมพเดิม (Map 1)
## ควบคุม: คลิกซ้ายเพื่อต่อย / เดินถอยเพื่อหลบ (ต่อยโดนตอนฆาตกรง้างมือ จะสะดุ้งและยกเลิกการโจมตี)
## ถูกสร้างและเรียก begin() จาก killer_cutscene.gd อัตโนมัติ

signal fight_won
signal fight_lost

@export_group("ตัวเอก")
@export var player_max_hp: float = 100.0
@export var punch_damage: float = 10.0
@export var punch_range: float = 2.0
@export var punch_cooldown: float = 0.45
@export var punch_angle_deg: float = 55.0

@export_group("ฆาตกร")
@export var killer_max_hp: float = 100.0
@export var killer_damage: float = 8.0
@export var killer_speed: float = 2.6
@export var killer_attack_range: float = 1.5
@export var killer_windup: float = 0.45
@export var killer_cooldown: float = 1.2

@export_group("เสียง")
@export var sfx_swing: AudioStream   ## เสียงเงื้อมต่อย (ตอนคลิก)
@export var sfx_hit: Array[AudioStream] = []   ## เสียงต่อยโดนฆาตกร (สุ่มเลือก)
@export var sfx_hurt: AudioStream    ## เสียงตัวเอกโดนต่อย
@export var sfx_volume_db: float = 0.0

@export_group("อื่น ๆ")
@export var gravity: float = 20.0
@export var retry_on_lose: bool = true
@export var win_line: String = "...จบแล้วสินะ"

const HERO := "จูดี้ใหญ่"

var player: CharacterBody3D
var killer: CharacterBody3D
var _cam: Camera3D
var _anim: AnimationPlayer
var _visual: Node3D
var _visual_base_x: float = 0.0

var _php: float
var _khp: float
var _punch_cd: float = 0.0
var _killer_cd: float = 0.6
var _winding: bool = false
var _attack_token: int = 0
var _active: bool = false
var _ended: bool = false
var _shake_tween: Tween
var _sfx_player: AudioStreamPlayer

var _hud: CanvasLayer
var _player_bar: ProgressBar
var _killer_bar: ProgressBar
var _flash: ColorRect

func begin(p: Node3D, k: Node3D, gap: float) -> void:
	player = p as CharacterBody3D
	killer = k as CharacterBody3D
	if player == null or killer == null:
		push_error("KillerFight: ต้องเป็น CharacterBody3D ทั้งตัวเอกและฆาตกร")
		queue_free()
		return

	_cam = player.get("camera") as Camera3D
	_anim = killer.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_visual = killer.get_node_or_null("Character_Killer_04") as Node3D
	if _visual:
		_visual_base_x = _visual.rotation.x

	_setup_audio()
	_php = player_max_hp
	_khp = killer_max_hp
	_place_killer(gap)
	_build_hud()
	_active = true

# ---------- เสียง ----------
func _setup_audio() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = sfx_volume_db
	add_child(_sfx_player)
	if sfx_swing == null:
		sfx_swing = _try_load("res://sfx_punch_swing.wav")
	if sfx_hit.is_empty():
		for p in ["res://sfx_punch_hit.wav", "res://sfx_punch_hit2.wav"]:
			var s := _try_load(p)
			if s:
				sfx_hit.append(s)
	if sfx_hurt == null:
		sfx_hurt = _try_load("res://sfx_player_hurt.wav")

func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	push_warning("KillerFight: ไม่พบไฟล์เสียง " + path)
	return null

# เล่นหลายเสียงซ้อนกันได้ (สร้างตัวเล่นชั่วคราว) พร้อมสุ่มระดับเสียงให้ไม่ซ้ำซาก
func _play_sfx(stream: AudioStream, pitch_var: float = 0.08) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = sfx_volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# ---------- วางตำแหน่ง (แก้ปัญหาตัวลอย: หาพื้นด้วย raycast) ----------
func _place_killer(gap: float) -> void:
	var pp: Vector3 = player.global_position
	var flat: Vector3 = killer.global_position - pp
	flat.y = 0.0
	var dir: Vector3 = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var pos: Vector3 = pp + dir * gap
	pos.y = _ground_y(pos, killer.global_position.y)
	killer.global_position = pos
	killer.velocity = Vector3.ZERO
	_face_killer(1.0)
	# ตัวเอกหันหน้าไปหาฆาตกร (ตัวเอกหันหน้าไปทาง -Z)
	var d: Vector3 = killer.global_position - player.global_position
	d.y = 0.0
	if d.length_squared() > 0.0001:
		player.rotation.y = atan2(-d.x, -d.z)

func _ground_y(pos: Vector3, fallback: float) -> float:
	var space := killer.get_world_3d().direct_space_state
	var from: Vector3 = pos + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0)
	q.exclude = [killer.get_rid(), player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return fallback
	return (hit["position"] as Vector3).y

# ---------- ลูปหลัก ----------
func _physics_process(delta: float) -> void:
	if not _active or _ended:
		return
	_punch_cd = maxf(0.0, _punch_cd - delta)
	_killer_cd = maxf(0.0, _killer_cd - delta)

	if killer.is_on_floor():
		killer.velocity.y = 0.0
	else:
		killer.velocity.y -= gravity * delta

	var to_p: Vector3 = player.global_position - killer.global_position
	to_p.y = 0.0
	var dist: float = to_p.length()

	if _winding or dist <= killer_attack_range:
		killer.velocity.x = 0.0
		killer.velocity.z = 0.0
		if not _winding:
			_play("Idle")
			if _killer_cd <= 0.0:
				_killer_attack()
	else:
		var d: Vector3 = to_p.normalized()
		killer.velocity.x = d.x * killer_speed
		killer.velocity.z = d.z * killer_speed
		_play("Run")

	_face_killer(minf(1.0, 10.0 * delta))
	killer.move_and_slide()

func _face_killer(weight: float) -> void:
	var d: Vector3 = player.global_position - killer.global_position
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return
	killer.rotation.y = lerp_angle(killer.rotation.y, atan2(d.x, d.z), weight)

func _play(anim_name: String) -> void:
	if _anim and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.2)

# ---------- ฆาตกรโจมตี ----------
func _killer_attack() -> void:
	_winding = true
	_attack_token += 1
	var token: int = _attack_token

	if _visual:
		var t := create_tween()
		t.tween_property(_visual, "rotation:x", _visual_base_x - deg_to_rad(14.0), killer_windup)
		t.tween_property(_visual, "rotation:x", _visual_base_x + deg_to_rad(30.0), 0.08)
		t.tween_property(_visual, "rotation:x", _visual_base_x, 0.25)

	await get_tree().create_timer(killer_windup).timeout
	if _ended or token != _attack_token:
		return  # ถูกต่อยสะดุ้งจนโจมตีไม่สำเร็จ

	var d: Vector3 = player.global_position - killer.global_position
	d.y = 0.0
	if d.length() <= killer_attack_range + 0.35:
		_hurt_player(killer_damage)

	await get_tree().create_timer(0.3).timeout
	if token == _attack_token:
		_winding = false
		_killer_cd = killer_cooldown

# ---------- ตัวเอกต่อย (คลิกซ้าย) ----------
func _unhandled_input(event: InputEvent) -> void:
	if not _active or _ended:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_player_punch()

func _player_punch() -> void:
	if _punch_cd > 0.0:
		return
	_punch_cd = punch_cooldown
	_shake(0.04, 0.12)
	_play_sfx(sfx_swing, 0.12)

	var to_k: Vector3 = killer.global_position - player.global_position
	to_k.y = 0.0
	if to_k.length() > punch_range or to_k.length_squared() < 0.0001:
		return

	var fwd: Vector3 = -player.global_transform.basis.z
	if _cam:
		fwd = -_cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return
	if rad_to_deg(fwd.normalized().angle_to(to_k.normalized())) > punch_angle_deg:
		return
	_hurt_killer(punch_damage, to_k.normalized())

# ---------- รับความเสียหาย ----------
func _hurt_killer(dmg: float, push_dir: Vector3) -> void:
	_khp = maxf(0.0, _khp - dmg)
	_killer_bar.value = _khp
	if not sfx_hit.is_empty():
		_play_sfx(sfx_hit[randi() % sfx_hit.size()])
	killer.global_position += push_dir * 0.3
	_attack_token += 1   # ยกเลิกการโจมตีที่กำลังง้างอยู่
	_winding = false
	_killer_cd = maxf(_killer_cd, 0.5)

	if _visual:
		var t := create_tween()
		t.tween_property(_visual, "rotation:x", _visual_base_x - deg_to_rad(18.0), 0.06)
		t.tween_property(_visual, "rotation:x", _visual_base_x, 0.15)

	if _khp <= 0.0:
		_win()

func _hurt_player(dmg: float) -> void:
	_php = maxf(0.0, _php - dmg)
	_player_bar.value = _php
	_play_sfx(sfx_hurt)
	_shake(0.12, 0.25)
	var t := create_tween()
	_flash.color = Color(0.8, 0.0, 0.0, 0.45)
	t.tween_property(_flash, "color:a", 0.0, 0.35)
	if _php <= 0.0:
		_lose()

func _shake(amount: float, dur: float) -> void:
	if _cam == null:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var step: float = dur / 5.0
	for i in 4:
		_shake_tween.tween_property(_cam, "h_offset", randf_range(-amount, amount), step)
		_shake_tween.parallel().tween_property(_cam, "v_offset", randf_range(-amount, amount), step)
	_shake_tween.tween_property(_cam, "h_offset", 0.0, step)
	_shake_tween.parallel().tween_property(_cam, "v_offset", 0.0, step)

# ---------- ผลการสู้ ----------
func _win() -> void:
	_ended = true
	StoryManager.set_flag("killer_defeated")
	killer.velocity = Vector3.ZERO
	_play("Idle")
	if _visual:
		var t := create_tween()
		t.tween_property(_visual, "rotation:x", _visual_base_x - PI * 0.5, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hud.visible = false
	await get_tree().create_timer(1.0).timeout
	if win_line.strip_edges() != "":
		DialogueUi.show_dialogue(HERO, win_line)
		await get_tree().create_timer(2.0).timeout
		DialogueUi.hide_dialogue()
	fight_won.emit()

func _lose() -> void:
	_ended = true
	fight_lost.emit()
	if not retry_on_lose:
		return
	# แพ้แล้วสู้ใหม่: จางดำ -> รีเซ็ตเลือดทั้งสองฝ่ายและวางฆาตกรใหม่
	var t := create_tween()
	_flash.color = Color(0, 0, 0, 0)
	t.tween_property(_flash, "color:a", 1.0, 0.8)
	await t.finished
	_php = player_max_hp
	_khp = killer_max_hp
	_player_bar.value = _php
	_killer_bar.value = _khp
	_attack_token += 1
	_winding = false
	_killer_cd = 1.0
	_place_killer(2.2)
	var t2 := create_tween()
	t2.tween_property(_flash, "color:a", 0.0, 0.6)
	_ended = false

# ---------- HUD ----------
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 60
	add_child(_hud)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_flash)

	_player_bar = _make_bar(player_max_hp, Color(0.3, 0.8, 0.4))
	_player_bar.anchor_top = 1.0
	_player_bar.anchor_bottom = 1.0
	_player_bar.offset_left = 30.0
	_player_bar.offset_right = 330.0
	_player_bar.offset_top = -50.0
	_player_bar.offset_bottom = -30.0
	_hud.add_child(_player_bar)
	_add_label("ตัวเอก", Vector2(30, -80), true)

	_killer_bar = _make_bar(killer_max_hp, Color(0.85, 0.15, 0.15))
	_killer_bar.anchor_left = 0.5
	_killer_bar.anchor_right = 0.5
	_killer_bar.offset_left = -200.0
	_killer_bar.offset_right = 200.0
	_killer_bar.offset_top = 40.0
	_killer_bar.offset_bottom = 60.0
	_hud.add_child(_killer_bar)

	var hint := _add_label("คลิกซ้ายเพื่อต่อย", Vector2(0, 0), false)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 0.0
	hint.offset_left = -150.0
	hint.offset_right = 150.0
	hint.offset_top = 70.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := create_tween()
	t.tween_interval(5.0)
	t.tween_property(hint, "modulate:a", 0.0, 1.0)

func _make_bar(max_hp: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_hp
	bar.value = max_hp
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _add_label(text: String, pos: Vector2, bottom_anchor: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	if bottom_anchor:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
		l.offset_left = pos.x
		l.offset_top = pos.y
	_hud.add_child(l)
	return l
