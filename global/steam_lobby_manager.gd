# This file handles all of the Steam peer to peer junk.
# Every time you want to send or recieve a packet, this code handles that.

extends Node


### Mission critical variables
const PACKET_READ_LIMIT: int = 32
var STEAM_ID: int = 0
var STEAM_USERNAME: String = ""
var LOBBY_ID: int = 0
var LOBBY_MEMBERS: Array = []
var LOBBY_VOTE_KICK: bool = false
var LOBBY_MAX_MEMBERS: int = 10


### User set variables
var lobby_name: String
var lobby_rules_bin: int


### Custom signals
signal lobby_manager_joined_lobby
signal lobby_manager_left_lobby
signal lobby_manager_start_game
signal lobby_manager_readied
signal p2p_someone_draw_n_cards
signal p2p_you_draw_n_cards
signal p2p_turn_change
signal p2p_active_card_set
signal p2p_play_card
signal p2p_played_card
signal p2p_out


### Default functions 
func _ready():
	# Bind signals up
	Steam.lobby_created.connect(_on_Lobby_Created)
	Steam.lobby_joined.connect(_on_Lobby_Joined)
	Steam.lobby_chat_update.connect(_on_Lobby_Chat_Update)
	Steam.join_requested.connect(_on_Lobby_Join_Requested)
	Steam.persona_state_change.connect(_on_Persona_Change)
	Steam.p2p_session_request.connect(_on_P2P_Session_Request)
	Steam.p2p_session_connect_fail.connect(_on_P2P_Session_Connect_Fail)
	
	# Do we have launch variables?
	_check_Command_Line()
	
	# Who am I?
	STEAM_ID = Steam.getSteamID()
	
	# Grab preliminary lobby data
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
	
	return


func _process(delta):
	if LOBBY_ID > 0:
		_read_All_P2P_Packets()


func _read_All_P2P_Packets(read_count: int = 0):
	if read_count >= PACKET_READ_LIMIT:
		return
	
	if Steam.getAvailableP2PPacketSize(0) > 0:
		_read_P2P_Packet()
		_read_All_P2P_Packets(read_count + 1)
	
	return


func _on_P2P_Session_Request(remote_id: int) -> void:
	# Get the requester's name
	var REQUESTER: String = Steam.getFriendPersonaName(remote_id)

	# Accept the P2P session; can apply logic to deny this request if needed
	Steam.acceptP2PSessionWithUser(remote_id)

	# Make the initial handshake
	_make_P2P_Handshake()
	
	return


func _send_P2P_Packet(target: int, packet_data: Dictionary) -> void:
	# Set the send_type and channel
	var SEND_TYPE: int = Steam.P2P_SEND_RELIABLE
	var CHANNEL: int = 0

	# Create a data array to send the data through
	var DATA: PackedByteArray
	# Compress the PackedByteArray we create from our dictionary  using the GZIP compression method
	var COMPRESSED_DATA: PackedByteArray = var_to_bytes(packet_data).compress(FileAccess.COMPRESSION_GZIP)
	DATA.append_array(COMPRESSED_DATA)

	# If not sending a packet to everyone, send to specific player
	if target != 0:
		Steam.sendP2PPacket(target, DATA, SEND_TYPE, CHANNEL)
		print("Sent:")
		print(packet_data)
		return
	
	# Loop through all members that aren't you
	for MEMBER in LOBBY_MEMBERS:
		if MEMBER['steam_id'] != STEAM_ID:
			Steam.sendP2PPacket(MEMBER["steam_id"], DATA, SEND_TYPE, CHANNEL)

	print("Sent:")
	print(packet_data)

	return


func _read_P2P_Packet() -> void:
	var PACKET_SIZE: int = Steam.getAvailableP2PPacketSize(0)

	# There is a packet
	if PACKET_SIZE < 0:
		return;
	
	var PACKET: Dictionary = Steam.readP2PPacket(PACKET_SIZE, 0)

	if PACKET.is_empty() or PACKET == null:
		print("WARNING: read an empty packet with non-zero size!")

	# Get the remote user's ID
	var PACKET_SENDER: int = PACKET['steam_id_remote']

	# Make the packet data readable
	var PACKET_CODE: PackedByteArray = PACKET['data']
	# Decompress the array before turning it into a useable dictionary
	var READABLE: Dictionary = bytes_to_var(PACKET_CODE.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP))

	# Handle packet
	match READABLE["message"]:
		"start_game":
			lobby_manager_start_game.emit()
		"ready":
			lobby_manager_readied.emit(PACKET_SENDER)
		"you_draw":
			p2p_you_draw_n_cards.emit(READABLE["cards"])
		"someone_draw":
			p2p_someone_draw_n_cards.emit(READABLE["target"], READABLE["n"])
		"turn_change":
			p2p_turn_change.emit(READABLE["turn"])
		"set_active_card":
			p2p_active_card_set.emit(READABLE["card"])
		"play":
			if STEAM_ID == LOBBY_MEMBERS[0]["steam_id"]:
				p2p_play_card.emit(READABLE["card"], PACKET_SENDER)
		"played":
			p2p_played_card.emit(READABLE["card"], READABLE["player"])
		"out":
			p2p_out.emit(READABLE["player"])
		_:
			print("Unknown Packet Type: "+str(READABLE))

	print("Recieved:")
	print(READABLE)

	# Append logic here to deal with packet data
	return


