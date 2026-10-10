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
var is_player_near: bool = false
var initial_y_rotation: float

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
	if is_player_near and event.is_action_pressed("interact"):
		toggle_door()

func toggle_door() -> void:
	is_open = !is_open
	_play_door_sound(is_open)
	var target_y = initial_y_rotation + (open_angle if is_open else 0.0)
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
	if body.is_in_group("player") or body.name == "Player":
		is_player_near = true
		set_labels_visible(true)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_near = false
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
