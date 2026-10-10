@tool
extends Node3D

@export var fix_now: bool = false:
	set(value):
		if value:
			_clear_old_collisions(self)
			_create_new_collisions(self)
			print("--- แก้ไขสำเร็จแล้ว! ---")

# รอบที่ 1: ไล่ลบ StaticBody3D เก่าออกจาก Editor ทันที
func _clear_old_collisions(node: Node):
	for child in node.get_children():
		_clear_old_collisions(child)
		if child is StaticBody3D:
			child.free()

# รอบที่ 2: สั่งสร้าง Convex Collision ใหม่พร้อมตั้งค่า Owner ให้ Editor รู้จัก
func _create_new_collisions(node: Node):
	for child in node.get_children():
		if child is MeshInstance3D:
			child.create_convex_collision()
			# กำหนด Owner ให้ Collision ตัวใหม่ถูกบันทึกลง Scene จริง
			if child.get_child_count() > 0:
				var new_static = child.get_child(child.get_child_count() - 1)
				new_static.owner = get_tree().edited_scene_root
				for col in new_static.get_children():
					col.owner = get_tree().edited_scene_root
		_create_new_collisions(child)

# ==========================================
# เนื้อเรื่องตอนมาถึงปั๊ม (แมพ 1)
# ==========================================
func _ready() -> void:
	# สคริปต์นี้เป็น @tool จึงต้องกันไม่ให้เนื้อเรื่องรันในหน้าต่าง Editor
	if Engine.is_editor_hint():
		return

	StoryManager.begin_map("map_1")

	# บทตอนมาถึง เล่นครั้งเดียวต่อวัน
	var key := "map1_intro_day_%d" % StoryManager.current_day
	if StoryManager.has_flag(key):
		return

	match StoryManager.current_day:
		1:
			StoryManager.set_flag(key)
			await get_tree().create_timer(0.5).timeout
			_arrival_day1()

func _set_player_can_move(value: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("set_can_move"):
		player.set_can_move(value)

func _arrival_day1() -> void:
	_set_player_can_move(false)

	# ช่วงที่ 1: บ่นเรื่องความไกล
	DialogueUi.show_dialogue("Big Judy", "Finally made it... what a trek. The gas station is so far out, I might as well have left the city. It took forever to get here.")
	await get_tree().create_timer(5.0).timeout

	# ช่วงที่ 2: ความกลัวที่มืดและที่ไร้ผู้คน
	DialogueUi.show_dialogue("Big Judy", "And it's the night shift, too... Pitch black all around, no houses, not a soul walking by. If something happened, nobody would hear me even if I screamed...")
	await get_tree().create_timer(6.0).timeout

	# ช่วงที่ 3: พยายามข่มความกลัว
	DialogueUi.show_dialogue("Big Judy", "Come on... I'm probably just overthinking it. It's just a dark, quiet place. What's there to be so afraid of?")
	await get_tree().create_timer(5.0).timeout

	# ช่วงที่ 4: ปลุกใจตัวเอง
	DialogueUi.show_dialogue("Big Judy", "Alright! Let's do this! I've been out of work for ages and I haven't given up, so this is nothing. Time to go find the manager!")
	await get_tree().create_timer(5.0).timeout

	DialogueUi.hide_dialogue()
	_set_player_can_move(true)
