extends Node3D
# ภารกิจเติมของ (วันที่ 1 หลังวาเนสขับรถออกไป)
# - เดินไปหยิบของที่ห้องเก็บของหลังร้าน (กด E 1 ครั้ง) -> ถือได้ทีละ 1 กล่อง
# - เดินไปเติมที่ชั้นวางที่ระบบบอก (มีป้ายลอยอยู่ + ข้อความมุมซ้ายบน) -> กด E รัวๆ จนหลอดเต็ม
# - เติมครบ total_restocks ครั้ง -> งาน "restock" เสร็จ
#
# วิธีวาง: ลากฉาก restock_task.tscn ไปไว้ใน Map_1 แล้วย้าย Marker3D
#   StockPoint        = จุดที่ยืนหยิบของ (ในห้องเก็บของ)
#   Shelf1 .. Shelf6  = จุดที่ยืนเติมของหน้าชั้นวางแต่ละชั้น (เติมตามลำดับเลข)
# ช่องว่างบนชั้น (ไม่ต้องย้ายโหนดเองแล้ว):
#   สคริปต์จะหาโมเดลของชิ้นเล็กๆ ที่วางอยู่รอบๆ Marker ShelfN เอง (ดู "ค้นหาของบนชั้นอัตโนมัติ")
#   แล้วสุ่มซ่อนบางส่วนตอนเริ่มเกม ชั้นจึงดูมีช่องว่าง พอกด E เติม ของจะโผล่กลับมาทีละชิ้น
#   ย้าย Marker ShelfN ให้อยู่ใกล้ชั้นที่ต้องการ (ใกล้ๆ ตำแหน่งยืน) ก็พอ
# ถ้าอยากคุมเอง: ใส่ Node3D ชื่อ Items ไว้ใต้ ShelfN แล้วเอาของที่จะให้หายเป็นลูกของมัน
#   (ถ้ามี Items อยู่ จะใช้ Items แทนการหาอัตโนมัติสำหรับชั้นนั้น)

## ชื่องาน (ต้องตรงกับใน DAY_PLAN ของ StoryManager)
@export var task_id: String = "restock"
## งานที่ต้องเสร็จก่อนภารกิจนี้จะเริ่ม (วาเนสกลับบ้านแล้ว)
@export var after_task_id: String = "talk_manager_leave"
## เติมกี่ครั้งถึงจะจบ
@export var total_restocks: int = 6
## หน่วงกี่วินาทีหลังรถหายไป ก่อนเริ่มภารกิจ
@export var start_delay: float = 1.5

@export_group("ชื่อชั้นวาง (เรียงตาม Shelf1, Shelf2, ...)")
## เช่น ["ชั้นขนมใกล้ประตู", "ตู้แช่ด้านขวา"] เว้นว่าง = ใช้ "ชั้นวางที่ N"
@export var shelf_labels: PackedStringArray = []

@export_group("เสียง (ลากไฟล์เสียงมาใส่)")
## เสียงตอนหยิบกล่อง
@export var snd_pickup: AudioStream
## เสียงตอนใส่ของ เล่นทุกครั้งที่กด E ระหว่างเติม
@export var snd_place: AudioStream
## เสียงตอนเติมเสร็จ 1 ชั้น
@export var snd_complete: AudioStream

@export_group("มินิเกมเติมของ")
## กด E 1 ครั้งหลอดขึ้นเท่าไหร่ (1.0 = เต็ม) 0.08 = กดประมาณ 13 ครั้ง
@export var fill_per_press: float = 0.08
## หลอดลดลงเองต่อวินาที ถ้าหยุดกด (0 = ไม่ลด)
@export var decay_per_second: float = 0.10
## ยืนใกล้จุดกี่เมตรถึงจะกด E ได้
@export var interact_radius: float = 1.6

@export_group("ค้นหาของบนชั้นอัตโนมัติ")
## เปิด = หาของรอบๆ Marker ShelfN แล้วซ่อนบางส่วนเป็นช่องว่าง
@export var auto_find_items: bool = true
## หาของในรัศมีกี่เมตรจาก Marker (แนวราบ) ถ้าไม่เจอของ/เจอน้อยไปให้เพิ่ม
@export var item_radius: float = 1.6
## หาของสูงจากพื้น Marker ขึ้นไปกี่เมตร (และต่ำลงไปได้ 0.5)
@export var item_height: float = 2.2
## ชิ้นที่ใหญ่กว่านี้ (เมตร ด้านที่ยาวสุด) ไม่นับเป็นของ เช่น ตัวชั้น ตู้ ผนัง
@export var max_item_size: float = 0.6
## สัดส่วนของที่ซ่อนเป็นช่องว่าง (0.7 = 70%)
@export_range(0.05, 1.0) var empty_fraction: float = 0.7
## ซ่อนได้ไม่เกินกี่ชิ้นต่อชั้น
@export var max_empty_items: int = 30
## ถ้าใส่ชื่อ จะนับเฉพาะโหนดที่ชื่อมีคำเหล่านี้ เช่น ["Cookies","Box","Bottle"] (ว่าง = ทุกชื่อ)
@export var item_name_contains: PackedStringArray = []

