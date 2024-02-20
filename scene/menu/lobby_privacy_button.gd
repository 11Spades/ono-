extends MenuButton


var active: int = 0


func _ready() -> void:
	get_popup().id_pressed.connect(_on_id_pressed)
	
	return

func _on_id_pressed(id: int) -> void:
	get_popup().set_item_checked(active, false);
	
	active = id
	text = get_popup().get_item_text(active)
	get_popup().set_item_checked(active, true)
	
	return
