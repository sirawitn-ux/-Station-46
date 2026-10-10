extends Node
# เสียงฝีเท้า ใช้ได้กับตัวละครทุกตัวที่เป็น CharacterBody3D (ผู้เล่น, วาเนส, ลูกค้า, ฯลฯ)
# วิธีใช้: เพิ่มโหนด Node เป็นลูกของตัวละคร -> แปะสคริปต์นี้ -> ลากไฟล์เสียงใส่ช่อง Steps
# ไม่ต้องเขียนโค้ดเรียกเอง มันเช็กเองว่าตัวละครกำลังเดินอยู่บนพื้นหรือเปล่า

## ไฟล์เสียงก้าวเดิน ใส่ได้หลายไฟล์ จะสุ่มเล่นสลับกันไม่ให้ซ้ำติดกัน
@export var steps: Array[AudioStream] = []

@export_group("จังหวะ")
## เดินไปกี่เมตรถึงจะเล่นเสียง 1 ก้าว (ผู้เล่นเดินช้า SPEED=3 ลอง 1.6, วาเนส SPEED=1.3 ลอง 1.0)
@export var step_distance: float = 1.6
## ความเร็วต่ำสุดที่ถือว่า "กำลังเดิน" (กันเสียงดังตอนไถลหรือแทบไม่ขยับ)
@export var min_speed: float = 0.5
## หยุดเดินแล้วตัดเสียงทันที (เปิดไว้ ถ้าไฟล์เสียงยาวหรือตั้งวนซ้ำไว้ เสียงจะได้ไม่ค้าง)
@export var stop_when_idle: bool = true
## เสียงค่อยๆ เบาลงกี่วินาทีตอนหยุด (0 = ตัดทันที)
@export var fade_out_time: float = 0.08

@export_group("เสียง")
@export var volume_db: float = -4.0
## สุ่มระดับเสียงสูงต่ำเล็กน้อยให้ฟังไม่ซ้ำ (0 = ไม่สุ่ม)
@export_range(0.0, 0.5) var pitch_variation: float = 0.08
## ระยะที่ยังได้ยิน (เมตร) ผู้เล่นใส่เยอะๆ ได้ NPC ใส่น้อยลงเพื่อให้รู้ว่าอยู่ใกล้
@export var max_distance: float = 25.0
@export var unit_size: float = 4.0
## ชื่อ Audio Bus ที่ใช้ (ถ้าไม่มี bus นี้ จะใช้ Master)
@export var bus: StringName = &"Master"

var _body: CharacterBody3D
var _player: AudioStreamPlayer3D
var _travelled: float = 0.0
var _last_index: int = -1
var _fade: Tween

func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_warning("Footsteps: ต้องเป็นลูกของ CharacterBody3D")
		set_physics_process(false)
		return
	_player = AudioStreamPlayer3D.new()
	_player.volume_db = volume_db
	_player.max_distance = max_distance
	_player.unit_size = unit_size
	_player.bus = bus
	_body.add_child.call_deferred(_player)

func _physics_process(delta: float) -> void:
	if steps.is_empty() or not _body.visible:
		_travelled = 0.0
		_stop_sound()
		return
	var v := _body.get_real_velocity()
	var speed := Vector2(v.x, v.z).length()
	if not _body.is_on_floor() or speed < min_speed:
		# หยุดหรือลอย: เตรียมให้ก้าวแรกเล่นเร็วขึ้นหน่อยตอนเริ่มเดินใหม่
		_travelled = step_distance * 0.6
		_stop_sound()
		return
	_travelled += speed * delta
	if _travelled >= step_distance:
		_travelled = 0.0
		_play_step()

func _stop_sound() -> void:
	if not stop_when_idle or _player == null or not _player.playing:
		return
	if _fade != null and _fade.is_running():
		return
	if fade_out_time <= 0.0:
		_player.stop()
		return
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -40.0, fade_out_time)
	_fade.tween_callback(func():
		_player.stop()
		_player.volume_db = volume_db)

func _play_step() -> void:
	if _player == null or not _player.is_inside_tree():
		return
	var i := randi() % steps.size()
	if steps.size() > 1 and i == _last_index:
		i = (i + 1) % steps.size()
	_last_index = i
	if _fade != null and _fade.is_running():
		_fade.kill()
	_player.volume_db = volume_db
	_player.stream = steps[i]
	_player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	_player.play()