@export_group("ป้ายลอย")
@export var hint_height: float = 1.8
@export var hint_through_walls: bool = true

var _active: bool = false
var _busy: bool = false
var _count: int = 0
var _stock: Node3D
var _shelves: Array[Node3D] = []
var _player: Node3D
var _game: FillGame

var _objective: Label
var _prompt: Label
var _hint: Label3D
var _auto_items: Dictionary = {}   # Shelf(Node3D) -> Array[Node3D]

func _ready() -> void:
	_collect_points()
	if _stock == null or _shelves.is_empty():
		push_warning("RestockTask: ต้องมี Marker3D ชื่อ StockPoint และ Shelf1, Shelf2, ... เป็นลูกของโหนดนี้")
		set_process(false)
		set_process_input(false)
		return
	_build_hud()
	_build_hint()
	if auto_find_items:
		_build_auto_items()
	for s in _shelves:
		_set_items_visible(s, false)

	# Map_1 เรียก StoryManager.begin_map() ใน _ready ของตัวเอง ซึ่งรันหลังลูกๆ จึงต้องรอ 1 เฟรม
	await get_tree().process_frame

	_count = int(StoryManager.flags.get(_count_key(), 0))
	for i in mini(_count, total_restocks):
		_set_items_visible(_shelf_for_round(i), true)

	if not StoryManager.is_task_pending(task_id):
		set_process(false)
		set_process_input(false)
		return

	if StoryManager.is_task_done(after_task_id):
		_activate()
	else:
		StoryManager.task_done.connect(_on_task_done)

func _collect_points() -> void:
	_stock = get_node_or_null("StockPoint") as Node3D
	_shelves.clear()
	for c in get_children():
		if c is Node3D and str(c.name).begins_with("Shelf"):
			_shelves.append(c as Node3D)
	_shelves.sort_custom(func(a: Node3D, b: Node3D): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)

func _on_task_done(id: String) -> void:
	if id == after_task_id:
		_wait_car_then_start()

# รอให้รถออกไปจนหายจากฉากก่อน แล้วค่อยเริ่มภารกิจ
func _wait_car_then_start() -> void:
	var car: Node = get_tree().current_scene.get_node_or_null("CarA")
	if car != null and is_instance_valid(car):
		await car.tree_exited
	await get_tree().create_timer(start_delay).timeout
	_activate()

func _activate() -> void:
	_active = true
	_refresh_objective()

# ---------- ตัวช่วย ----------
func _count_key() -> String:
	return "restock_count_%d" % StoryManager.current_day

func _shelf_for_round(i: int) -> Node3D:
	return _shelves[i % _shelves.size()]

func _target_shelf() -> Node3D:
	return _shelf_for_round(_count)

func _shelf_name(i: int) -> String:
	var idx := i % _shelves.size()
	if idx < shelf_labels.size() and shelf_labels[idx] != "":
		return shelf_labels[idx]
	return "Shelf %d" % (idx + 1)

func _carry_key() -> String:
	return "restock_carry_%d" % StoryManager.current_day

func _carrying() -> bool:
	return bool(StoryManager.flags.get(_carry_key(), false))

