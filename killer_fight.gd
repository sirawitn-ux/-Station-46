extends Node
## ระบบต่อสู้ ตัวเอก vs ฆาตกร ในแมพเดิม (Map 1)
## ควบคุม: คลิกซ้ายเพื่อต่อย / เดินถอยเพื่อหลบ (ต่อยโดนตอนฆาตกรง้างมือ จะสะดุ้งและยกเลิกการโจมตี)
## ถูกสร้างและเรียก begin() จาก killer_cutscene.gd อัตโนมัติ

signal fight_won
signal fight_lost

@export_group("ตัวเอก")
@export var player_max_hp: float = 100.0
@export var punch_damage: float = 7.0
@export var punch_range: float = 2.0
@export var punch_cooldown: float = 0.55
@export var punch_angle_deg: float = 55.0

@export_group("ฆาตกร")
@export var killer_max_hp: float = 250.0
@export var killer_damage: float = 14.0
@export var killer_speed: float = 3.6
@export var killer_attack_range: float = 1.8
@export var killer_windup: float = 0.32
@export var killer_cooldown: float = 0.8
@export var punch_interrupts_attack: bool = false  ## true = ต่อยแล้วฆาตกรสะดุ้งหยุดโจมตี (ง่ายขึ้นมาก)
@export var punch_knockback: float = 0.12

@export_group("เสียง")
@export var sfx_swing: AudioStream   ## เสียงเงื้อมต่อย (ตอนคลิก)
@export var sfx_hit: Array[AudioStream] = []   ## เสียงต่อยโดนฆาตกร (สุ่มเลือก)
@export var sfx_hurt: AudioStream    ## เสียงตัวเอกโดนต่อย
@export var sfx_volume_db: float = 0.0

@export_group("เพลงต่อสู้")
## ใส่เพลงของคุณเองได้ ถ้าเว้นว่างจะหาไฟล์ res://fight_music.mp3 / .ogg / .wav ก่อน
## ถ้าไม่มีไฟล์ จะสร้างเพลงสั้น ๆ จากโค้ดให้เล่นวนแทน
@export var fight_music: AudioStream = preload("res://lnplusmusic-sport-sports-rock-music-597971.mp3")
@export var music_volume_db: float = -4.0
@export var music_fade_in: float = 1.5
@export_range(0.0, 1.0) var music_duck_linear: float = 0.5  ## ตอนชนะเสียงเพลงเหลือกี่เท่า (0.5 = 50%)
@export var music_duck_time: float = 1.0

@export_group("อื่น ๆ")
@export var gravity: float = 20.0
@export var win_lines: Array[String] = [
	"...It's over, huh.",
	"Just a pathetic punk like this... he's going to prison for a long time, bro.",
]

const HERO := "Big Judy"

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
var _music: AudioStreamPlayer
var _music_tween: Tween

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
	_start_music()
	_php = player_max_hp
	_khp = killer_max_hp
	_place_killer(gap)
	_build_hud()
	_active = true

# ---------- เพลงต่อสู้ ----------
func _start_music() -> void:
	if fight_music == null:
		for ext in ["mp3", "ogg", "wav"]:
			var path: String = "res://fight_music." + str(ext)
			if ResourceLoader.exists(path):
				fight_music = load(path) as AudioStream
				break
	if fight_music == null:
		fight_music = _synth_music()
	_set_loop(fight_music)

	_music = AudioStreamPlayer.new()
	_music.name = "FightMusic"
	_music.stream = fight_music
	_music.volume_db = -40.0
	add_child(_music)
	# กันพลาด: ถ้าเพลงเล่นจบโดยไม่ได้ตั้งลูป ให้เล่นใหม่เอง
	_music.finished.connect(func() -> void:
		if _music and is_instance_valid(_music) and _music.stream:
			_music.play()
	)
	_music.play()
	_tween_music(music_volume_db, music_fade_in)

func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			var bytes_per := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
			w.loop_end = int(w.data.size() / float(bytes_per))
	elif "loop" in s:
		s.set("loop", true)

func _tween_music(target_db: float, time: float) -> void:
	if _music == null or not is_instance_valid(_music):
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", target_db, maxf(0.01, time))

# ตอนชนะ: ลดเสียงเพลงลงตามสัดส่วน (0.5 = เหลือ 50% ของความดังเดิม)
func _duck_music() -> void:
	_tween_music(music_volume_db + linear_to_db(maxf(0.0001, music_duck_linear)), music_duck_time)

