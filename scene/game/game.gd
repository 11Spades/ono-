extends Node2D


# Constants
const CARD_PRELOAD: Resource = preload("res://scene/game/card.tscn")
const FLIPPED_CARD_PRELOAD: Resource = preload("res://scene/game/flipped_card.tscn")
const VALID_CARDS: Array = ["R0", "R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8", "R9", "RS", "RR", "RP",
							"G0", "G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8", "G9", "GS", "GR", "GP",
							"B0", "B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9", "BS", "BR", "BP",
							"Y0", "Y1", "Y2", "Y3", "Y4", "Y5", "Y6", "Y7", "Y8", "Y9", "YS", "YR", "YP",
							"WC", "WC", "WF", "WF"]
const MENU_PRELOAD: Resource = preload("res://scene/menu/menu.tscn")


# Variables
var networking_mode: int = Global.get_network_mode()
var rules: Dictionary = {"draw_stacking": 0}
var readied_players: int = 0
var place_in_lobby: int
var degrees_to_turn_hand: float
var current_turn: int = -3
var turn_order: int = 1
var active_card: String = "null"
var attempting_to_play: Control


# Custom rules variables
var draw_stack: int = 0

### Custom functions
func game_setup():
	# If you aren't the host, don't try to set the game up.
	if SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"] != SteamLobbyManager.STEAM_ID:
		return
	
	# Deal every player seven cards.
	for i in SteamLobbyManager.LOBBY_MEMBERS.size():
		var player_id: int = SteamLobbyManager.LOBBY_MEMBERS[i]["steam_id"]
		var hand: Array = []
		
		for j in 7:
			hand.push_back(VALID_CARDS.pick_random())
		
		SteamLobbyManager._send_P2P_Packet(player_id, {"message": "you_draw", "cards": hand})
		
		SteamLobbyManager._send_P2P_Packet(0, {"message": "someone_draw", "target": player_id, "n": 7}) # It'd be nice to not send a packet to the drawer, as they get their own
		if player_id != SteamLobbyManager.STEAM_ID:
			_on_someone_drew(player_id, 7)
	
	# Flip the first card.
	var starter_card: String = VALID_CARDS.pick_random()
	SteamLobbyManager._send_P2P_Packet(0, {"message": "set_active_card", "card": starter_card})
	_on_active_card_set(starter_card)
	
	# Choose the first person to play at random.
	var first_to_go: int = randi() % SteamLobbyManager.LOBBY_MEMBERS.size()
	SteamLobbyManager._send_P2P_Packet(0, {"message": "turn_change", "turn": first_to_go})
	_on_turn_changed(first_to_go)


func _on_player_readied(_player: int):
	readied_players += 1
	
	# If every player is ready, start the game.
	if readied_players == SteamLobbyManager.LOBBY_MEMBERS.size() && SteamLobbyManager.STEAM_ID == SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"]:
		game_setup()
	
	return


func render_card(card_node: Control, card_data: String) -> void:
	match card_data[0]:
		"R":
			card_node.get_node("CardColor").color = Color(1, 0, 0, 1)
		"G":
			card_node.get_node("CardColor").color = Color(0, 1, 0, 1)
		"B":
			card_node.get_node("CardColor").color = Color(0, 1, 1, 1)
		"Y":
			card_node.get_node("CardColor").color = Color(1, 1, 0, 1)
		"W":
			card_node.get_node("CardColor").color = Color(0, 0, 0, 1)
	
	match card_data[1]:
		"R":
			card_node.get_node("CardNumber").text = "🔄"
		"S":
			card_node.get_node("CardNumber").text = "🚫"
		"P":
			card_node.get_node("CardNumber").text = "+2"
		"F":
			card_node.get_node("CardNumber").text = "+4"
		_:
			card_node.get_node("CardNumber").text = card_data[1]


func advance_turn() -> void:
	current_turn += turn_order
	
	if SteamLobbyManager.LOBBY_MEMBERS.size() <= current_turn:
		current_turn = 0
	
	if current_turn < 0:
		current_turn = SteamLobbyManager.LOBBY_MEMBERS.size() - 1
	
	$TurnPointer.rotation_degrees = -degrees_to_turn_hand * (current_turn - place_in_lobby) 
	$TurnPointer.position = Vector2(960 + sin($TurnPointer.rotation) * 200, 540 + cos($TurnPointer.rotation) * 200)
	
	return


