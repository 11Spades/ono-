extends Control


var name_placard: Resource


func _ready():
	# Connect up our signals
	SteamLobbyManager.lobby_manager_joined_lobby.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_updated)
	get_parent().lobby_offscreen.connect(_on_lobby_left)
	
	# Ready our assets
	name_placard = preload("res://scene/menu/lobby_column_text.tscn")
	
	return


func _on_lobby_joined() -> void:
	for MEMBER in SteamLobbyManager.LOBBY_MEMBERS:
		var placard: Label = name_placard.instantiate()
		placard.text = MEMBER["steam_name"]
		#placard.text = "Spade"
		placard.name = "PlacardLabel" + str(MEMBER["steam_id"])
		$LobbyMembersContainer/LobbyMembersNames.add_child(placard)
		$ChatPaneTextEdit.text += MEMBER["steam_name"] + " joined the lobby."
		#$ChatPaneTextEdit.text += "Spade joined the lobby."
	return


# TODO: Animate people joining and leaving
func _on_lobby_chat_updated(lobby_id: int, change_id: int, making_change_id: int, chat_state: int) -> void:
	var CHANGER: String = Steam.getFriendPersonaName(change_id)
	
	match chat_state:
		1:
			var placard: Label = name_placard.instantiate()
			placard.text = CHANGER
			placard.name = "PlacardLabel" + str(change_id)
			$LobbyMembersContainer/LobbyMembersNames.add_child(placard)
			$ChatPaneTextEdit.text += CHANGER + " joined the lobby."
		_:
			get_node("LobbyMembersContainer/LobbyMembersNames/PlacardLabel" + str(change_id)).queue_free()
			$ChatPaneTextEdit.text += CHANGER + " left the lobby."
	return

func _on_lobby_left() -> void:
	for node in $LobbyMembersContainer/LobbyMembersNames.get_children():
		node.queue_free()
		
	for node in $LobbyRulesContainer/LobbyRules.get_children():
		if (node.name == "LobbyRulesPlacard"):
			continue
	
		node.queue_free()
	return
