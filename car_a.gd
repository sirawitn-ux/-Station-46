extends Node3D
# รถที่ขับออกไปในฉากตัดต่อ
# ตัวละครเดินมาที่รถ -> เปิดประตู -> ขึ้นรถ -> ปิดประตู -> สตาร์ท -> ขับออกไปตามจุด drive_points -> หายไป
# แปะสคริปต์นี้ที่โหนดรากของฉากรถ (ต้องเป็น Node3D)

@export_group("เสียง (ลากไฟล์ .ogg จาก FileSystem มาใส่)")
@export var snd_door_open: AudioStream
@export var snd_door_close: AudioStream
@export var snd_engine_start: AudioStream
@export var snd_engine_loop: AudioStream
@export var snd_acceleration: AudioStream

@export_group("การขับ")
## ลาก Marker3D เรียงตามเส้นทางที่รถจะขับผ่าน จุดสุดท้ายควรอยู่นอกสายตา
@export var drive_points: Array[Node3D] = []
@export var speed: float = 9.0
## หน้ารถของโมเดลนี้หันไปทาง +Z เลยตั้ง 180 ไว้ให้แล้ว (ไม่งั้นรถจะขับถอยหลัง)
## ถ้ารถยังขับผิดด้าน ลองใส่ 0, 90 หรือ -90
@export var yaw_offset_deg: float = 180.0
## งานนี้เสร็จแล้วรถจะไม่อยู่ในฉากอีก (เช่นกลับเข้าแมพมาทีหลัง) เว้นว่าง = อยู่ตลอด
@export var gone_after_task: String = "talk_manager_leave"

var _engine_loop_player: AudioStreamPlayer3D

func _ready() -> void:
	if gone_after_task != "" and StoryManager.is_task_done(gone_after_task):
		queue_free()

# ผู้โดยสารเดินมาถึงข้างรถแล้ว เรียกฟังก์ชันนี้
func board_and_depart(passenger: Node) -> void:
	_play(snd_door_open)
	await get_tree().create_timer(0.6).timeout

	# คนขึ้นรถแล้ว หายจากฉาก
	if passenger and passenger.has_method("hide_for_cutscene"):
		passenger.hide_for_cutscene()
	await get_tree().create_timer(0.4).timeout

	_play(snd_door_close)
	await get_tree().create_timer(0.8).timeout

	await _depart()

func _depart() -> void:
	# สตาร์ทเครื่อง
	var start := _play(snd_engine_start)
	if start:
		await start.finished
	else:
		await get_tree().create_timer(1.0).timeout

	# เสียงเครื่องวิ่งต่อเนื่อง + เสียงออกตัว
	_engine_loop_player = _play(snd_engine_loop, true)
	_play(snd_acceleration)

	# ขับไปตามจุด: ค่อยๆ เร่ง และหันหน้าไปตามทาง
	var tw := create_tween()
	var pos := global_position
	var start_y := global_position.y   # รถวิ่งบนพื้นระดับเดิม ไม่ตามความสูงของ Marker
	var cur_angle := rotation.y
	var added := 0
	for p in drive_points:
		if p == null:
			continue
		var target := Vector3(p.global_position.x, start_y, p.global_position.z)
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

	# เสียงเครื่องค่อยๆ เบาลงแล้วรถหายไป
	if _engine_loop_player:
		var fade := create_tween()
		fade.tween_property(_engine_loop_player, "volume_db", -40.0, 1.2)
		await fade.finished
	queue_free()

func _play(stream: AudioStream, loop: bool = false) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	var s: AudioStream = stream
	if loop:
		s = stream.duplicate()
		s.set("loop", true)   # .ogg วนซ้ำ (ถ้าไฟล์ชนิดอื่นไม่มีค่านี้ จะไม่มีผล)
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.unit_size = 12.0
	p.max_distance = 120.0
	add_child(p)
	p.play()
	if not loop:
		p.finished.connect(p.queue_free)
	return p