func attempt_to_play(card: Control) -> void:
	# If it isn't my turn, fail.
	if SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"] != SteamLobbyManager.STEAM_ID:
		return

	var card_data: String = card.get_meta("card")
	
	# If this is a wild card, display the wild buttons.
	if card_data[0] == "W":
		attempting_to_play = card
		$WildButtonGroup.visible = true
		return
	else:
		$WildButtonGroup.visible = false
	
	# If: The card I'm trying to play doesn't match the color of the active card
	# and the card I'm trying to play doesn't match the number of the active card
	# and the active card isn't an uncolored wild (occurs when a wild is the first card)
	# NOTE: We do not need to account for the attempted play being a wild, the wild buttons handle that.
	if card_data[0] != active_card[0] && card_data[1] != active_card[1] && active_card[0] != "W":
		return
	
	# Draw Stacking Logic
	# If: There are cards on the draw stack
	# and the card I'm trying to play doesn't match the active card in number
	# and the card I'm trying to play isn't a Draw Four
	if draw_stack && card_data[1] != active_card[1] && card_data[1] != "F":
		return
	
	attempting_to_play = card
	
	SteamLobbyManager._send_P2P_Packet(SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"], {"message": "play", "card": card_data})
	
	return


### Signals
func _on_attempted_to_play_card(card: String, player: int) -> void:
	if SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"] != player:
		return
	
	# TODO: Prevent draws from deleting the current card
	if card[0] == "D":
		if !draw_stack:
			SteamLobbyManager._send_P2P_Packet(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"], {"message": "you_draw", "cards": [VALID_CARDS.pick_random()]})
			SteamLobbyManager._send_P2P_Packet(0, {"message": "someone_draw", "target": player, "n": 1})
			if SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"] != SteamLobbyManager.STEAM_ID:
				get_node("Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])).add_child(FLIPPED_CARD_PRELOAD.instantiate())
		else:
			var cards_drawn: Array
			
			while 0 < draw_stack:
				cards_drawn.push_back(VALID_CARDS.pick_random())
				draw_stack -= 1
			
			SteamLobbyManager._send_P2P_Packet(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"], {"message": "you_draw", "cards": cards_drawn})
			SteamLobbyManager._send_P2P_Packet(0, {"message": "someone_draw", "target": player, "n": cards_drawn.size()})
			if SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"] != SteamLobbyManager.STEAM_ID:
				get_node("Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])).add_child(FLIPPED_CARD_PRELOAD.instantiate())
		
		advance_turn()
		SteamLobbyManager._send_P2P_Packet(0, {"message": "turn_change", "turn": current_turn})
		return
	
	if card[0] != active_card[0] && card[1] != active_card[1] && card[0] != "W" && active_card[0] != "W":
		return
	
	if draw_stack && card[1] != active_card[1] && card[1] != "F":
		return
	
	SteamLobbyManager._send_P2P_Packet(0, {"message": "played", "card": card, "player": player})
	_on_card_played(card, player)
	
	return


func _on_card_played(card: String, player: int) -> void:
	if player == SteamLobbyManager.STEAM_ID:
		attempting_to_play.queue_free()
	else:
		self.get_node("Hand" + str(player)).get_child(0).queue_free()
	
	if card[0] == "W":
		active_card = card[2] + card[1]
	else:
		active_card = card
	
	render_card(self.get_node("ActiveCard"), active_card)
	
	match card[1]:
		"R":
			turn_order *= -1
		"S":
			advance_turn()
		"P":
			if !rules["draw_stacking"]:
				advance_turn()
				
				if SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"] == SteamLobbyManager.STEAM_ID:
					SteamLobbyManager._send_P2P_Packet(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"], {"message": "you_draw", "cards": [VALID_CARDS.pick_random(), VALID_CARDS.pick_random()]})
				
				if SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"] != SteamLobbyManager.STEAM_ID:
					get_node("Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])).add_child(FLIPPED_CARD_PRELOAD.instantiate())
					get_node("Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])).add_child(FLIPPED_CARD_PRELOAD.instantiate())
			else:
				draw_stack += 2
		"F":
			if !rules["draw_stacking"]:
				advance_turn()
				
				if SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"] == SteamLobbyManager.STEAM_ID:
					SteamLobbyManager._send_P2P_Packet(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"], {"message": "you_draw", "cards": [VALID_CARDS.pick_random(), VALID_CARDS.pick_random(), VALID_CARDS.pick_random(), VALID_CARDS.pick_random()]})
				
				if SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"] != SteamLobbyManager.STEAM_ID:
					get_node("Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])).add_child(FLIPPED_CARD_PRELOAD.instantiate())
					get_node("Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])).add_child(FLIPPED_CARD_PRELOAD.instantiate())
					get_node("Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])).add_child(FLIPPED_CARD_PRELOAD.instantiate())
					get_node("Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])).add_child(FLIPPED_CARD_PRELOAD.instantiate())
			else:
				draw_stack += 4
		_:
			pass
	
	if SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"] == SteamLobbyManager.STEAM_ID && get_node("Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])).get_child_count() == 1:
		SteamLobbyManager._send_P2P_Packet(0, {"message": "out", "player": SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"]})
		_on_player_out(SteamLobbyManager.LOBBY_MEMBERS[current_turn]["steam_id"])
		
		return
	
	$WildButtonGroup.visible = false
	
	advance_turn()
	
	return


func _on_player_out(player: int):
	return


func _on_draw_button_pressed():
	SteamLobbyManager._send_P2P_Packet(SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"], {"message": "play", "card": "D"})
	return


func _on_color_button_pressed(color: String):
	SteamLobbyManager._send_P2P_Packet(SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"], {"message": "play", "card": attempting_to_play.get_meta("card") + color})
	
	$WildButtonGroup.visible = false
	
	return


func _on_you_drew(cards: Array) -> void:
	for card in cards:
		var card_node = CARD_PRELOAD.instantiate()
		
		render_card(card_node, card)
		
		card_node.get_node("CardButton").pressed.connect(attempt_to_play.bind(card_node))
		
		card_node.set_meta("card", card)
		
		self.get_node("Hand" + str(SteamLobbyManager.STEAM_ID)).add_child(card_node)
	return


func _on_someone_drew(target: int, drawn: int) -> void:
	if target == SteamLobbyManager.STEAM_ID:
		return
	
	for i in drawn:
		var flipped_card = FLIPPED_CARD_PRELOAD.instantiate()
		self.get_node("Hand" + str(target)).add_child(flipped_card)
	
	return


func _on_turn_changed(player: int) -> void:
	current_turn = player
	
	$TurnPointer.rotation_degrees = -degrees_to_turn_hand * (current_turn - place_in_lobby)
	$TurnPointer.position = Vector2(960 + sin($TurnPointer.rotation) * 200, 540 + cos($TurnPointer.rotation) * 200)
	
	return


func _on_active_card_set(card: String) -> void:
	var card_node = CARD_PRELOAD.instantiate()
	card_node.name = "ActiveCard"
	card_node.set_position(Vector2(910, 540))
	
	active_card = card
	render_card(card_node, card)
	
	self.add_child(card_node)
	
	return


### Builtins
func _ready():
	var number_of_players: float
	
	# Preloaded stuff
	const hand_container_preload: Resource = preload("res://scene/game/player_hand_container.tscn")
	
	# Signals
	SteamLobbyManager.lobby_manager_readied.connect(_on_player_readied)
	SteamLobbyManager.p2p_you_draw_n_cards.connect(_on_you_drew)
	SteamLobbyManager.p2p_someone_draw_n_cards.connect(_on_someone_drew)
	SteamLobbyManager.p2p_turn_change.connect(_on_turn_changed)
	SteamLobbyManager.p2p_active_card_set.connect(_on_active_card_set)
	SteamLobbyManager.p2p_play_card.connect(_on_attempted_to_play_card)
	SteamLobbyManager.p2p_played_card.connect(_on_card_played)
	SteamLobbyManager.p2p_out.connect(_on_player_out)
	
	randomize()
	
	# Figure out how many players need dealing with
	match networking_mode:
		1:
			print("This functionality should not be available right now.")
		2:
			number_of_players = SteamLobbyManager.LOBBY_MEMBERS.size()
		_:
			print("Invalid network mode for being in game -- I should crash here.")
	
	degrees_to_turn_hand = 360 / number_of_players
	
	for i in number_of_players:
		if SteamLobbyManager.LOBBY_MEMBERS[i]["steam_id"] == SteamLobbyManager.STEAM_ID:
			place_in_lobby = i
			break

	# Create hands for everybody
	for i in number_of_players:
		var hand_container: HBoxContainer = hand_container_preload.instantiate()
		hand_container.name = "Hand" + str(SteamLobbyManager.LOBBY_MEMBERS[i]["steam_id"])
		hand_container.rotation_degrees = (i - place_in_lobby) * degrees_to_turn_hand
		self.add_child(hand_container)
	
	# Tell the server that we've loaded.
	SteamLobbyManager._send_P2P_Packet(SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"], {"message": "ready"})
	
	if SteamLobbyManager.STEAM_ID == SteamLobbyManager.LOBBY_MEMBERS[0]["steam_id"]:
		Steam.setLobbyData(SteamLobbyManager.LOBBY_ID, "mode", "ono_inprogress")
	
	return


func _input(event):
	if event.is_action_pressed("ui_back"):
		SteamLobbyManager._leave_Lobby()
		get_tree().change_scene_to_packed(MENU_PRELOAD)
		self.queue_free()
	return
