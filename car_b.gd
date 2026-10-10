extends Node3D
# รถของลูกค้า B: ขับเข้ามาตามจุด Marker แล้วจอดเพื่อเติมน้ำมัน
# แปะสคริปต์นี้ที่โหนดรากของฉาก CarB (ต้องเป็น Node3D หรือ CharacterBody3D)
# ปกติไม่ต้องเรียกเอง ตัวควบคุมเหตุการณ์ (node.gd (ตัวควบคุมเหตุการณ์ในโฟลเดอร์แมพ)) จะสั่งให้เอง

signal parked
## ขับออกไปจนจบเส้นทางแล้ว (รถถูกซ่อน)
signal departed

@export_group("เสียง (ลากไฟล์เสียงมาใส่)")
@export var snd_engine_loop: AudioStream
@export var snd_brake: AudioStream
@export var snd_door_open: AudioStream
@export var snd_door_close: AudioStream
@export var snd_acceleration: AudioStream

@export_group("การขับ")
@export var speed: float = 8.0
## ถ้ารถขับถอยหลังหรือหันผิดด้าน ลองเปลี่ยนเป็น 0, 90, -90 หรือ 180
@export var yaw_offset_deg: float = 180.0
## ช่วงสุดท้ายเบรกช้าๆ ก่อนจอด
@export var brake_slowdown: bool = true

@export_group("เส้นทาง (ลาก Marker3D มาใส่ได้เลย)")
## เส้นทางขับเข้า จุดแรก = จุดที่รถโผล่ (นอกสายตา) จุดสุดท้าย = ที่จอด (เว้นว่าง = หา Marker ชื่อ TargetPointCarB1, 2, ...)
@export var in_points: Array[Node3D] = []
## เส้นทางขับออก (เว้นว่าง = หา TargetPointCarBOut1, 2, ... ถ้าไม่มีก็ย้อนทางที่เข้ามา)
@export var out_points: Array[Node3D] = []

var _engine_player: AudioStreamPlayer3D

# ซ่อนรถและปิดการชน (ก่อนเหตุการณ์เริ่ม)
func set_active(value: bool) -> void:
	visible = value
	_set_collisions(self, value)

func _set_collisions(node: Node, value: bool) -> void:
	if node is CollisionObject3D:
		node.set_deferred("collision_layer", node.get_meta("_orig_layer", 1) if value else 0)
		node.set_deferred("collision_mask", node.get_meta("_orig_mask", 1) if value else 0)
	for c in node.get_children():
		_set_collisions(c, value)

func _remember_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.set_meta("_orig_layer", node.collision_layer)
		node.set_meta("_orig_mask", node.collision_mask)
	for c in node.get_children():
		_remember_collisions(c)

func _ready() -> void:
	_remember_collisions(self)

# ขับตามจุดแล้วจอดที่จุดสุดท้าย (จุดแรก = จุดที่รถโผล่เข้ามา ควรอยู่นอกสายตา)
func drive_and_park(points: Array[Node3D]) -> void:
	var pts: Array[Node3D] = []
	for p in points:
		if p != null:
			pts.append(p)
	if pts.size() < 2:
		push_warning("CarB: ต้องมีจุดอย่างน้อย 2 จุด (จุดแรกคือจุดเริ่ม จุดสุดท้ายคือที่จอด)")
		return

	var y := global_position.y
	var start := Vector3(pts[0].global_position.x, y, pts[0].global_position.z)
	global_position = start
	var first_dir := pts[1].global_position - pts[0].global_position
	first_dir.y = 0.0
	rotation.y = atan2(-first_dir.x, -first_dir.z) + deg_to_rad(yaw_offset_deg)
	set_active(true)

	_engine_player = _play(snd_engine_loop, true)

	var tw := create_tween()
	var pos := start
	var cur_angle := rotation.y
	for i in range(1, pts.size()):
		var target := Vector3(pts[i].global_position.x, y, pts[i].global_position.z)
		var dir := target - pos
		dir.y = 0.0
		if dir.length() < 0.01:
			continue
		var angle := atan2(-dir.x, -dir.z) + deg_to_rad(yaw_offset_deg)
		var dur := pos.distance_to(target) / speed
		var from_angle := cur_angle
		var step := tw.tween_property(self, "global_position", target, dur)
		if brake_slowdown and i == pts.size() - 1:
			step.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(
			func(t: float): rotation.y = lerp_angle(from_angle, angle, t),
			0.0, 1.0, minf(0.8, dur))
		pos = target
		cur_angle = angle

	_play(snd_brake)
	await tw.finished

	# ดับเครื่อง
	if _engine_player:
		var fade := create_tween()
		fade.tween_property(_engine_player, "volume_db", -40.0, 0.8)
		await fade.finished
		_engine_player.stop()
		_engine_player.queue_free()
		_engine_player = null
	parked.emit()

func open_door() -> void:
	_play(snd_door_open)

func close_door() -> void:
	_play(snd_door_close)

# ขับออกไปตามจุด (เริ่มจากตำแหน่งที่จอดอยู่) ออกตัวช้าๆ แล้วเร่ง ถึงจุดสุดท้ายแล้วรถหายไป
func drive_away(points: Array[Node3D]) -> void:
	var pts: Array[Node3D] = []
	for p in points:
		if p != null:
			pts.append(p)
	if pts.is_empty():
		push_warning("CarB: ไม่มีจุดให้ขับออก (วาง Marker ชื่อ TargetPointCarBOut1, 2, ...)")
		set_active(false)
		departed.emit()
		return

	var y := global_position.y
	_engine_player = _play(snd_engine_loop, true)
	_play(snd_acceleration)

	var tw := create_tween()
	var pos := global_position
	var cur_angle := rotation.y
	var added := 0
	for p in pts:
		var target := Vector3(p.global_position.x, y, p.global_position.z)
		var dir := target - pos
		dir.y = 0.0
		if dir.length() < 0.01:
			continue
		var angle := atan2(-dir.x, -dir.z) + deg_to_rad(yaw_offset_deg)
		var dur := pos.distance_to(target) / speed
		var from_angle := cur_angle
		var step := tw.tween_property(self, "global_position", target, dur)
		if added == 0:
			step.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)   # ออกตัวช้าๆ แล้วเร่ง
		tw.parallel().tween_method(
			func(t: float): rotation.y = lerp_angle(from_angle, angle, t),
			0.0, 1.0, minf(0.8, dur))
		pos = target
		cur_angle = angle
		added += 1

	if added > 0:
		await tw.finished
	else:
		tw.kill()

	if _engine_player:
		var fade := create_tween()
		fade.tween_property(_engine_player, "volume_db", -40.0, 0.8)
		await fade.finished
		_engine_player.stop()
		_engine_player.queue_free()
		_engine_player = null
	set_active(false)
	departed.emit()

func _play(stream: AudioStream, loop: bool = false) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	var s: AudioStream = stream
	if loop:
		s = stream.duplicate()
		s.set("loop", true)
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.unit_size = 12.0
	p.max_distance = 120.0
	add_child(p)
	p.play()
	if not loop:
		p.finished.connect(p.queue_free)
	return p
