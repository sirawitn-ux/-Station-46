extends CanvasLayer
# แปะสคริปต์นี้ที่โหนดราก "SceneTransition" ใน scene_transition.tscn
# (Autoload อยู่แล้ว ไม่ต้องลงทะเบียนเพิ่ม)

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var rect: ColorRect = $ColorRect

func _ready() -> void:
	layer = 100   # ให้อยู่เหนือ UI ทุกอย่าง
	# ColorRect ในฉากกว้างแค่ 1201x702 ตายตัว ทำให้เต็มจอทุกขนาดหน้าต่าง
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out() -> void:
	anim.play("Fade Out")
	await anim.animation_finished

func fade_in() -> void:
	anim.play("Fade In")
	await anim.animation_finished

# เฟสจอดำ -> เปลี่ยนฉาก -> เฟสจอสว่างขึ้น ในคำสั่งเดียว
func change_scene(path: String) -> void:
	await fade_out()
	get_tree().change_scene_to_file(path)
	# รอให้ฉากใหม่โหลดเสร็จก่อนค่อยเฟสกลับ
	await get_tree().process_frame
	await get_tree().process_frame
	fade_in()
