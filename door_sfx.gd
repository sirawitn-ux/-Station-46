extends RefCounted
## สร้างเสียงประตู (เอี๊ยดตอนเปิด / ตึงตอนปิด) จากโค้ด ไม่ต้องใช้ไฟล์เสียง
## ใช้จาก door_pivot*.gd: DoorSfx.open_sound() / DoorSfx.close_sound()

const RATE := 22050

static var _open_cache: AudioStreamWAV
static var _close_cache: AudioStreamWAV

static func open_sound() -> AudioStreamWAV:
	if _open_cache == null:
		_open_cache = _make_open()
	return _open_cache

static func close_sound() -> AudioStreamWAV:
	if _close_cache == null:
		_close_cache = _make_close()
	return _close_cache

static func _to_wav(data: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for v in data:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

# เปิด: คลิกสลักสั้น ๆ แล้วเสียงบานพับเอี๊ยดค่อย ๆ ไล่ระดับ
static func _make_open() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var dur := 0.7
	var n := int(RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	var phase := 0.0
	var smooth := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq := 150.0 + 90.0 * sin(PI * t / dur) + 6.0 * sin(TAU * 18.0 * t)
		phase += TAU * freq / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		smooth += (saw - smooth) * 0.25
		var env := pow(sin(PI * t / dur), 1.5) * 0.5
		var nz := rng.randf() * 2.0 - 1.0
		lp += (nz - lp) * 0.08
		var click := nz * exp(-t * 300.0) * 0.8
		data[i] = smooth * env * 0.9 + lp * env * 0.8 + click
	return _to_wav(data)

# ปิด: เสียงกระแทกทุ้ม ๆ + คลิกสลัก
static func _make_close() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	var dur := 0.4
	var n := int(RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq := 50.0 + 70.0 * exp(-t * 25.0)
		phase += TAU * freq / RATE
		var nz := rng.randf() * 2.0 - 1.0
		lp += (nz - lp) * 0.15
		var thud := sin(phase) * exp(-t * 11.0)
		var body := lp * exp(-t * 22.0) * 0.6
		var click := nz * exp(-t * 450.0) * 0.5
		data[i] = thud + body + click
	return _to_wav(data)
