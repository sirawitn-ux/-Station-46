extends Node
# เหตุการณ์ลูกค้า B (วันที่ 1) ตัวควบคุมลำดับทั้งหมด
# วางสคริปต์นี้ไว้ที่โหนด Node (ลูกของ Map1) ที่มีอยู่แล้วใน Map_1 เก็บไฟล์ไว้ที่ res://แมพ/node.gd
#
# ลำดับ: เติมของครบ -> จูดี้บ่น -> CarB ขับตาม Marker มาจอด
#   -> CustomerNPCB ลงจากรถ เดินตาม Marker แล้วหยุดรอ (มีป้ายลอยเหนือหัว)
#   -> ผู้เล่นเดินไปกด E คุยและคิดเงิน
#   -> ลูกค้าเดินกลับไปขึ้นรถ -> รถขับออกไปตามเส้นทางขาออก -> งาน customer_b เสร็จ
#
# Marker ที่ต้องมี (Marker3D เป็นลูกของ Map1 ตั้งชื่อตามนี้ ตามด้วยเลขเรียงลำดับ):
#   TargetPointCarB1, 2, 3 ...        เส้นทางรถขับเข้า  จุดแรก = จุดที่รถโผล่ (นอกสายตา)  จุดสุดท้าย = ที่จอด
#   TargetPointB1, 2, 3 ...           เส้นทางที่ลูกค้าเดินหลังลงรถ  จุดสุดท้าย = จุดที่ยืนรอให้ผู้เล่นมาคุย
#   TargetPointCarBOut1, 2, 3 ...     เส้นทางรถขับออก (ถ้าไม่มี รถจะขับย้อนทางที่เข้ามา)
#   TargetPointBBack1, 2, 3 ...       เส้นทางที่ลูกค้าเดินกลับไปรถ (ไม่บังคับ ถ้าไม่มี จะเดินย้อนเส้นทางเดิม)
# ชื่อแบบเก่า CarBPoint / CustBPoint / CarBOut / CustBBack ก็ใช้ได้ หรือจะลาก Marker ใส่ช่อง Inspector แทนก็ได้

const HERO := "Big Judy"
const CUSTOMER := "Customer"   # เปลี่ยนชื่อลูกค้าที่นี่ที่เดียว

## ชื่องานใน DAY_PLAN ของ StoryManager
@export var task_id: String = "customer_b"
## งานที่ต้องเสร็จก่อนเหตุการณ์จะเริ่ม
@export var after_task_id: String = "restock"

@export_group("โหนดในแมพ (เว้นว่าง = หาตามชื่อ CarB / CustomerNPCB)")
@export var car: Node3D
@export var customer: Node3D

@export_group("เส้นทาง (เว้นว่าง = หา Marker ตามชื่อ)")
@export var car_in_points: Array[Node3D] = []
@export var customer_walk_points: Array[Node3D] = []
@export var customer_back_points: Array[Node3D] = []
@export var car_out_points: Array[Node3D] = []

@export_group("จังหวะ")
## เปิด = จูดี้บ่นก่อนรถมา (บทอยู่ด้านล่าง monologue_lines)
@export var use_monologue: bool = true
## หลังจูดี้บ่นจบ รอกี่วินาทีก่อนรถโผล่
@export var delay_before_car: float = 3.0
## ลูกค้าลงรถ: ตำแหน่งเทียบกับรถ (หน้ารถอยู่ +Z, ขวาคือ -X) ปรับถ้าลูกค้าโผล่ผิดฝั่ง
@export var exit_offset: Vector3 = Vector3(-1.6, 0.0, 0.3)
## ลูกค้าถึงจุดที่ยืนรอแล้ว ให้ป้ายลอยข้อความอะไร
@export var wait_hint_text: String = "Checkout\nV"
## คุยจบแล้ว ลูกค้ารอกี่วินาทีก่อนเดินกลับ
@export var pause_after_talk: float = 0.8

# ==========================================
# จูดี้บ่นหลังเติมของเสร็จ: [ชื่อ, ข้อความ] (แก้เป็นบทของคุณได้เลย)
# เปลี่ยนบรรทัดเองตามเวลาตัวอักษร
# ==========================================
var monologue_lines: Array = [
	[HERO, "Ugh... I'm exhausted."],
	[HERO, "It's only my first day and I've been hauling stuff back and forth. My arms are about to fall off."],
	[HERO, "And it's so dead quiet here, like I'm the last person left in the world."],
	[HERO, "Let me grab a cup of coffee first... Huh? Is that a car?"],
]

