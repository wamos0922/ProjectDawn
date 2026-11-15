extends MultiplayerPeerExtension
## RelayPeer: online play with room codes through our relay on the VM.

signal room_ready(code: String)
signal failed(reason: String)

var code := ""
var fail_reason := ""

var _ws := WebSocketPeer.new()
var _id := 0
var _status := CONNECTION_DISCONNECTED
var _target := 0
var _channel := 0
var _mode := TRANSFER_MODE_RELIABLE
var _refuse := false
var _in: Array = []
var _peers := {}
var _hello_sent := false
var _wanted := ""


func open(url: String, join_code := "") -> Error:
	_wanted = join_code.strip_edges().to_upper()
	_id = 1 if _wanted == "" else randi_range(2, 2147483646)
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	var err := _ws.connect_to_url(url)
	if err != OK:
		return err
	_status = CONNECTION_CONNECTING
	return OK


func _poll() -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _hello_sent:
		_hello_sent = true
		var hello := {"t": "host"} if _wanted == "" else {"t": "join", "code": _wanted, "id": _id}
		_ws.send_text(JSON.stringify(hello))
	while _ws.get_available_packet_count() > 0:
		var pkt := _ws.get_packet()
		if _ws.was_string_packet():
			_on_text(pkt.get_string_from_utf8())
		elif pkt.size() >= 4 and _status == CONNECTION_CONNECTED:
			_in.append([pkt.decode_s32(0), pkt.slice(4)])
	if st == WebSocketPeer.STATE_CLOSED:
		if _status == CONNECTION_CONNECTING and fail_reason == "":
			_fail("Could not reach the online server. Check your internet, then try again.")
		_drop_all()


func _on_text(raw: String) -> void:
	var m = JSON.parse_string(raw)
	if typeof(m) != TYPE_DICTIONARY:
		return
	match str(m.get("t", "")):
		"ok":
			_id = int(m["id"])
			code = str(m["code"])
			_status = CONNECTION_CONNECTED
			if _id != 1:
				_peers[1] = true
				peer_connected.emit(1)
			room_ready.emit(code)
		"error":
			_fail(str(m.get("reason", "The server said no.")))
			_ws.close()
		"peer":
			var id := int(m["id"])
			if _id == 1 and not _peers.has(id):
				_peers[id] = true
				peer_connected.emit(id)
		"gone":
			var id := int(m["id"])
			if _peers.erase(id):
				peer_disconnected.emit(id)
			if id == 1:
				_ws.close()
				_drop_all()


func _fail(reason: String) -> void:
	fail_reason = reason
	failed.emit(reason)


func _drop_all() -> void:
	_status = CONNECTION_DISCONNECTED
	for id in _peers.keys():
		peer_disconnected.emit(id)
	_peers.clear()
	_in.clear()


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var out := PackedByteArray()
	out.resize(4)
	out.encode_s32(0, _target)
	out.append_array(buffer)
	return _ws.put_packet(out)


func _get_packet_script() -> PackedByteArray:
	return _in.pop_front()[1] if not _in.is_empty() else PackedByteArray()

func _get_available_packet_count() -> int:
	return _in.size()

func _get_packet_peer() -> int:
	return _in[0][0] if not _in.is_empty() else 0

func _get_max_packet_size() -> int:
	return 1 << 20

func _get_packet_channel() -> int:
	return 0

func _get_packet_mode() -> TransferMode:
	return TRANSFER_MODE_RELIABLE

func _set_transfer_channel(channel: int) -> void:
	_channel = channel

func _get_transfer_channel() -> int:
	return _channel

func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode

func _get_transfer_mode() -> TransferMode:
	return _mode

func _set_target_peer(peer: int) -> void:
	_target = peer

func _get_unique_id() -> int:
	return _id

func _is_server() -> bool:
	return _id == 1

func _is_server_relay_supported() -> bool:
	return true

func _get_connection_status() -> ConnectionStatus:
	return _status

func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable

func _is_refusing_new_connections() -> bool:
	return _refuse

func _disconnect_peer(_peer: int, _force: bool) -> void:
	pass

func _close() -> void:
	_ws.close()
	_drop_all()