# เรียกจากภายนอกตอนจะจบ (เช่นเครดิตจบ) เพื่อให้เพลงค่อย ๆ เงียบ
func fade_music_out(time: float = 1.5) -> void:
	_tween_music(-60.0, time)

# เพลงเครียด ๆ วนได้ ประมาณ 6.4 วินาที: เบสริฟฟ์ + กลอง + เสียงอึมครึม
func _synth_music() -> AudioStreamWAV:
	var rate := 11025   # ความถี่ต่ำเพื่อให้สร้างเร็ว (เพลงเน้นเบส/กลอง ไม่เสียคุณภาพมาก)
	var bpm := 150.0
	var beat := 60.0 / bpm
	var bars := 4
	var total := beat * 4.0 * bars
	var n := int(rate * total)
	var data := PackedFloat32Array()
	data.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	# โน้ตเบส (Hz) 8 ตัวต่อห้อง เสียงเพี้ยนครึ่งเสียงให้รู้สึกอันตราย
	var riff: Array = [
		[55.0, 55.0, 65.4, 55.0, 58.3, 55.0, 65.4, 49.0],
		[55.0, 55.0, 65.4, 55.0, 58.3, 55.0, 73.4, 65.4],
		[55.0, 55.0, 65.4, 55.0, 58.3, 55.0, 65.4, 49.0],
		[55.0, 65.4, 55.0, 73.4, 77.8, 73.4, 65.4, 58.3],
	]
	var eighth := beat / 2.0
	var kick_beats := [0.0, 2.0, 2.5]
	var snare_beats := [1.0, 3.0]
	var bass_phase := 0.0
	var pad_phase_a := 0.0
	var pad_phase_b := 0.0
	var hat_lp := 0.0
	var snare_lp := 0.0

	for i in n:
		var t := float(i) / rate
		var bar_i := int(t / (beat * 4.0)) % bars
		var in_bar := fmod(t, beat * 4.0)

		# --- เบส ---
		var step := int(in_bar / eighth) % 8
		var st := fmod(in_bar, eighth)
		var f0: float = riff[bar_i][step]
		bass_phase += TAU * f0 / rate
		var benv := exp(-st * 7.0) * minf(1.0, st * 300.0)
		var bass := (sin(bass_phase) + 0.45 * sin(bass_phase * 2.0) + 0.25 * sin(bass_phase * 3.0)) * benv
		# บีบเสียงให้หยาบขึ้นเล็กน้อย
		bass = clampf(bass * 1.6, -1.0, 1.0)

		# --- กลองใหญ่: จังหวะ 1, 3 และเติมก่อนห้องถัดไป ---
		var kick := 0.0
		for kt in kick_beats:
			var kd: float = in_bar - float(kt) * beat
			if kd >= 0.0 and kd < 0.25:
				kick += sin(TAU * (45.0 + 90.0 * exp(-kd * 40.0)) * kd) * exp(-kd * 14.0)

		# --- สแนร์: จังหวะ 2, 4 ---
		var snare := 0.0
		for sb in snare_beats:
			var sd: float = in_bar - float(sb) * beat
			if sd >= 0.0 and sd < 0.2:
				var nz := rng.randf() * 2.0 - 1.0
				snare_lp += (nz - snare_lp) * 0.5
				snare += (nz - snare_lp * 0.6) * exp(-sd * 20.0)

		# --- ไฮแฮต: ทุกครึ่งจังหวะ ---
		var hd := fmod(in_bar, eighth)
		var hat := 0.0
		if hd < 0.04:
			var hn := rng.randf() * 2.0 - 1.0
			hat_lp += (hn - hat_lp) * 0.7
			hat = (hn - hat_lp) * exp(-hd * 90.0)

		# --- เสียงอึมครึม ค้างยาว (สองเสียงเพี้ยนกันเล็กน้อย) ---
		pad_phase_a += TAU * 220.0 / rate
		pad_phase_b += TAU * 233.1 / rate
		var trem := 0.6 + 0.4 * sin(TAU * 0.5 * t)
		var pad := (sin(pad_phase_a) + sin(pad_phase_b)) * 0.5 * trem

		data[i] = bass * 0.55 + kick * 0.9 + snare * 0.35 + hat * 0.14 + pad * 0.07

	# ตัดปลายสั้น ๆ ให้ต่อวนไม่เกิดเสียงป๊อก
	var fade := int(rate * 0.01)
	for j in fade:
		var g := float(j) / fade
		data[j] *= g
		data[n - 1 - j] *= g

	var w := _to_wav(data, rate)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

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
	# ไม่มีไฟล์ก็ไม่เป็นไร สร้างเสียงเองจากโค้ด จะได้มีเสียงเสมอ
	if sfx_swing == null:
		sfx_swing = _synth_swing()
	if sfx_hit.is_empty():
		sfx_hit.append(_synth_hit(0.30, 170.0, 55.0, 14.0, 1))
		sfx_hit.append(_synth_hit(0.28, 210.0, 70.0, 16.0, 2))
	if sfx_hurt == null:
		sfx_hurt = _synth_hit(0.40, 130.0, 40.0, 10.0, 3)

