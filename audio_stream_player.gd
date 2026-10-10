extends AudioStreamPlayer

func _ready():
	# เชื่อมสัญญาณเมื่อเสียงเล่นจบ ให้เล่นใหม่ทันที
	finished.connect(_on_audio_finished)
	play()

func _on_audio_finished():
	play()
