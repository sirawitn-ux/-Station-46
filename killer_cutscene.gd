extends Node3D
## ซีนฆาตกรหลังทิ้งขยะ
## ลำดับ:
## 1) ผู้เล่นหยุดนิ่ง 1 วิ + พูด
## 2) ฆาตกรวาร์ปไป KillerSpawnPoint + เล่นเสียง
## 3) เปลี่ยนกล้องไปกล้องของฆาตกร (ผู้เล่นควบคุมไม่ได้)
## 4) ฆาตกรเดินตาม RoutePoints ที่กำหนดใน Inspector
## 5) ถึงจุดสุดท้าย -> คุยกับตัวเอก
## 6) ขึ้นตัวเลือก หนี / สู้ -> สุดท้ายตัวเอกสู้ไม่ว่าจะเลือกอะไร
## 7) ฆาตกรกับตัวเอกสู้กัน (ปล่อยสัญญาณ fight_started ให้ระบบต่อสู้มารับช่วง)

signal fight_started(killer: Node3D)
signal _fight_done(won: bool)

const HERO := "Big Judy"
const KILLER := "Killer"

@export_group("ตัวฆาตกร")
@export var killer_scene: PackedScene = preload("res://customer_npc_killer.tscn")
@export var killer_spawn_point: Node3D
@export var camera_point: Node3D
@export var route_points: Array[Node3D] = []
@export var walk_speed: float = 1.8
@export var arrive_distance: float = 0.45

@export_group("เสียงตอนฆาตกรโผล่")
@export var appear_sound: AudioStream = preload("res://universfield-eerie-sudden-shock-454675.mp3")
@export var appear_volume_db: float = 0.0

@export_group("กล้องฆาตกร")
@export var camera_fov: float = 55.0
@export var camera_height: float = 1.55

@export_group("บทพูด")
@export_multiline var hero_after_trash: String = "Why does it feel like someone is watching me..."
@export var killer_dialogue: Array[String] = [
	"Finally... alone at last.",
	"You shouldn't be here at night.",
	"I'll give you a choice. Run... or dieeeeeee! Hahahahaha!",
]
@export var hero_dialogue: Array[String] = [
	"Who's there!?",
	"Who are you!?",
]

@export_group("ฉากจบ")
@export_file("*.tscn") var menu_scene: String = "res://main_menu.tscn"
@export var credits_script_path: String = "res://end_credits.gd"
@export var music_fade_out_time: float = 1.5

@export_group("ตัวเลือกหนี/สู้")
@export var choice_flee_text: String = "Run"
@export var choice_fight_text: String = "Fight"
@export_multiline var hero_flee_try: String = "I have to run!"
@export_multiline var killer_block_flee: String = "Where do you think you're going...? There's no escape."
@export_multiline var hero_cornered: String = "...No choice, then. Fine, let's fight!"
@export_multiline var hero_choose_fight: String = "No more running... Let's fight!"
@export var fight_gap: float = 2.2  ## ระยะห่างตอนเริ่มสู้ (เมตร)

var _finished_game := false
var _killer: Node3D
var _killer_anim: AnimationPlayer
var _killer_camera: Camera3D
var _player_camera: Camera3D
var _running := false
var _route_index := 0
var _current_target: Node3D
var _finished_walking := false