func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

# ---------- สังเคราะห์เสียง (ไม่ต้องใช้ไฟล์) ----------
const _RATE := 22050

func _to_wav(data: PackedFloat32Array, rate: int = _RATE) -> AudioStreamWAV:
	var peak := 0.0001
	for v in data:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w

func _synth_swing() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var dur := 0.22
	var n := int(_RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / _RATE
		var nz := rng.randf() * 2.0 - 1.0
		lp += (nz - lp) * 0.25
		var env := pow(sin(PI * t / dur), 2.0)
		data[i] = (nz - lp) * env
	return _to_wav(data)

func _synth_hit(dur: float, f0: float, f1: float, decay: float, seed_val: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var n := int(_RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / _RATE
		var freq := f0 * pow(f1 / f0, t / dur)
		phase += TAU * freq / _RATE
		var nz := rng.randf() * 2.0 - 1.0
		lp += (nz - lp) * 0.3
		var thud := sin(phase) * exp(-t * decay)
		var body := lp * exp(-t * decay * 2.2)
		var click := nz * exp(-t * 400.0)
		data[i] = thud + 0.9 * body + 0.4 * click
	return _to_wav(data)

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
	killer.global_position += push_dir * punch_knockback
	if punch_interrupts_attack:
		_attack_token += 1   # ยกเลิกการโจมตีที่กำลังง้างอยู่
		_winding = false
		_killer_cd = maxf(_killer_cd, 0.5)

	if _visual and not _winding:
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
	if player.has_method("set_can_move"):
		player.set_can_move(false)
	_duck_music()   # ชนะแล้ว เสียงเพลงเบาลงเหลือ 50%
	await get_tree().create_timer(1.0).timeout
	for line in win_lines:
		if str(line).strip_edges() == "":
			continue
		DialogueUi.show_dialogue(HERO, str(line))
		await get_tree().create_timer(maxf(2.0, str(line).length() * 0.075)).timeout
		DialogueUi.hide_dialogue()
	# hide_dialogue ปลดล็อกให้เดินได้ ต้องล็อกกลับ เพราะต่อไปคือเครดิต
	if player.has_method("set_can_move"):
		player.set_can_move(false)
	fight_won.emit()

func _lose() -> void:
	_ended = true
	_active = false
	_attack_token += 1
	_winding = false
	if player.has_method("set_can_move"):
		player.set_can_move(false)
	killer.velocity = Vector3.ZERO
	_play("Idle")
	# จางดำ แล้วให้ cutscene รีเซ็ตทุกอย่างกลับไปที่จุดเลือก หนี/สู้
	_flash.color = Color(0, 0, 0, 0)
	fade_music_out(0.8)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 1.0, 0.8)
	await t.finished
	if _visual:
		_visual.rotation.x = _visual_base_x
	fight_lost.emit()

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
	_add_label("Big Judy", Vector2(30, -80), true)

	_killer_bar = _make_bar(killer_max_hp, Color(0.85, 0.15, 0.15))
	_killer_bar.anchor_left = 0.5
	_killer_bar.anchor_right = 0.5
	_killer_bar.offset_left = -200.0
	_killer_bar.offset_right = 200.0
	_killer_bar.offset_top = 40.0
	_killer_bar.offset_bottom = 60.0
	_hud.add_child(_killer_bar)

	var hint := _add_label("Left-click to punch", Vector2(0, 0), false)
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