# ==========================================
# บทคุยกับลูกค้า B (ตัวอย่าง แก้เป็นบทของคุณได้เลย) ตอนผู้เล่นกด E ที่ตัวลูกค้า: [ชื่อ, ข้อความ] กด E ไปบรรทัดถัดไป
# ==========================================
var talk_lines: Array = [
	[CUSTOMER, "Hello."],
	[CUSTOMER, "I haven't seen you here before."],
	[CUSTOMER, "Vanes isn't working tonight?"],
	[HERO, "I'm the new night-shift guy. My name's Big Judy."],
	[HERO, "It's my first day here, and honestly, I'm surprised anyone would drive down a creepy road like this and stop by at night."],
	[CUSTOMER, "Not many people use this road to begin with. And with all the strange things going on lately, everyone takes a different route after dark."],
	[HERO, "Strange things?"],
	[CUSTOMER, "Yes. It's been going on for a while now, almost a month, and they still haven't caught whoever's behind it."],
	[HERO, "It's not... a murder case, is it?"],
	[CUSTOMER, "Oh, so he did tell you. I thought Vanes wouldn't mention it."],
	[CUSTOMER, "I'll have to see Vanes in a new light. Even if he is a bit of a prankster."],
	[HERO, "Honestly, I didn't think it was real. Not with the manager's love of pranks."],
	[HERO, "Will that be cash or a transfer?"],
	[CUSTOMER, "I'll scan, please."],
	[CUSTOMER, "If anything strange happens, stay calm and call this place's emergency hotline."],
	[CUSTOMER, "It's for your own safety."],
	[CUSTOMER, "I'll swing by to check on you every now and then, too."],
	[HERO, "Thanks for looking out for me. Take care out there."],
	[CUSTOMER, "Good luck with the job, Big Judy."],
	[HERO, "By the way, what's your name?"],
	[CUSTOMER, "I'll tell you next time. I've got to run now. Bye, Mr. Clerk!"],
	[HERO, "Huh?"],
]

var _started: bool = false
var _waiting: bool = false
signal _advance

func _ready() -> void:
	# Map_1 เรียก StoryManager.begin_map() ใน _ready ของตัวเอง ซึ่งรันหลังลูกๆ จึงต้องรอ 1 เฟรม
	await get_tree().process_frame
	if car == null:
		car = get_parent().get_node_or_null("CarB") as Node3D
	if customer == null:
		customer = get_parent().get_node_or_null("CustomerNPCB") as Node3D

	# ซ่อนก่อนเหตุการณ์เริ่ม
	if car and car.has_method("set_active"):
		car.set_active(false)
	elif car:
		car.visible = false
	if customer and customer.has_method("hide_npc"):
		customer.hide_npc()

	if not StoryManager.is_task_pending(task_id):
		return   # งานนี้ทำไปแล้ว (หรือวันนี้ไม่มี)

	if StoryManager.is_task_done(after_task_id):
		_start_event(StoryManager.has_flag(_mono_key()))
	else:
		StoryManager.task_done.connect(_on_task_done)

func _on_task_done(id: String) -> void:
	if id == after_task_id:
		_start_event(false)

func _mono_key() -> String:
	return "cb_monologue_day_%d" % StoryManager.current_day

