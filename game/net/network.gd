extends Node
## Network: who is connected, and host/join/leave. Autoload name: "Network".
## Owner: Sufi (gameplay). Peer-to-peer: one player's game is the HOST, others join it.
##
## N1 uses ENet (direct IP, works from the editor for testing).
## N4 swaps in WebRTC + room codes for the web build; nothing else has to change,
## because the rest of the game only uses the functions and signals below.
##
##   Network.host("Sufi")                 -> become the host (you are player slot 0)
##   Network.join("127.0.0.1", "Zaliq")   -> join a host
##   Network.leave()
##   Network.players   { peer_id: {"name": "Sufi", "slot": 0}, ... }   same on every device
##   Network.is_host() / Network.my_id() / Network.my_slot()
##
##   Network.claim_slot(2)                -> ask for another free slot (= role) in the lobby
##   Network.start_game("res://game/test_map.tscn")   host only: everyone loads that scene
##
## Signals: players_changed, joined (you are in), join_failed(reason), disconnected(reason)

signal players_changed
signal joined
signal join_failed(reason: String)
signal disconnected(reason: String)

const MAX_PLAYERS := 4

const RELAY_URL := "wss://<your-site>.sslip.io/relay"   # fixed in Step 6
const RelayPeer := preload("res://game/net/relay_peer.gd")

var players := {}          ## peer_id -> {"name": String, "slot": int}
var game_scene := ""       ## scene the host started ("" = still in the lobby)
var _my_name := ""
var room_code := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host(player_name: String) -> Error:
	leave()
	var peer = RelayPeer.new()
	var err: Error = peer.open(relay_url(), "")
	if err != OK:
		return err
	peer.room_ready.connect(func(code: String):
		room_code = code
		players = {1: {"name": clean_name(player_name), "slot": 0}}
		players_changed.emit()
		joined.emit())
	multiplayer.multiplayer_peer = peer
	_my_name = player_name
	return OK


func join(code: String, player_name: String) -> Error:
	leave()
	var peer = RelayPeer.new()
	var err: Error = peer.open(relay_url(), code)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_my_name = player_name
	return OK

static func relay_url() -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--relay="):
			return a.trim_prefix("--relay=")
	return RELAY_URL

## Host only: every device (including late joiners) switches to this scene.
func start_game(scene_path: String) -> void:
	if not is_host():
		return
	game_scene = scene_path
	_load_scene.rpc(scene_path)


func leave() -> void:
	game_scene = ""
	room_code = ""
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if not players.is_empty():
		players = {}
		players_changed.emit()


func is_online() -> bool:
	return not players.is_empty()


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func my_slot() -> int:
	return players.get(my_id(), {}).get("slot", -1)


# ---------------------------------------------------------------- pure rules (tested)

## Lowest free slot 0..MAX_PLAYERS-1, or -1 when full. Slot = colour and spawn point.
static func free_slot(current: Dictionary) -> int:
	var used := {}
	for info in current.values():
		used[info["slot"]] = true
	for s in MAX_PLAYERS:
		if not used.has(s):
			return s
	return -1


static func clean_name(raw: String) -> String:
	var n := raw.strip_edges().substr(0, 16)
	return n if n != "" else "Player"


## Pick a slot (role) in the lobby. The host checks it is still free.
func claim_slot(slot: int) -> void:
	if not is_online():
		return
	if is_host():
		_claim(1, slot)
	else:
		_req_claim.rpc_id(1, slot)


static func slot_taken(current: Dictionary, slot: int, by: int) -> bool:
	for id in current:
		if id != by and current[id]["slot"] == slot:
			return true
	return false


# ---------------------------------------------------------------- host side

@rpc("any_peer", "reliable")
func _req_claim(slot: int) -> void:
	if multiplayer.is_server():
		_claim(multiplayer.get_remote_sender_id(), slot)


func _claim(id: int, slot: int) -> void:
	if not players.has(id) or slot < 0 or slot >= MAX_PLAYERS or slot_taken(players, slot, id):
		return
	players[id]["slot"] = slot
	_sync_players.rpc(players)
	players_changed.emit()


func _on_peer_connected(_id: int) -> void:
	pass   # host waits for the newcomer to send its name (_register)


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var slot := free_slot(players)
	if slot == -1:
		_refused.rpc_id(id, "The team is full (%d players)." % MAX_PLAYERS)
		return
	players[id] = {"name": clean_name(player_name), "slot": slot}
	_sync_players.rpc(players)        # everyone (including the newcomer) gets the full list
	players_changed.emit()
	if game_scene != "":
		_load_scene.rpc_id(id, game_scene)   # game already running: bring the newcomer in


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.erase(id):
		_sync_players.rpc(players)
		players_changed.emit()


# ---------------------------------------------------------------- client side

func _on_connected_to_server() -> void:
	_register.rpc_id(1, _my_name)


@rpc("authority", "reliable")
func _sync_players(list: Dictionary) -> void:
	var was_in := players.has(my_id())
	players = list
	players_changed.emit()
	if not was_in and players.has(my_id()):
		joined.emit()


@rpc("authority", "call_local", "reliable")
func _load_scene(scene_path: String) -> void:
	game_scene = scene_path
	get_tree().change_scene_to_file(scene_path)


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	leave()
	join_failed.emit(reason)


func _on_connection_failed() -> void:
	var why := "Could not reach the host. Check the address and that the host is running."
	var peer = multiplayer.multiplayer_peer
	if peer is RelayPeer and peer.fail_reason != "":
		why = peer.fail_reason
	leave()
	join_failed.emit(why)


func _on_server_disconnected() -> void:
	leave()
	disconnected.emit("The host left the game.")