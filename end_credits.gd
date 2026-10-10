extends CanvasLayer
## เครดิตท้ายเกม เลื่อนจากล่างขึ้นบน จบแล้วปล่อยสัญญาณ finished
## ใช้: var c = load("res://end_credits.gd").new(); add_child(c); await c.finished

signal finished

@export var scroll_speed: float = 70.0      ## พิกเซลต่อวินาที
@export var fade_in_time: float = 1.2
@export var skip_after: float = 3.0         ## กดข้ามได้หลังผ่านไปกี่วินาที (กันเผลอคลิกตอนจบการสู้)
@export_multiline var credits_text: String = "CLOSING TIME\n\n\nThanks for playing\n\n\nCreated by\n\nNattaphum Phadnok\nSirawit Niyomwong\nChunchak Srichanto"

var _bg: ColorRect
var _holder: Control
var _box: VBoxContainer
var _scroll: Tween
var _age := 0.0
var _done := false

func _ready() -> void:
	layer = 90
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.clip_contents = true
	_bg.add_child(_holder)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_box)

	var first := true
	for line in credits_text.split("\n"):
		if line.strip_edges() == "":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 26)
			_box.add_child(sp)
			continue
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 58 if first else 28)
		l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		_box.add_child(l)
		first = false

	await get_tree().process_frame
	await get_tree().process_frame
	_start_scroll()

func _start_scroll() -> void:
	var vp := get_viewport().get_visible_rect().size
	var h := _box.get_combined_minimum_size().y
	_box.size = Vector2(vp.x, h)
	_box.position = Vector2(0, vp.y)

	var fade := create_tween()
	fade.tween_property(_bg, "color:a", 1.0, fade_in_time)

	var dist := vp.y + h + 40.0
	_scroll = create_tween()
	_scroll.tween_property(_box, "position:y", -h - 40.0, dist / maxf(1.0, scroll_speed))
	_scroll.tween_callback(_finish)

func _process(delta: float) -> void:
	_age += delta

func _input(event: InputEvent) -> void:
	if _done or _age < skip_after:
		return
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton) \
		and event.is_pressed() and not event.is_echo()
	if pressed:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if _scroll and _scroll.is_valid():
		_scroll.kill()
	var t := create_tween()
	t.tween_property(_box, "modulate:a", 0.0, 0.8)
	await t.finished
	finished.emit()