# ---------- ลำดับเหตุการณ์ ----------
func _start_event(skip_monologue: bool) -> void:
	if _started:
		return
	_started = true

	if car == null or customer == null:
		push_warning("CustomerEvent: หา CarB หรือ CustomerNPCB ในแมพไม่เจอ (ตั้งชื่อโหนดให้ตรง หรือลากใส่ช่อง Car / Customer)")
		return

	var car_in := _points(car_in_points if car_in_points.size() > 0 else _from(car, "in_points"), ["TargetPointCarB", "CarBPoint"])
	var walk := _points(customer_walk_points if customer_walk_points.size() > 0 else _from(customer, "walk_points"), ["TargetPointB", "CustBPoint"])
	if car_in.size() < 2:
		push_warning("CustomerEvent: ต้องมี Marker TargetPointCarB1, TargetPointCarB2 อย่างน้อย 2 จุด")
		return
	if walk.is_empty():
		push_warning("CustomerEvent: ไม่มี Marker TargetPointB1, 2, ... ลูกค้าจะยืนรอตรงข้างรถ")
	print("[ลูกค้า B] รถ ", car_in.size(), " จุด / เดิน ", walk.size(), " จุด")

	# 1) จูดี้บ่น
	if use_monologue and not skip_monologue:
		StoryManager.set_flag(_mono_key())
		await get_tree().create_timer(1.0).timeout
		await _run_lines(monologue_lines, true)
	await get_tree().create_timer(delay_before_car).timeout

	# 2) รถขับมาจอด
	await car.drive_and_park(car_in)

	# 3) ลูกค้าลงจากรถ
	if car.has_method("open_door"):
		car.open_door()
	await get_tree().create_timer(0.7).timeout

	var spawn: Vector3 = car.global_transform * exit_offset
	spawn.y = car.global_position.y + 0.6   # ให้ตกลงพื้นเอง
	var face_to: Vector3 = walk[0].global_position if walk.size() > 0 else spawn + Vector3(0, 0, 1)
	var d := face_to - spawn
	customer.appear_at(spawn, atan2(-d.x, -d.z))
	await get_tree().create_timer(0.5).timeout

	# 4) เดินตามจุดแล้วหยุดรอ
	if walk.size() > 0:
		await customer.walk_route(walk)

	# 5) รอผู้เล่นเดินมากด E คุย (ลูกค้ามีป้ายลอยอยู่เหนือหัว)
	customer.enable_talk(wait_hint_text)
	await customer.interacted
	await _run_lines(talk_lines, false)
	await get_tree().create_timer(pause_after_talk).timeout

	# 6) ลูกค้าเดินกลับไปที่ประตูรถ
	var back_route: Array[Node3D] = _points(customer_back_points if customer_back_points.size() > 0 else _from(customer, "back_points"), ["TargetPointBBack", "CustBBack"])
	if back_route.is_empty():
		back_route.assign(walk)
		back_route.reverse()
		if back_route.size() > 0:
			back_route.pop_front()   # ตัวแรกหลังกลับด้านคือจุดที่ยืนอยู่แล้ว
	var door := Marker3D.new()
	add_child(door)
	door.global_position = spawn
	back_route.append(door)
	await customer.walk_route(back_route)
	door.queue_free()

	# 7) ขึ้นรถ
	if car.has_method("open_door"):
		car.open_door()
	await get_tree().create_timer(0.5).timeout
	customer.hide_npc()
	await get_tree().create_timer(0.5).timeout
	if car.has_method("close_door"):
		car.close_door()
	await get_tree().create_timer(0.8).timeout

	# 8) รถขับออกไปตามเส้นทางขาออก (ไม่มี Marker ขาออก = ย้อนทางที่เข้ามา)
	var out_route := _points(car_out_points if car_out_points.size() > 0 else _from(car, "out_points"), ["TargetPointCarBOut", "CarBOut"])
	if out_route.is_empty():
		out_route.assign(car_in)
		out_route.reverse()
		out_route.pop_front()   # จุดที่จอดอยู่ตอนนี้
	await car.drive_away(out_route)

	StoryManager.complete_task(task_id)

# ---------- ตัวช่วย ----------
# อ่านเส้นทางที่ลากใส่ไว้ในช่อง Inspector ของ CarB / CustomerNPCB เอง
func _from(obj: Object, prop: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if obj == null:
		return out
	var v = obj.get(prop)
	if v is Array:
		for n in v:
			if n is Node3D:
				out.append(n)
	return out

# ถ้าลากใส่ Inspector ใช้ตามนั้น ไม่งั้นหา Marker3D ชื่อ "<prefix><เลข>" ในแมพ เรียงตามเลข
# (TargetPointCarB1 ไม่ปนกับ TargetPointCarBOut1 เพราะหลัง prefix ต้องเป็นตัวเลขล้วน)
func _points(exported: Array[Node3D], prefixes: Array[String]) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in exported:
		if n != null:
			out.append(n)
	if out.size() > 0:
		return out
	var re := RegEx.create_from_string("^(%s)\\d+$" % "|".join(prefixes))
	for child in get_parent().get_children():
		if child is Marker3D and re.search(str(child.name)) != null:
			out.append(child)
	out.sort_custom(func(a: Node3D, b: Node3D): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out

# แสดงบทสนทนาทีละบรรทัด auto = เปลี่ยนเองตามเวลา / ไม่ auto = กด E
func _run_lines(lines: Array, auto: bool) -> void:
	for line in lines:
		DialogueUi.show_dialogue(line[0], line[1])
		if auto:
			await get_tree().create_timer(maxf(2.5, str(line[1]).length() * 0.09)).timeout
		else:
			_waiting = true
			await _advance
			_waiting = false
	DialogueUi.hide_dialogue()

func _input(event: InputEvent) -> void:
	if not _waiting or not event.is_action_pressed("interact", false):
		return
	get_viewport().set_input_as_handled()
	if DialogueUi.is_typing:
		DialogueUi.finish_typing()
	else:
		_advance.emit()
