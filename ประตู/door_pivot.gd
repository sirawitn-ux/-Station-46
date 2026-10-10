extends Node3D

const DoorSfx = preload("res://door_sfx.gd")

@export var open_angle: float = 90.0
@export var open_speed: float = 0.4

@export_group("เสียงประตู")
@export var open_sound: AudioStream = preload("res://data/PSX_Style_Cars_by_GGBot_(August2023)/Sound effects/Car_Door_Open.ogg")   ## เปลี่ยนเป็นไฟล์เสียงของคุณได้
@export var close_sound: AudioStream = preload("res://data/PSX_Style_Cars_by_GGBot_(August2023)/Sound effects/Car_Door_Close.ogg")
@export var sound_volume_db: float = 0.0
@export var sound_max_distance: float = 25.0   ## ไกลกว่านี้จะไม่ได้ยิน

var is_open: bool = false
var initial_y_rotation: float

# ตัวนับจำนวนตัวละครที่ยืนอยู่ใน Area (รองรับทั้ง Player และ NPC หลายตัวพร้อมกัน)
var bodies_in_range: int = 0

# เก็บค่าตำแหน่ง Y เริ่มต้นของป้าย UI ไว้คำนวณระยะเด้ง
var label_front_base_y: float = 0.0
var label_back_base_y: float = 0.0
var ui_tween: Tween

@onready var interaction_area: Area3D = $InteractionArea
@onready var label_front: Label3D = $LabelFront
@onready var label_back: Label3D = $LabelBack

func _ready() -> void:
	initial_y_rotation = rotation_degrees.y
	_setup_sfx()
	
	# บันทึกตำแหน่ง Y เดิมของป้าย
	if label_front: label_front_base_y = label_front.position.y
	if label_back: label_back_base_y = label_back.position.y
	
	# ซ่อนป้ายเมื่อเริ่มเกม
	set_labels_visible(false)
	
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	# ถ้าผู้เล่นอยู่ใกล้และกดปุ่ม interact ให้สลับสถานะประตู (เปิด/ปิด)
	# เช็กจาก bodies_in_range ว่ามี Player อยู่จริงไหม (หรือใช้ตัวแปร is_player_near เดิมก็ได้ครับ)
	if bodies_in_range > 0 and event.is_action_pressed("interact"):
		# เช็กเบื้องต้นว่ามี Player อยู่ในพื้นที่ไหม (หรือจะเปิดให้กดได้ตลอดถ้าอยู่ใน Area)
		toggle_door()

func toggle_door() -> void:
	if is_open:
		close_door()
	else:
		open_door()

func open_door() -> void:
	if not is_open:
		_play_door_sound(true)   # เล่นเสียงเฉพาะตอนเปลี่ยนจากปิดเป็นเปิด
	is_open = true
	var target_y = initial_y_rotation + open_angle
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees:y", target_y, open_speed)

func close_door() -> void:
	if is_open:
		_play_door_sound(false)
	is_open = false
	var target_y = initial_y_rotation
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees:y", target_y, open_speed)

# ควบคุมการเปิด-ปิดป้าย และเรียกใช้แอนิเมชัน
func set_labels_visible(show_ui: bool) -> void:
	if label_front: label_front.visible = show_ui
	if label_back: label_back.visible = show_ui
	
	if show_ui:
		start_ui_bounce()
	else:
		stop_ui_bounce()

# ให้ป้ายลอยขึ้น-ลงนุ่มนวล
func start_ui_bounce() -> void:
	stop_ui_bounce()
	ui_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if label_front:
		ui_tween.parallel().tween_property(label_front, "position:y", label_front_base_y + 0.08, 0.6)
	if label_back:
		ui_tween.parallel().tween_property(label_back, "position:y", label_back_base_y + 0.08, 0.6)
		
	if label_front:
		ui_tween.chain().tween_property(label_front, "position:y", label_front_base_y, 0.6)
	if label_back:
		ui_tween.parallel().tween_property(label_back, "position:y", label_back_base_y, 0.6)

# หยุดแอนิเมชันและคืนตำแหน่งเดิม
func stop_ui_bounce() -> void:
	if ui_tween and ui_tween.is_valid():
		ui_tween.kill()
	
	if label_front: label_front.position.y = label_front_base_y
	if label_back: label_back.position.y = label_back_base_y

func _on_body_entered(body: Node3D) -> void:
	# ตรวจจับทั้ง Player และ CustomerNPC (หรือโหนดที่อยู่ในกลุ่ม npc / player)
	if body.is_in_group("player") or body.name == "Player" or body.is_in_group("npc") or "CustomerNPC" in body.name:
		bodies_in_range += 1
		
		# สั่งเปิดประตูอัตโนมัติทันทีเมื่อมีใครเดินเข้าใกล้
		open_door()
		
		# ถ้าเป็น Player ถึงจะให้แสดงป้าย UI กด [E]
		if body.is_in_group("player") or body.name == "Player":
			set_labels_visible(true)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player" or body.is_in_group("npc") or "CustomerNPC" in body.name:
		bodies_in_range = max(0, bodies_in_range - 1)
		
		# ถ้าไม่มีใครยืนอยู่ในบริเวณ Area แล้ว ให้ปิดประตูอัตโนมัติ
		if bodies_in_range == 0:
			close_door()
			set_labels_visible(false)

# ---------- เสียงประตู ----------
var _sfx: AudioStreamPlayer3D

func _setup_sfx() -> void:
	_sfx = AudioStreamPlayer3D.new()
	_sfx.volume_db = sound_volume_db
	_sfx.max_distance = sound_max_distance
	_sfx.unit_size = 6.0
	add_child(_sfx)

func _play_door_sound(opening: bool) -> void:
	if _sfx == null:
		return
	var s: AudioStream = open_sound if opening else close_sound
	if s == null:
		s = DoorSfx.open_sound() if opening else DoorSfx.close_sound()
	_sfx.stream = s
	_sfx.pitch_scale = randf_range(0.94, 1.06)
	_sfx.play()
