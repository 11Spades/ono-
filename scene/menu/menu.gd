extends Node


### Script globals
var current_screen: int = 0
var rule_placard_preload: Resource


### Custom signals
signal lobby_offscreen


func _ready():
	preload("res://scene/game/game.tscn")
	rule_placard_preload = preload("res://scene/menu/lobby_column_text.tscn")
	SteamLobbyManager.lobby_manager_start_game.connect(_on_game_start_packet_recieved)
	
	return


func _input(event):
	if event.is_action_pressed("ui_back"):
		match current_screen:
			1:
				transition_left_to_stage_one()
			2:
				SteamLobbyManager._leave_Lobby()
				SteamLobbyManager.lobby_rules_bin = 0
				transition_left_to_stage_two()
			_:
				get_tree().quit()
	return


### Signal connectors
func connect_new_lobby_button(button: TextureButton) -> void:
	button.pressed.connect(_on_lobby_join_button_pressed.bind(button.get_meta("lobby_id")))
	return


### Signals
func _on_window_resized():
	Global.current_node_size_multiplier = get_viewport().get_visible_rect().size / Vector2(1920, 1080)
	resize_node_and_all_children(self)
	
	return

func _on_steam_lobby_list_button_pressed():
	# Unhide lobby list container
	$LobbyList.visible = true
	
	# Transition to lobby list
	transition_right_to_stage_two()


func _on_steam_host_button_pressed():
	# Unhide the lobby creation container
	$LobbyCreation.visible = true
	
	# Transition to lobby settings
	transition_right_to_stage_two()


func _on_lobby_create_button_pressed():
	# Inform the lobby manager of our preferences
	SteamLobbyManager.lobby_name = $LobbyCreation/LobbyNameLineEdit.text
	
	# Set up our lobby rules
	SteamLobbyManager.lobby_rules_bin = (
		int($LobbyCreation/DrawStackingCheckBox.button_pressed)     *      0b1 +
		int($LobbyCreation/PlayDrawsCheckBox.button_pressed)        *     0b10 +
		int($LobbyCreation/DrawUntilPlayCheckBox.button_pressed)    *    0b100 +
		int($LobbyCreation/JumpInsCheckBox.button_pressed)          *   0b1000 +
		int($LobbyCreation/SevensCheckBox.button_pressed)           *  0b10000 +
		int($LobbyCreation/ZeroesCheckBox.button_pressed)           * 0b100000 )
	
	# Move this to lobby.gd later
	var rule_placard: Label
	
	if ($LobbyCreation/DrawStackingCheckBox.button_pressed):
		rule_placard = rule_placard_preload.instantiate()
		rule_placard.text = "Draw Stacking"
		$Lobby/LobbyRulesContainer/LobbyRules.add_child(rule_placard)
	
	if ($LobbyCreation/PlayDrawsCheckBox.button_pressed):
		rule_placard = rule_placard_preload.instantiate()
		rule_placard.text = "Play Draws"
		$Lobby/LobbyRulesContainer/LobbyRules.add_child(rule_placard)
	
	if ($LobbyCreation/DrawUntilPlayCheckBox.button_pressed):
		rule_placard = rule_placard_preload.instantiate()
		rule_placard.text = "Draw Until Play"
		$Lobby/LobbyRulesContainer/LobbyRules.add_child(rule_placard)
	
	if ($LobbyCreation/JumpInsCheckBox.button_pressed):
		rule_placard = rule_placard_preload.instantiate()
		rule_placard.text = "Jump Ins"
		$Lobby/LobbyRulesContainer/LobbyRules.add_child(rule_placard)
	
	if ($LobbyCreation/SevensCheckBox.button_pressed):
		rule_placard = rule_placard_preload.instantiate()
		rule_placard.text = "Swap on Sevens"
		$Lobby/LobbyRulesContainer/LobbyRules.add_child(rule_placard)
	
	if ($LobbyCreation/ZeroesCheckBox.button_pressed):
		rule_placard = rule_placard_preload.instantiate()
		rule_placard.text = "Cycle on Zeroes"
		$Lobby/LobbyRulesContainer/LobbyRules.add_child(rule_placard)
	
	# Create our lobby with the help of our global
	SteamLobbyManager._create_Lobby()
	
	# Set the lobby pane's label
	$Lobby/LobbyNameLabel.text = SteamLobbyManager.lobby_name

	# Go to our lobby screen
	transition_right_to_stage_three()

	# Update global
	Global.set_network_mode(Global.NETWORK_MODE.STEAM)

	return


