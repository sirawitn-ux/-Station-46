extends CanvasLayer

# Node References
@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/MarginContainer/VBoxContainer/Label
@onready var text_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/RichTextLabel
@onready var interact_label: Label = $Label # Label บอกปุ่มกดข้างบน

var is_typing: bool = false

func _ready() -> void:
	panel.hide() # ซ่อนกล่องข้อความสนทนาตอนเริ่มเกม
	hide_prompt() # ซ่อน Label ปุ่มกดตอนเริ่มเกม

# ==========================================
# ระบบป้ายบอกปุ่มกด (Press [E] to Talk Prompt)
# ==========================================

func show_prompt(msg: String = "Press [E] to Talk") -> void:
	# ถ้ากำลังคุยบทสนทนาอยู่ ไม่ต้องโชว์ Label บอกปุ่มกด
	if panel.visible:
		hide_prompt()
		return
		
	if interact_label.visible and interact_label.text == msg:
		return
		
	interact_label.text = msg
	interact_label.visible = true
	interact_label.modulate.a = 1.0 # ตั้งค่าให้สว่างนิ่งๆ ไม่ต้องวิ่งอนิเมชัน

func hide_prompt() -> void:
	if interact_label:
		interact_label.visible = false

# ==========================================
# ระบบบทสนทนา (Dialogue System)
# ==========================================

func show_dialogue(speaker_name: String, text_content: String) -> void:
	hide_prompt() # ซ่อนป้ายกดทันทีเมื่อเริ่มคุย
	panel.show()
	
	# ล็อกไม่ให้ผู้เล่นเดินขณะเปิดบทสนทนา (ใช้คำสั่งเดิมของคุณ)
	get_tree().call_group("Player", "set", "can_move", false)
	
	name_label.text = speaker_name
	text_label.text = text_content
	
	# ทำ Typewriter Effect
	text_label.visible_characters = 0
	is_typing = true
	
	for i in range(text_content.length()):
		if not is_typing:
			break
		text_label.visible_characters = i + 1
		await get_tree().create_timer(0.03).timeout
		
	text_label.visible_characters = -1
	is_typing = false

func finish_typing() -> void:
	is_typing = false
	text_label.visible_characters = -1

func hide_dialogue() -> void:
	panel.hide()
	# ปลดล็อกให้ผู้เล่นเดินได้ (ใช้คำสั่งเดิมของคุณ)
	get_tree().call_group("Player", "set", "can_move", true)

# ==========================================
# ระบบตัวเลือก (Choice System)
# ใช้: var picked: int = await DialogueUi.show_choices(["หนี", "สู้"])
# คืนค่าเป็นลำดับตัวเลือกที่กด (เริ่มที่ 0)
# ==========================================
signal choice_made(index: int)

var _choice_box: VBoxContainer

func show_choices(options: Array[String]) -> int:
	hide_prompt()
	hide_dialogue()
	get_tree().call_group("Player", "set", "can_move", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_choice_box = VBoxContainer.new()
	_choice_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_choice_box.add_theme_constant_override("separation", 14)
	add_child(_choice_box)

	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.custom_minimum_size = Vector2(320, 56)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(func() -> void: choice_made.emit(i))
		_choice_box.add_child(b)

	var picked: int = await choice_made
	_choice_box.queue_free()
	_choice_box = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return picked