func _ready() -> void:
	visible = false

	# ถ้าไม่ได้ลาก Marker ใน Inspector ให้หา Marker ลูกตามชื่ออัตโนมัติ
	if killer_spawn_point == null:
		killer_spawn_point = get_node_or_null("KillerSpawnPoint") as Node3D
	if camera_point == null:
		camera_point = get_node_or_null("KillerCameraPoint") as Node3D
	if route_points.is_empty():
		var found: Array[Node3D] = []
		var re := RegEx.create_from_string("^RoutePoint\\d+$")
		for child in get_children():
			if child is Node3D and re.search(str(child.name)) != null:
				found.append(child as Node3D)
		found.sort_custom(func(a: Node3D, b: Node3D): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
		route_points = found

func start_sequence() -> void:
	if _running:
		return
	_running = true
	visible = true
	
	var player := _find_player()
	if player:
		player.set_can_move(false)
		_player_camera = player.get("camera") as Camera3D
	
	# ให้ตัวเอกนิ่งประมาณ 1 วินาทีหลังทิ้งขยะ
	await get_tree().create_timer(1.0).timeout
	await _say_one(HERO, hero_after_trash)
	
	_spawn_killer()
	if _killer == null:
		_end_sequence()
		return

	# ให้ตัวเอกหันไปหาฆาตกรทันทีที่ฆาตกรปรากฏตัว
	_look_player_at_killer(player)
	
	_play_appear_sound()
	# เว้นจังหวะสั้น ๆ ให้เห็นตัวเอกหันไปมองก่อนตัดกล้อง
	await get_tree().create_timer(0.35).timeout
	_switch_to_killer_camera()
	
	await _walk_route()
	await _final_dialogue()
	await _choice_then_fight(player)
	if _finished_game:
		return   # กำลังกลับหน้าเมนู ไม่ต้องคืนการควบคุมให้ผู้เล่น
	_end_sequence()

func _look_player_at_killer(player: Node3D) -> void:
	if player == null or _killer == null:
		return

	# หันเฉพาะซ้าย/ขวา ไม่ให้ตัวละครก้ม/เงยตามตำแหน่งฆาตกร
	var player_pos := player.global_position
	var killer_pos := _killer.global_position
	killer_pos.y = player_pos.y

	var direction := killer_pos - player_pos
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return

	player.look_at(player_pos + direction, Vector3.UP)

func _spawn_killer() -> void:
	if killer_scene == null:
		push_error("KillerCutscene: ยังไม่ได้ใส่ Killer Scene")
		return
	if killer_spawn_point == null:
		push_error("KillerCutscene: กรุณากำหนด Killer Spawn Point")
		return
	
	_killer = killer_scene.instantiate() as Node3D
	if _killer == null:
		return
	get_tree().current_scene.add_child(_killer)
	_killer.global_transform = killer_spawn_point.global_transform
	_killer.visible = true
	
	_killer_anim = _killer.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play_killer_anim("Idle")

func _play_appear_sound() -> void:
	if appear_sound == null or _killer == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = appear_sound
	p.volume_db = appear_volume_db
	p.max_distance = 30.0
	_killer.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _switch_to_killer_camera() -> void:
	if _killer == null:
		return

	_killer_camera = Camera3D.new()
	_killer_camera.name = "KillerCutsceneCamera"
	_killer_camera.fov = camera_fov
	# ไม่ผูกเป็นลูกของฆาตกร เพื่อไม่ให้กล้องหมุนตามตอนฆาตกรหันตัว
	get_tree().current_scene.add_child(_killer_camera)

	# ใช้แค่ "ตำแหน่ง" ของ camera_point (ไม่เอามุมหมุน เพราะ Marker ที่เอียงจะทำให้ภาพเอียง)
	if camera_point != null:
		_killer_camera.global_position = camera_point.global_position
	else:
		_killer_camera.global_position = _killer.global_transform * Vector3(0, camera_height, 3.0)

	_aim_camera()
	_killer_camera.current = true
	if _player_camera:
		_player_camera.current = false

# หันกล้องมองฆาตกรโดยล็อกแกนตั้ง ภาพไม่เอียงแน่นอน
func _aim_camera() -> void:
	if _killer_camera == null or _killer == null or not is_instance_valid(_killer):
		return
	var target := _killer.global_position + Vector3.UP * 1.2
	if _killer_camera.global_position.distance_to(target) < 0.05:
		return
	_killer_camera.look_at(target, Vector3.UP)

func _process(_delta: float) -> void:
	if _killer_camera != null and is_instance_valid(_killer_camera):
		_aim_camera()

func _walk_route() -> void:
	if _killer == null:
		return
	
	var points: Array[Node3D] = []
	for p in route_points:
		if p != null:
			points.append(p)
	
	if points.is_empty():
		return
	
	for p in points:
		await _move_killer_to(p)

func _move_killer_to(point: Node3D) -> void:
	if _killer == null or point == null:
		return
	
	_current_target = point
	_play_killer_anim("Walking")
	
	while is_instance_valid(_killer):
		var flat := point.global_position - _killer.global_position
		flat.y = 0.0
		
		if flat.length() <= arrive_distance:
			break
		
		var dir := flat.normalized()
		_killer.global_position += dir * walk_speed * get_process_delta_time()
		_killer.rotation.y = lerp_angle(
			_killer.rotation.y,
			atan2(dir.x, dir.z),
			minf(1.0, 8.0 * get_process_delta_time())
		)
		await get_tree().process_frame
	
	_play_killer_anim("Idle")

func _final_dialogue() -> void:
	# ตอนคุยจะคืนกล้องให้มุมฆาตกรก่อน เพื่อให้เห็นฆาตกรเป็นหลัก
	if _killer_camera:
		_killer_camera.current = true
	
	for line in killer_dialogue:
		if str(line).strip_edges() == "":
			continue
		await _say_one(KILLER, str(line))
	
	for line in hero_dialogue:
		if str(line).strip_edges() == "":
			continue
		await _say_one(HERO, str(line))

func _say_one(speaker: String, line: String) -> void:
	if line.strip_edges() == "":
		return
	DialogueUi.show_dialogue(speaker, line)
	await get_tree().create_timer(maxf(2.0, line.length() * 0.075)).timeout
	DialogueUi.hide_dialogue()

func _play_killer_anim(anim_name: String) -> void:
	if _killer_anim == null:
		return
	if _killer_anim.has_animation(anim_name):
		if _killer_anim.current_animation != anim_name:
			_killer_anim.play(anim_name, 0.2)

func _end_sequence() -> void:
	DialogueUi.hide_dialogue()
	if _killer_camera and is_instance_valid(_killer_camera):
		_killer_camera.current = false
		_killer_camera.queue_free()
	_killer_camera = null
	if _player_camera:
		_player_camera.current = true
	var player := _find_player()
	if player:
		player.set_can_move(true)
	_running = false
	visible = false

func _find_player() -> Node3D:
	for n in get_tree().get_nodes_in_group("Player"):
		if n is Node3D and n.has_method("set_can_move"):
			return n
	return null

# ==========================================
# ตัวเลือก หนี / สู้ -> สุดท้ายสู้เหมือนกัน
# ==========================================
func _choice_then_fight(player: Node3D) -> void:
	# จำตำแหน่งตอนยืนเลือก หนี/สู้ ไว้ ถ้าแพ้จะกลับมาที่จุดนี้
	var saved := _save_fight_state(player)

	while true:
		var picked: int = await DialogueUi.show_choices([choice_flee_text, choice_fight_text])

		if picked == 0:
			# เลือกหนี: ตัวเอกลองหนี แต่ฆาตกรขวาง -> จำใจต้องสู้
			await _say_one(HERO, hero_flee_try)
			await _say_one(KILLER, killer_block_flee)
			await _say_one(HERO, hero_cornered)
		else:
			await _say_one(HERO, hero_choose_fight)

		var fight: Node = _start_fight(player)
		if fight == null:
			return
		_release_to_player(player)

		var won: bool = await _wait_fight(fight)
		if won:
			await _play_ending(player, fight)
			return
		await _retry_reset(player, fight, saved)

func _start_fight(player: Node3D) -> Node:
	if _killer == null or player == null:
		return null
	StoryManager.set_flag("fight_killer")

	# ระบบต่อสู้จริงอยู่ใน killer_fight.gd (ต้องวางไว้ที่ res://killer_fight.gd)
	var fight_script := load("res://killer_fight.gd") as GDScript
	if fight_script == null:
		push_error("KillerCutscene: ไม่พบ res://killer_fight.gd")
		return null
	var fight: Node = fight_script.new()
	fight.name = "KillerFight"
	get_tree().current_scene.add_child(fight)
	fight.begin(player, _killer, fight_gap)
	fight_started.emit(_killer)
	return fight

func _wait_fight(fight: Node) -> bool:
	fight.fight_won.connect(func() -> void: _fight_done.emit(true))
	fight.fight_lost.connect(func() -> void: _fight_done.emit(false))
	var won: bool = await _fight_done
	return won

# คืนกล้อง/การควบคุมให้ผู้เล่นตอนเริ่มสู้
func _release_to_player(player: Node3D) -> void:
	if _killer_camera and is_instance_valid(_killer_camera):
		_killer_camera.current = false
		_killer_camera.queue_free()
	_killer_camera = null
	if _player_camera:
		_player_camera.current = true
	if player and player.has_method("set_can_move"):
		player.set_can_move(true)

func _save_fight_state(player: Node3D) -> Dictionary:
	var cam := player.get("camera") as Camera3D
	return {
		"player_xf": player.global_transform,
		"cam_rot": cam.rotation if cam else Vector3.ZERO,
		"killer_xf": _killer.global_transform,
	}

# แพ้: จอดำ -> ลบระบบสู้ -> วางทุกอย่างกลับจุดเลือก -> กล้องฆาตกร -> จางเข้า -> ขึ้นตัวเลือกใหม่
func _retry_reset(player: Node3D, fight: Node, saved: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 1)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	get_tree().current_scene.add_child(layer)

	fight.queue_free()

	player.global_transform = saved["player_xf"]
	player.set("velocity", Vector3.ZERO)
	var cam := player.get("camera") as Camera3D
	if cam:
		cam.rotation = saved["cam_rot"]
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	_killer.global_transform = saved["killer_xf"]
	_killer.set("velocity", Vector3.ZERO)
	_play_killer_anim("Idle")

	if player.has_method("set_can_move"):
		player.set_can_move(false)
	_switch_to_killer_camera()

	await get_tree().create_timer(0.4).timeout
	var t := create_tween()
	t.tween_property(rect, "color:a", 0.0, 0.6)
	await t.finished
	layer.queue_free()

# ==========================================
# ฉากจบ: ชนะ -> (killer_fight ลดเสียงเพลง 50% + ตัวเอกพูดเสร็จแล้ว) -> เครดิต -> กลับหน้าเมนู
# ==========================================
func _play_ending(player: Node3D, fight: Node) -> void:
	_finished_game = true
	if player and player.has_method("set_can_move"):
		player.set_can_move(false)

	var credits_script := load(credits_script_path) as GDScript
	if credits_script == null:
		push_error("KillerCutscene: ไม่พบ " + credits_script_path + " (ข้ามเครดิต)")
	else:
		var credits = credits_script.new()
		get_tree().current_scene.add_child(credits)
		await credits.finished

	# เพลงค่อย ๆ เงียบพร้อมกลับหน้าเมนู
	if is_instance_valid(fight):
		fight.fade_music_out(music_fade_out_time)
	_reset_game_state()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# ไม่ await: ตัวสคริปต์นี้จะถูกลบเมื่อเปลี่ยนฉาก
	SceneTransition.change_scene(menu_scene)

# เคลียร์ความคืบหน้า เพื่อให้กด Play ใหม่แล้วเริ่มเกมได้ตั้งแต่ต้น
func _reset_game_state() -> void:
	StoryManager.flags.clear()
	StoryManager.done_tasks.clear()
	StoryManager.set_day(1)
	Engine.time_scale = 1.0
	var inv := get_node_or_null("/root/PlayerInventory")
	if inv:
		if "items" in inv:
			inv.items.clear()
		if "shelf_stock" in inv:
			inv.shelf_stock.clear()
