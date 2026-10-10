extends Node3D

@export_file("*.tscn") var target_scene: String = "res://scenes/gas_station.tscn"
@export var prompt_message: String = "Press [E] to take the bus"

var player_in_range: bool = false
var is_traveling: bool = false

func _ready() -> void:
	# เชื่อมต่อ Signal แบบถูกต้องใน Godot 4
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("Player"):
		player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("Player"):
		player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_traveling and event.is_action_pressed("interact"):
		start_travel_sequence()

func start_travel_sequence() -> void:
	is_traveling = true
	print("กำลังขึ้นรถบัส...")

	# ซ่อน Prompt บนหน้าจอ
	if DialogueUi.has_method("hide_prompt"):
		DialogueUi.hide_prompt()

	# ค้นหาผู้เล่นแล้วสั่งล็อกการเดินทันทีระหว่างเฟดจอ
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		player = get_tree().current_scene.get_node_or_null("Player")
		
	if player and player.has_method("set_can_move"):
		player.set_can_move(false)
		print("ล็อกตัวละครเรียบร้อย ระหว่างเฟดหน้าจอ")

	# สั่งเล่นอนิเมชัน Fade หน้าจอมืดลง
	if SceneTransition.has_method("fade_out"):
		SceneTransition.fade_out()
		await get_tree().create_timer(1.0).timeout
	else:
		await get_tree().create_timer(0.5).timeout

	# เปลี่ยนฉากเป้าหมาย
	get_tree().change_scene_to_file(target_scene)
