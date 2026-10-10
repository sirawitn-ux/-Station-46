extends Node3D

@export var player_node: CharacterBody3D

@onready var bus_area: Area3D = $BusStop/Area3D

func _ready() -> void:
	# ไม่ต้องลากผู้เล่นใส่ Inspector: ถ้าว่างอยู่ ให้หาเองจากกลุ่ม Player
	if player_node == null:
		player_node = get_tree().get_first_node_in_group("Player") as CharacterBody3D

	StoryManager.begin_map("map_2")
	bus_area.activated.connect(_on_bus_stop_activated)

	# ธงแยกตามวัน วันละครั้ง
	var key := "intro_day_%d" % StoryManager.current_day
	if StoryManager.has_flag(key):
		_update_bus_stop()
		return   # วันนี้เล่นไปแล้ว ไม่ล็อกผู้เล่นไม่บ่นซ้ำ
	StoryManager.set_flag(key)

	bus_area.enabled = false   # ฉากเปิดเรื่องกำลังเล่น ยังขึ้นรถไม่ได้
	await get_tree().create_timer(0.5).timeout
	match StoryManager.current_day:
		1:
			if player_node and player_node.has_method("set_can_move"):
				player_node.set_can_move(false)
			start_intro_sequence()   # ฉากเปิดเรื่องยาวที่เขียนไว้เดิม
		2:
			start_day2_intro()       # บทของวันที่ 2
		_:
			_update_bus_stop()

func start_intro_sequence() -> void:
	# ช่วงที่ 1: สะท้อนความกดดันจากการตกงานยาวนานและความโล่งใจที่ได้งาน
	DialogueUi.show_dialogue("Big Judy", "Seriously... I sent out dozens of applications and got rejected so many times I was running out of will. And I finally landed a job.")
	await get_tree().create_timer(5.0).timeout

	# ช่วงที่ 2: เผชิญความจริงเรื่องสภาพงาน (กะดึก + ไกลบ้าน) แต่จำเป็นต้องยอมรับ
	DialogueUi.show_dialogue("Big Judy", "Sure, it's a late-night shift, and the gas station is so far out it's practically outside the city... but right now, I can't afford to be picky about any job that pays the bills.")
	await get_tree().create_timer(6.0).timeout

	# ช่วงที่ 3: ความกดดันของการเป็นเด็กใหม่และความตั้งใจจริง
	DialogueUi.show_dialogue("Big Judy", "I'm a total rookie, and I've barely worked in a convenience store before... All I can do is hope tonight goes smoothly. Please, no nightmare customers on my first night.")
	await get_tree().create_timer(5.5).timeout

	# ช่วงที่ 4: สรุปเข้าสู่เกมเพลย์ (ต้องรีบไปป้ายรถเมล์)
	DialogueUi.show_dialogue("Big Judy", "Sigh... enough overthinking. If I keep dawdling, I'll miss the last bus. Being late on day one would put me on the manager's radar for sure. Let's go wait at the bus stop!")
	await get_tree().create_timer(5.0).timeout

	# ปิดกล่องข้อความบทสนทนา
	DialogueUi.hide_dialogue()

	# ปลดล็อกให้ผู้เล่นบังคับตัวละครเดินได้อิสระ
	if player_node and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	_update_bus_stop()
	print("เริ่มเกมอิสระ: เดินไปที่ป้ายรถบัสหน้าปากซอยเพื่อเดินทางไปปั๊มน้ำมันได้เลย!")

func start_day2_intro() -> void:
	if player_node and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

	DialogueUi.show_dialogue("Big Judy", "Day two already, huh... Let's go wait for the bus.")
	await get_tree().create_timer(4.0).timeout

	DialogueUi.hide_dialogue()
	if player_node and player_node.has_method("set_can_move"):
		player_node.set_can_move(true)

	_update_bus_stop()

# ป้ายรถใช้ได้เฉพาะตอนที่วันนี้มีงาน take_bus ค้างอยู่
func _update_bus_stop() -> void:
	bus_area.enabled = StoryManager.is_task_pending("take_bus")

func _on_bus_stop_activated() -> void:
	var next_scene: String = StoryManager.get_plan("map_2").get("next_scene", "")
	if next_scene == "":
		return
	bus_area.enabled = false
	if player_node and player_node.has_method("set_can_move"):
		player_node.set_can_move(false)

	StoryManager.complete_task("take_bus")   # บันทึกว่าวันนี้ขึ้นรถแล้ว สเตปเดินต่อ

	SceneTransition.change_scene(next_scene)   # เฟสจอดำ -> เปลี่ยนฉาก -> เฟสกลับ