func _on_lobby_join_button_pressed(lobby_id: int) -> void:
	# Join the lobby with the help of our global
	SteamLobbyManager._join_Lobby(lobby_id)
	
	# Set the lobby pane's label
	$Lobby/LobbyNameLabel.text = Steam.getLobbyData(lobby_id, "name")
	
	# Go to our lobby screen
	transition_right_to_stage_three()
	
	# Update global
	Global.set_network_mode(Global.NETWORK_MODE.STEAM)
	
	return


func stage_three_got_offscreen() -> void:
	lobby_offscreen.emit()
	$Lobby/ChatPaneTextEdit.text = ""
	return


### Menu transitions
func transition_left_to_stage_one() -> void:
	var bounce_tween = create_tween()
	bounce_tween.set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(self, "position", Vector2(-1970 * Global.current_node_size_multiplier.x, 0), 0.05)
	bounce_tween.set_trans(Tween.TRANS_QUAD)
	bounce_tween.tween_property(self, "position", Vector2(50 * Global.current_node_size_multiplier.x, 0), 0.2)
	bounce_tween.set_trans(Tween.TRANS_LINEAR)
	bounce_tween.tween_property(self, "position", Vector2(0, 0), 0.05)
	bounce_tween.tween_callback(hide_stage_two)
	current_screen = 0
	return


func transition_right_to_stage_two() -> void:
	var bounce_tween = create_tween()
	bounce_tween.set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(self, "position", Vector2(50 * Global.current_node_size_multiplier.x, 0), 0.05)
	bounce_tween.set_trans(Tween.TRANS_QUAD)
	bounce_tween.tween_property(self, "position", Vector2(-1970 * Global.current_node_size_multiplier.x, 0), 0.2)
	bounce_tween.set_trans(Tween.TRANS_LINEAR)
	bounce_tween.tween_property(self, "position", Vector2(-1920 * Global.current_node_size_multiplier.x, 0), 0.05)
	current_screen = 1
	
	# Change focus to prevent spacebar glitch
	# Works for our purposes even if target is hidden!
	$LobbyCreation/LobbyNameLineEdit.grab_focus()
	
	return


func transition_left_to_stage_two() -> void:
	var bounce_tween = create_tween()
	bounce_tween.set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(self, "position", Vector2(-3890 * Global.current_node_size_multiplier.x, 0), 0.05)
	bounce_tween.set_trans(Tween.TRANS_QUAD)
	bounce_tween.tween_property(self, "position", Vector2(-1870 * Global.current_node_size_multiplier.x, 0), 0.2)
	bounce_tween.tween_callback(stage_three_got_offscreen)
	bounce_tween.set_trans(Tween.TRANS_LINEAR)
	bounce_tween.tween_property(self, "position", Vector2(-1920 * Global.current_node_size_multiplier.x, 0), 0.05)
	current_screen = 1
	return


func transition_right_to_stage_three() -> void:
	var bounce_tween = create_tween()
	bounce_tween.set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(self, "position", Vector2(-1870 * Global.current_node_size_multiplier.x, 0), 0.05)
	bounce_tween.set_trans(Tween.TRANS_QUAD)
	bounce_tween.tween_property(self, "position", Vector2(-3890 * Global.current_node_size_multiplier.x, 0), 0.2)
	bounce_tween.set_trans(Tween.TRANS_LINEAR)
	bounce_tween.tween_property(self, "position", Vector2(-3840 * Global.current_node_size_multiplier.x, 0), 0.05)
	current_screen = 2
	
	# Change focus to prevent spacebar glitch
	$Lobby/GameStartButton.grab_focus()
	
	return


func hide_stage_two() -> void:
	$LobbyList.visible = false
	$LobbyCreation.visible = false
	return


func _on_game_start_button_pressed():
	SteamLobbyManager._send_P2P_Packet(0, {"message": "start_game"})
	get_tree().change_scene_to_packed(Global.GAME_PRELOAD)

	return


func _on_game_start_packet_recieved():
	get_tree().change_scene_to_file("res://scene/game/game.tscn")
	return


### Other custom functions
func resize_node_and_all_children(node: Node) -> void:
	self.size *= Global.current_node_size_multiplier
	
	for child in get_children():
		resize_node_and_all_children(child)
	
	return