func _on_P2P_Session_Connect_Fail(steamID: int, session_error: int) -> void:
	# If no error was given
	match session_error:
		0:
			print("WARNING: Session failure with "+str(steamID)+" [no error given].")
		1:
			print("WARNING: Session failure with "+str(steamID)+" [target user not running the same game].")
		2:
			print("WARNING: Session failure with "+str(steamID)+" [local user doesn't own app / game].")
		3:
			print("WARNING: Session failure with "+str(steamID)+" [target user isn't connected to Steam].")
		4:
			print("WARNING: Session failure with "+str(steamID)+" [connection timed out].")
		5:
			print("WARNING: Session failure with "+str(steamID)+" [unused].")
		_:
			print("WARNING: Session failure with "+str(steamID)+" [unknown error "+str(session_error)+"].")


### Custom functions
func _create_Lobby() -> void:
	# Make sure a lobby is not already set
	if LOBBY_ID == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, LOBBY_MAX_MEMBERS) # Requires an int() for whatever reason
	
	return


func _on_Lobby_Created(connection: int, new_lobby_id: int) -> void:
	if connection != 1:
		return
	
	# Set our lobby ID
	LOBBY_ID = new_lobby_id
	print ("Created lobby " + str(LOBBY_ID))

	# Set our lobby data
	Steam.setLobbyData(LOBBY_ID, "name", lobby_name)
	Steam.setLobbyData(LOBBY_ID, "mode", "ono")
	
	# Allow steam to relay in the event of P2P failure
	var RELAY: bool = Steam.allowP2PPacketRelay(true)
	print("Steam relay backup is now " + str(RELAY))
	
	return


func _join_Lobby(lobby_id: int) -> void:
	print("Attempting to join lobby id " + str(lobby_id) + "...")
	
	# Clear garbage from a previous lobby (should be taken care of upon leaving a lobby but whatever
	LOBBY_MEMBERS.clear()
	
	# Actually request a lobby join.
	Steam.joinLobby(lobby_id)
	
	return


func _on_Lobby_Joined(new_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		return
	
	LOBBY_ID = new_lobby_id
	_get_Lobby_Members()
	_make_P2P_Handshake()
	
	lobby_manager_joined_lobby.emit()
	
	return


func _on_Lobby_Join_Requested(lobby_id: int, friendID: int) -> void:
	var OWNER_NAME: String = Steam.getFriendPersonaName(friendID)
	
	print("Joining" + str(OWNER_NAME) + "'s lobby...")
	
	_join_Lobby(lobby_id)


func _get_Lobby_Members() -> void:
	# Ensure that the previous members have been cleared
	LOBBY_MEMBERS.clear()
	
	var MEMBERS: int = Steam.getNumLobbyMembers(LOBBY_ID)
	
	# Get data on members
	for MEMBER in range(0, MEMBERS):
		var MEMBER_STEAM_ID: int = Steam.getLobbyMemberByIndex(LOBBY_ID, MEMBER)
		var MEMBER_STEAM_NAME: String = Steam.getFriendPersonaName(MEMBER_STEAM_ID)
		LOBBY_MEMBERS.append({"steam_id": MEMBER_STEAM_ID, "steam_name": MEMBER_STEAM_NAME})
		
	return


func _on_Persona_Change(steam_id: int, _flag: int) -> void:
	if 0 < LOBBY_ID:
		return
	
	_get_Lobby_Members()
	
	return


func _make_P2P_Handshake() -> void:
	_send_P2P_Packet(0, {"message": "handshake", "from": STEAM_ID})
	return


func _on_Lobby_Chat_Update(lobby_id: int, change_id: int, making_change_id: int, chat_state: int) -> void:
	var CHANGER: String = Steam.getFriendPersonaName(change_id)
	
	# Player joined.
	match chat_state:
		1:
			print(str(CHANGER) + "has joined.")
		2:
			print(str(CHANGER) + "has left.")
		8:
			print(str(CHANGER) + "has been kicked.")
		16:
			print(str(CHANGER) + "has been banned.")
		_:
			print(str(CHANGER) + "did some black magic.")
	
	_get_Lobby_Members()
	
	return


func _leave_Lobby() -> void:
	if LOBBY_ID != 0:
		Steam.leaveLobby(LOBBY_ID)
	
	LOBBY_ID = 0
	
	for MEMBERS in LOBBY_MEMBERS:
		if MEMBERS['steam_id'] == STEAM_ID:
			continue

		Steam.closeP2PSessionWithUser(MEMBERS['steam_id'])
	
	LOBBY_MEMBERS.clear()
	
	lobby_manager_left_lobby.emit()
	
	return


func _check_Command_Line() -> void:
	var ARGUMENTS: Array = OS.get_cmdline_args()
	
	if ARGUMENTS.size() < 1:
		return
	
	if ARGUMENTS[0] != "+connect_lobby" or int(ARGUMENTS[1]) < 0: # TODO: I am unsure of whether this will always be the first argument.
		return
	
	print("Switching lobbies. Joining ID " + str(ARGUMENTS[1]))
	_join_Lobby(int(ARGUMENTS[1]))
	pass
