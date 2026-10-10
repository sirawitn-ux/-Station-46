extends Camera3D
# กล้องหน้าเมนู: เคลื่อนที่ช้าๆ ให้ฉากหลังดูมีชีวิต แปะที่โหนด Camera3D
# - โหมด "วนรอบ": กล้องวนรอบจุดที่มอง (Look Target)
# - โหมด "เลื่อนกล้อง": กล้องค่อยๆ เลื่อนจากตำแหน่งที่วางไว้ ไปยังจุด Dolly End แล้วเลื่อนกลับ วนไปเรื่อยๆ
# ทั้งสองโหมดมีการสั่นเบาๆ ให้เหมือนกล้องถือด้วยมือ

enum Mode { ORBIT, DOLLY }

@export var mode: Mode = Mode.ORBIT
## จุดที่กล้องมอง (วาง Marker3D ไว้กลางฉากที่อยากให้เห็น เช่น ตรงปั๊มน้ำมัน) เว้นว่าง = มองที่จุด (0,0,0)
@export var look_target: Node3D
## ขยับจุดที่มองขึ้น/ลงเล็กน้อย
@export var look_offset: Vector3 = Vector3(0, 1.5, 0)

@export_group("โหมดวนรอบ")
@export var orbit_radius: float = 14.0
@export var orbit_height: float = 3.0
## องศาต่อวินาที (ติดลบ = วนกลับด้าน)
@export var orbit_speed_deg: float = 5.0
## เริ่มวนจากมุมไหน (ลองปรับจนเห็นฉากที่ชอบ)
@export var orbit_start_deg: float = 0.0

@export_group("โหมดเลื่อนกล้อง")
## จุดปลายทาง (Marker3D) จุดเริ่มคือตำแหน่งที่คุณวางกล้องไว้ในฉาก
@export var dolly_end: Node3D
## เวลาไป-กลับครบ 1 รอบ (วินาที)
@export var dolly_time: float = 20.0

@export_group("สั่นเบาๆ")
@export var sway_amount: float = 0.12
@export var sway_speed: float = 0.6

var _t: float = 0.0
var _start_pos: Vector3
var _angle: float = 0.0

func _ready() -> void:
	_start_pos = global_position
	_angle = deg_to_rad(orbit_start_deg)

func _process(delta: float) -> void:
	_t += delta
	var center := look_target.global_position if look_target else Vector3.ZERO
	var pos := _start_pos

	match mode:
		Mode.ORBIT:
			_angle += deg_to_rad(orbit_speed_deg) * delta
			pos = center + Vector3(cos(_angle) * orbit_radius, orbit_height, sin(_angle) * orbit_radius)
		Mode.DOLLY:
			if dolly_end != null:
				var k := (1.0 - cos(_t / maxf(dolly_time, 0.1) * TAU)) * 0.5   # 0 -> 1 -> 0 นุ่มๆ
				pos = _start_pos.lerp(dolly_end.global_position, k)

	var sway := Vector3(
		sin(_t * sway_speed * 1.3),
		sin(_t * sway_speed * 0.9 + 1.0) * 0.6,
		cos(_t * sway_speed)
	) * sway_amount

	global_position = pos + sway
	var target := center + look_offset
	if global_position.distance_to(target) > 0.1:
		look_at(target)