# หาโมเดลของชิ้นเล็กๆ รอบ Marker แต่ละชั้น (ชิ้นหนึ่งสังกัด Marker ที่ใกล้ที่สุด) แล้วสุ่มเลือกบางส่วนเป็นช่องว่าง
func _build_auto_items() -> void:
	var root: Node = self
	while root.get_parent() != null and root.get_parent() != get_tree().root:
		root = root.get_parent()

	var groups: Dictionary = {}
	for s in _shelves:
		if s.get_node_or_null("Items") == null:
			groups[s] = []
	if groups.is_empty():
		return

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == self:
			continue
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		if not _name_ok(str(mi.name)):
			continue
		var aabb := mi.mesh.get_aabb()
		var sc := mi.global_transform.basis.get_scale().abs()
		var size := Vector3(aabb.size.x * sc.x, aabb.size.y * sc.y, aabb.size.z * sc.z)
		if maxf(size.x, maxf(size.y, size.z)) > max_item_size:
			continue
		var center := mi.global_transform * aabb.get_center()
		var best: Node3D = null
		var best_d := INF
		for s in groups.keys():
			var d: Vector3 = center - (s as Node3D).global_position
			var flat := Vector2(d.x, d.z).length()
			if flat <= item_radius and d.y >= -0.5 and d.y <= item_height and flat < best_d:
				best_d = flat
				best = s
		if best != null:
			groups[best].append(mi)

	for s in groups.keys():
		var list: Array = groups[s]
		if list.is_empty():
			push_warning("RestockTask: ไม่เจอของใกล้ %s — ลองย้าย Marker ให้ใกล้ชั้น หรือเพิ่ม item_radius / max_item_size" % (s as Node).name)
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str((s as Node).name))
		# สับลำดับแบบคงที่ (รีโหลดฉากแล้วช่องว่างอยู่ที่เดิม)
		for i in range(list.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = list[i]
			list[i] = list[j]
			list[j] = tmp
		var take := clampi(int(round(list.size() * empty_fraction)), 1, max_empty_items)
		take = mini(take, list.size())
		var picked: Array[Node3D] = []
		for i in take:
			picked.append(list[i] as Node3D)
		_auto_items[s] = picked
		print("RestockTask: %s พบของ %d ชิ้น ซ่อนเป็นช่องว่าง %d ชิ้น" % [(s as Node).name, list.size(), take])

func _name_ok(n: String) -> bool:
	if item_name_contains.is_empty():
		return true
	for key in item_name_contains:
		if key != "" and n.containsn(key):
			return true
	return false

# ของแต่ละชิ้นที่ต้องเติมบนชั้นนี้ (หาอัตโนมัติ หรือลูกของ Items ถ้าไม่มีลูกจะนับ Items เองเป็น 1 ชิ้น)
func _shelf_items(shelf: Node3D) -> Array[Node3D]:
	if _auto_items.has(shelf):
		return _auto_items[shelf]
	var out: Array[Node3D] = []
	var items := shelf.get_node_or_null("Items") as Node3D
	if items == null:
		return out
	for c in items.get_children():
		if c is Node3D:
			out.append(c as Node3D)
	if out.is_empty():
		out.append(items)
	return out

func _set_items_visible(shelf: Node3D, value: bool) -> void:
	var items := shelf.get_node_or_null("Items") as Node3D
	if items != null:
		items.visible = true
	for it in _shelf_items(shelf):
		it.visible = value

# โชว์ของทีละชิ้นตามความคืบหน้า (0..1) พร้อมเด้งเล็กน้อย
func _reveal_items(shelf: Node3D, progress: float) -> void:
	var list := _shelf_items(shelf)
	var n := int(floor(progress * list.size() + 0.0001))
	for i in mini(n, list.size()):
		var it := list[i]
		if it.visible:
			continue
		it.visible = true
		var base := it.scale
		it.scale = base * 0.5
		create_tween().tween_property(it, "scale", base, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _near(p: Node3D) -> bool:
	if p == null:
		return false
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node3D
		if _player == null:
			return false
	var d := _player.global_position - p.global_position
	return Vector2(d.x, d.z).length() <= interact_radius and absf(d.y) < 3.0

func _set_player_can_move(value: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("set_can_move"):
		player.set_can_move(value)

func _play(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ---------- HUD ----------
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
	_hint.top_level = true   # ไม่ให้ป้ายยืดตามสเกลของโหนดแม่
	add_child(_hint)

func _refresh_objective() -> void:
	if not _active:
		_objective.visible = false
		return
	var text := "Task: Restock (%d/%d)\n" % [_count, total_restocks]
	if _carrying():
		text += "Take the stock to: %s (follow the yellow marker)" % _shelf_name(_count)
	else:
		text += "Go pick up stock in the back room (follow the yellow marker)"
	_objective.text = text
	_objective.visible = true

func _process(_delta: float) -> void:
	if not _active or _busy:
		_prompt.visible = false
		_hint.visible = false
		return

	var carrying := _carrying()
	var target: Node3D = _target_shelf() if carrying else _stock

	# ป้ายลอยบอกจุดหมาย
	_hint.text = ("Restock here\n%s\nV" % _shelf_name(_count)) if carrying else "Pick up stock here\nV"
	_hint.global_position = target.global_position + Vector3(0, hint_height, 0)
	_hint.visible = true

	# ข้อความกด E
	var msg := ""
	if _near(_stock) and not carrying:
		msg = "[E] Pick up stock"
	elif _near(_stock) and carrying:
		msg = "You're already carrying stock. Take it to %s" % _shelf_name(_count)
	elif carrying and _near(_target_shelf()):
		msg = "[E] Restock (mash it!)"
	elif not carrying:
		for s in _shelves:
			if _near(s):
				msg = "Pick up stock from the back room first"
				break
	else:
		for s in _shelves:
			if _near(s) and s != _target_shelf():
				msg = "This isn't the shelf to restock. Go to %s" % _shelf_name(_count)
				break

	_prompt.text = msg
	_prompt.visible = msg != "" and not DialogueUi.panel.visible

# ---------- รับปุ่ม ----------
func _input(event: InputEvent) -> void:
	if not _active:
		return

	# ระหว่างมินิเกม: กด E = เติม
	if _game != null:
		if event.is_action_pressed("interact", false):
			get_viewport().set_input_as_handled()
			_game.press()
		return

	if _busy or not event.is_action_pressed("interact", false):
		return
	if DialogueUi.panel.visible:
		return

	if _near(_stock) and not _carrying():
		_pickup()
	elif _carrying() and _near(_target_shelf()):
		_start_fill()

func _pickup() -> void:
	StoryManager.flags[_carry_key()] = true
	_play(snd_pickup)
	_refresh_objective()

func _start_fill() -> void:
	_busy = true
	_set_player_can_move(false)

	_game = FillGame.new()
	_game.fill_per_press = fill_per_press
	_game.decay_per_second = decay_per_second
	_game.pressed.connect(func(): _play(snd_place, randf_range(0.95, 1.05)))
	var shelf := _target_shelf()
	_game.progressed.connect(func(p: float): _reveal_items(shelf, p))
	get_tree().current_scene.add_child(_game)
	await _game.finished
	_game = null

	_set_player_can_move(true)
	StoryManager.flags[_carry_key()] = false
	_set_items_visible(shelf, true)
	_count += 1
	StoryManager.flags[_count_key()] = _count
	_play(snd_complete)

	if _count >= total_restocks:
		_objective.text = "All shelves restocked! (%d/%d)" % [_count, total_restocks]
		await get_tree().create_timer(3.0).timeout
		_active = false
		_objective.visible = false
		_busy = false
		StoryManager.complete_task(task_id)
		return

	_busy = false
	_refresh_objective()

# ==========================================
# มินิเกม: กด E รัวๆ จนหลอดเต็ม (สร้างหน้าจอด้วยโค้ด ไม่ต้องทำ Scene เพิ่ม)
# ==========================================
class FillGame extends CanvasLayer:
	signal pressed
	signal progressed(peak: float)
	signal finished

	var fill_per_press: float = 0.08
	var decay_per_second: float = 0.10

	var _value: float = 0.0
	var _peak: float = 0.0
	var _done: bool = false
	var _bar: ProgressBar
	var _hint_label: Label

	func _ready() -> void:
		layer = 90

		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.5)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(520, 200)
		center.add_child(panel)

		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 24)
		panel.add_child(margin)

		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 14)
		margin.add_child(box)

		var title := Label.new()
		title.text = "Restock the Shelf"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 30)
		box.add_child(title)

		_hint_label = Label.new()
		_hint_label.text = "Mash E until the bar is full!"
		_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint_label.add_theme_font_size_override("font_size", 22)
		box.add_child(_hint_label)

		_bar = ProgressBar.new()
		_bar.min_value = 0.0
		_bar.max_value = 1.0
		_bar.step = 0.001
		_bar.value = 0.0
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(0, 30)
		box.add_child(_bar)

	func press() -> void:
		if _done:
			return
		_value = minf(_value + fill_per_press, 1.0)
		_bar.value = _value
		_peak = maxf(_peak, _value)
		progressed.emit(_peak)
		pressed.emit()
		_bar.modulate = Color(1.5, 1.5, 1.5)
		create_tween().tween_property(_bar, "modulate", Color.WHITE, 0.12)
		if _value >= 1.0:
			_finish()

	func _process(delta: float) -> void:
		if _done:
			return
		_value = maxf(_value - decay_per_second * delta, 0.0)
		_bar.value = _value

	func _finish() -> void:
		_done = true
		_hint_label.text = "Restocked!"
		await get_tree().create_timer(0.5).timeout
		finished.emit()
		queue_free()
