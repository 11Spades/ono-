extends Control


var LOBBY_LIST_ENTRY: Resource


func _ready():
	LOBBY_LIST_ENTRY = preload("res://scene/menu/lobby_list_entry.tscn")
	
	# Connect our signals up
	Steam.lobby_match_list.connect(_on_Lobby_Match_List)


func _input(event):
	if event.is_action_pressed("lobby_refresh"):
		for node in $LobbyListContainer/LobbyListEntries.get_children():
			# Run the fly-out animation
			var bounce_tween = create_tween()
			bounce_tween.set_ease(Tween.EASE_OUT)
			bounce_tween.tween_property(node, "position", node.position - Vector2(50, 0), 0.05)
			bounce_tween.set_trans(Tween.TRANS_QUAD)
			bounce_tween.tween_property(node, "position", node.position + Vector2(1920, 0), 0.2)
			bounce_tween.tween_callback(node.queue_free)
			continue
		
		Steam.requestLobbyList()
	return


func _on_Lobby_Match_List(lobbies: Array) -> void:
	for LOBBY in lobbies:
		# Pull lobby data from Steam, these are specific to our example
		var LOBBY_NAME: String = Steam.getLobbyData(LOBBY, "name")
		var LOBBY_MODE: String = Steam.getLobbyData(LOBBY, "mode")
		
		if LOBBY_MODE != "ono":
			continue

		# Get the current number of members
		var LOBBY_NUM_MEMBERS: int = Steam.getNumLobbyMembers(LOBBY)

		# Create an entry for the lobby
		var LobbyEntry = LOBBY_LIST_ENTRY.instantiate()
		LobbyEntry.get_node("LobbyName").set_text(str(LOBBY_NAME))
		LobbyEntry.get_node("LobbyPlayerCount").set_text(str(LOBBY_NUM_MEMBERS))
		LobbyEntry.get_node("LobbyJoinButton").set_meta("lobby_id", LOBBY)
		
		# Connect the join buttons to components that need them
		get_parent().connect_new_lobby_button(LobbyEntry.get_node("LobbyJoinButton"))

		# Add the new lobby to the list
		$LobbyListContainer/LobbyListEntries.add_child(LobbyEntry)
		
		# Run the fly-in animation
		var ending_position = LobbyEntry.position
		var bounce_tween = create_tween()
		bounce_tween.set_trans(Tween.TRANS_QUAD)
		bounce_tween.tween_property(LobbyEntry, "position", ending_position - Vector2(1920, 0), 0)
		LobbyEntry.visible = true
		bounce_tween.tween_property(LobbyEntry, "position", ending_position + Vector2(50, 0), 0.2)
		bounce_tween.set_trans(Tween.TRANS_LINEAR)
		bounce_tween.tween_property(LobbyEntry, "position", ending_position, 0.05)
	return
