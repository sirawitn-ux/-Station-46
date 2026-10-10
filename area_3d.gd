extends Area3D
# จุดโต้ตอบทั่วไป: ไม่รู้ว่ากดแล้วต้องทำอะไร แค่ส่งสัญญาณ activated
# แมพเป็นคนเชื่อมสัญญาณแล้วตัดสินใจเอง (ไปฉากไหน ตั้งธงอะไร)

signal activated

## ป้าย [E] ถ้าเว้นว่าง จะหา Label3D ที่ชื่อ "Label3D" ในโหนดแม่ให้เอง
@export var label_node: Label3D
## แมพสั่งปิดได้ เช่นยังไม่ถึงเวลาขึ้นรถ ป้ายจะซ่อนและกดไม่ติด
@export var enabled: bool = true:
	set(value):
		enabled = value
		_refresh_label()

var player_in_range: bool = false
var _player: Node3D = null

func _ready() -> void:
	if label_node == null:
		label_node = get_parent().get_node_or_null("Label3D")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_label()

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("Player"):
		player_in_range = true
		_player = body
		_refresh_label()

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("Player"):
		player_in_range = false
		_player = null
		_refresh_label()

func _refresh_label() -> void:
	if label_node:
		label_node.visible = enabled and player_in_range

func _unhandled_input(event: InputEvent) -> void:
	if not (enabled and player_in_range and event.is_action_pressed("interact")):
		return
	# กำลังคุย/โดนล็อกอยู่ ห้ามกดติด (กัน E ที่ใช้ปิดบทสนทนาไปเรียกขึ้นรถ)
	if DialogueUi.panel.visible:
		return
	if _player and "can_move" in _player and not _player.can_move:
		return
	activated.emit()
	
