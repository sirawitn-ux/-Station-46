extends Node

signal inventory_changed(item_name: String, new_amount: int)

# เก็บข้อมูลไอเทมในตัวผู้เล่น เช่น {"milk_tea": 2, "coffee": 1}
var items: Dictionary = {}

# สต็อกของบนชั้นวางแต่ละชั้น เช่น {"/root/Map_1/Shelf1": 3}
# เก็บไว้ที่ Autoload นี้ เพราะ Node ในฉากจะถูกลบทิ้งตอนเปลี่ยนฉาก (เช่นนั่งรถบัส)
# ถ้าเก็บไว้ในชั้นวางเอง ของที่เติมไว้จะหายหมดเวลากลับมา
var shelf_stock: Dictionary = {}

# ฟังก์ชันเช็กว่ามีไอเทมพอไหม
func has_item(item_name: String, amount: int) -> bool:
	return items.get(item_name, 0) >= amount

# จำนวนไอเทมที่ถืออยู่
func get_count(item_name: String) -> int:
	return items.get(item_name, 0)

# ฟังก์ชันเพิ่มไอเทม (เวลาผู้เล่นไปเก็บของหรือทำมา)
func add_item(item_name: String, amount: int) -> void:
	if amount <= 0:
		return
	items[item_name] = items.get(item_name, 0) + amount
	print("เพิ่มไอเทม: ", item_name, " จำนวน: ", amount)
	inventory_changed.emit(item_name, items[item_name])

# ฟังก์ชันลบ/หักไอเทม (ตอนเอาไปส่งให้ NPC หรือเติมเข้าชั้นวาง)
# คืนค่า true ถ้าหักสำเร็จ
func remove_item(item_name: String, amount: int) -> bool:
	if amount <= 0 or not has_item(item_name, amount):
		return false
	items[item_name] -= amount
	if items[item_name] <= 0:
		items.erase(item_name)
	print("หักไอเทม: ", item_name, " จำนวน: ", amount)
	inventory_changed.emit(item_name, get_count(item_name))
	return true

# ---------- สต็อกบนชั้นวาง ----------
func get_shelf_stock(shelf_id: String) -> int:
	return shelf_stock.get(shelf_id, 0)

func set_shelf_stock(shelf_id: String, amount: int) -> void:
	shelf_stock[shelf_id] = max(amount, 0)
