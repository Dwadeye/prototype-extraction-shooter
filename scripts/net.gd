extends Node

## Co-op networking singleton (autoload "Net"). Host-authoritative.
## Host = peer 1. Clients connect over ENet/UDP. Built for friend co-op
## (no anti-cheat): the host simulates the world, clients send intent.

signal lobby_changed
signal connected_to_host
signal connect_failed

const DEFAULT_PORT := 45678
const MAX_PLAYERS := 4

var active: bool = false
## peer_id (int) -> display name (String)
var players: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Headless co-op test: auto-quit after a while so logs flush.
	if "test" in OS.get_cmdline_user_args():
		get_tree().create_timer(12.0).timeout.connect(func(): get_tree().quit())

func is_host() -> bool:
	return active and multiplayer.is_server()

func local_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()

func peer_ids() -> Array:
	var ids: Array = players.keys()
	ids.sort()
	return ids

func host(port: int = DEFAULT_PORT) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return "Could not host on port %d (error %d)." % [port, err]
	multiplayer.multiplayer_peer = peer
	active = true
	players = {1: "Host"}
	lobby_changed.emit()
	print("NET hosting on port %d" % port)
	return ""

func join(address: String, port: int = DEFAULT_PORT) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return "Could not reach %s:%d (error %d)." % [address, port, err]
	multiplayer.multiplayer_peer = peer
	active = true
	print("NET joining %s:%d" % [address, port])
	return ""

func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	active = false
	players.clear()
	lobby_changed.emit()

func _on_connected_to_server() -> void:
	register_player.rpc_id(1, "Player %d" % multiplayer.get_unique_id())
	print("NET connected as peer %d" % multiplayer.get_unique_id())
	connected_to_host.emit()

func _on_connection_failed() -> void:
	connect_failed.emit()
	leave()

func _on_server_disconnected() -> void:
	leave()

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		sync_players.rpc(players)
	lobby_changed.emit()

@rpc("any_peer", "reliable")
func register_player(display_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = display_name
	sync_players.rpc(players)

@rpc("authority", "reliable", "call_local")
func sync_players(list: Dictionary) -> void:
	players = list
	print("NET players %s" % str(players))
	lobby_changed.emit()
