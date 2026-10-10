extends Node3D
# ภารกิจเก็บขยะ -> นำไปทิ้ง
# วาง Marker3D 2 ตัวเป็นลูกของ TrashTask:
#   PickupPoint   = จุดหยิบขยะ
#   TrashBinPoint = จุดทิ้งขยะ
#
# ทั้งสองจุดต้องกด E เมื่อเข้าใกล้

const HERO := "Big Judy"

@export var task_id: String = "trash"
@export var after_task_id: String = "customer_a"

@export_group("จุดภารกิจ")
@export var pickup_point: Node3D
@export var trash_bin_point: Node3D
@export var interact_radius: float = 1.8

@export_group("ป้าย")
@export var hint_height: float = 1.8
@export var hint_through_walls: bool = true

@export_group("ข้อความ")
@export var pickup_text: String = "[E] Pick up trash"
@export var dispose_text: String = "[E] Throw away trash"

var _active := false
var _busy := false
var _has_trash := false
var _started := false

var _objective: Label
var _prompt: Label
var _hint: Label3D
var _player: Node3D
var _killer_cutscene: Node

func _ready() -> void:
	# ถ้าไม่ได้ลาก Marker ใน Inspector ให้หาเองจากชื่อตามที่กำหนด
	if pickup_point == null:
		pickup_point = get_node_or_null("PickupPoint")
	if trash_bin_point == null:
		trash_bin_point = get_node_or_null("TrashBinPoint")

	if pickup_point == null or trash_bin_point == null:
		push_warning("TrashTask: ต้องมี Marker3D ชื่อ PickupPoint และ TrashBinPoint")
		set_process(false)
		set_process_input(false)
		return

	_build_hud()
	_build_hint()
	_killer_cutscene = get_node_or_null("KillerCutscene")

	# Map_1 เรียก begin_map() ที่ _ready ของตัวเอง จึงรอ 1 เฟรม
	await get_tree().process_frame

	if not StoryManager.is_task_pending(task_id):
		set_process(false)
		set_process_input(false)
		return

	if StoryManager.is_task_done(after_task_id):
		_begin()
	else:
		StoryManager.task_done.connect(_on_task_done)

func _on_task_done(id: String) -> void:
	if id == after_task_id:
		_begin()

func _begin() -> void:
	if _started:
		return
	_started = true
	_active = true
	_refresh_objective()

func _near(point: Node3D) -> bool:
	if point == null:
		return false

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return false

	var d := _player.global_position - point.global_position
	return Vector2(d.x, d.z).length() <= interact_radius and absf(d.y) < 3.0

func _find_player() -> Node3D:
	for n in get_tree().get_nodes_in_group("Player"):
		if n is Node3D and n.has_method("set_can_move"):
			return n
	return null

func _set_player_can_move(value: bool) -> void:
	var pl := _find_player()
	if pl:
		pl.set_can_move(value)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)

	_objective = Label.new()
	_objective.position = Vector2(24, 24)
	_objective.add_theme_font_size_override("font_size", 22)
	_objective.add_theme_constant_override("outline_size", 8)
	_objective.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective.visible = false
	layer.add_child(_objective)

	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.75
	_prompt.anchor_bottom = 0.75
	_prompt.offset_left = -350
	_prompt.offset_right = 350
	_prompt.offset_top = -20
	_prompt.offset_bottom = 20
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 26)
	_prompt.add_theme_constant_override("outline_size", 10)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.visible = false
	layer.add_child(_prompt)

func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.font_size = 64
	_hint.pixel_size = 0.005
	_hint.outline_size = 14
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.no_depth_test = hint_through_walls
	_hint.modulate = Color(1.0, 0.9, 0.3)
	_hint.visible = false
	_hint.top_level = true
	add_child(_hint)

func _refresh_objective() -> void:
	if not _active:
		_objective.visible = false
		return

	if not _has_trash:
		_objective.text = "Task: Collect the trash\nGo to the trash pickup point (follow the yellow marker)"
	else:
		_objective.text = "Task: Dispose of the trash\nTake it to the trash can (follow the yellow marker)"
	_objective.visible = true

func _process(_delta: float) -> void:
	if not _active or _busy:
		_prompt.visible = false
		_hint.visible = false
		return

	var target := trash_bin_point if _has_trash else pickup_point

	if target == null:
		return

	if _has_trash:
		_hint.text = "Throw it away here\nV"
	else:
		_hint.text = "Pick up trash here\nV"

	_hint.global_position = target.global_position + Vector3(0, hint_height, 0)
	_hint.visible = true

	var msg := ""
	if _near(target):
		msg = dispose_text if _has_trash else pickup_text

	_prompt.text = msg
	_prompt.visible = msg != "" and not DialogueUi.panel.visible

func _input(event: InputEvent) -> void:
	if not _active or _busy:
		return
	if not event.is_action_pressed("interact", false):
		return
	if DialogueUi.panel.visible:
		return

	var target := trash_bin_point if _has_trash else pickup_point
	if _near(target):
		get_viewport().set_input_as_handled()
		_complete_step()

func _complete_step() -> void:
	_busy = true
	_set_player_can_move(false)

	if not _has_trash:
		# เก็บขยะ
		_has_trash = true
		await _say_lines([
			[HERO, "Okay... let's grab the trash first."],
		])
		_set_player_can_move(true)
		_busy = false
		_refresh_objective()
		return

	# ทิ้งขยะ
	await _say_lines([
		[HERO, "Alright... let's go throw this out properly."],
		[HERO, "Done!"],
	])

	_objective.text = "Trash taken out!"
	_hint.visible = false
	_prompt.visible = false
	_active = false
	_objective.visible = false

	# ต่อเข้าซีนฆาตกรทันทีหลังทิ้งขยะ
	if _killer_cutscene != null and _killer_cutscene.has_method("start_sequence"):
		_busy = true
		await _killer_cutscene.start_sequence()
	else:
		# ถ้าไม่ได้วาง KillerCutscene ไว้ ให้เกมทำงานต่อได้ตามปกติ
		_set_player_can_move(true)

	_busy = false
	StoryManager.complete_task(task_id)

func _say_lines(lines: Array) -> void:
	for line in lines:
		DialogueUi.show_dialogue(line[0], line[1])
		await get_tree().create_timer(maxf(2.0, str(line[1]).length() * 0.07)).timeout
	DialogueUi.hide_dialogue()
