extends Node
class_name CoopNet

## Host-authoritative co-op layer. Added by game_manager as a child named
## "CoopNet" (so its node path matches on every peer).
##
##  - every peer broadcasts its local player transform; proxies show teammates
##  - the host runs enemy AI and streams snapshots; clients show puppets
##  - client shots are resolved by the host (report_fire -> net_client_fire)
##  - enemy damage to a client is routed back to that client (net_apply_damage)
##  - loot is host-authoritative: pickup requests are validated, then broadcast

const RemotePlayerScript := preload("res://scripts/remote_player.gd")

const PLAYER_SEND_HZ := 20.0
const ENEMY_SEND_HZ := 12.0

var gm: Node
var _remotes: Node3D
var _proxies: Dictionary = {}   # peer_id -> RemotePlayer
var _puppets: Dictionary = {}   # net_id  -> Enemy (client-side mirrors)
var _player_timer: float = 0.0
var _enemy_timer: float = 0.0
var _roster_timer: float = 0.0

func setup(manager: Node) -> void:
	gm = manager
	_remotes = Node3D.new()
	_remotes.name = "Remotes"
	add_child(_remotes)
	Net.lobby_changed.connect(_rebuild_proxies)
	_rebuild_proxies()

# --- player proxies ----------------------------------------------------------

func _rebuild_proxies() -> void:
	if not Net.active:
		for id in _proxies.keys():
			(_proxies[id] as Node).queue_free()
		_proxies.clear()
		return
	var me := Net.local_id()
	var want: Array = Net.players.keys()
	for id in want:
		if int(id) == me:
			continue
		if not _proxies.has(int(id)):
			_add_proxy(int(id))
	for id in _proxies.keys():
		if not want.has(int(id)):
			(_proxies[id] as Node).queue_free()
			_proxies.erase(id)
	print("COOP proxies %s (local=%d)" % [str(_proxies.keys()), me])

func _add_proxy(id: int) -> void:
	var p := RemotePlayerScript.new() as RemotePlayer
	p.peer_id = id
	p.name = "Player_%d" % id
	_remotes.add_child(p)
	p.net_damaged.connect(_on_proxy_damaged)
	_proxies[id] = p

func _on_proxy_damaged(peer_id: int, amount: float) -> void:
	if Net.is_host() and peer_id != 1:
		net_apply_damage.rpc_id(peer_id, amount)

func _local_player() -> Node3D:
	if gm != null and gm.has_method("get_local_player"):
		return gm.get_local_player()
	return null

# --- per-frame ---------------------------------------------------------------

func _process(delta: float) -> void:
	if not Net.active:
		return
	_player_timer -= delta
	if _player_timer <= 0.0:
		_player_timer = 1.0 / PLAYER_SEND_HZ
		_send_player_state()
	if Net.is_host():
		_enemy_timer -= delta
		if _enemy_timer <= 0.0:
			_enemy_timer = 1.0 / ENEMY_SEND_HZ
			_send_enemy_snapshot()
		_roster_timer -= delta
		if _roster_timer <= 0.0:
			_roster_timer = 2.0
			_send_enemy_roster()

func _send_player_state() -> void:
	var p := _local_player()
	if p == null:
		return
	net_player_state.rpc(Net.local_id(), p.global_position, p.rotation.y)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func net_player_state(id: int, pos: Vector3, yaw: float) -> void:
	var proxy = _proxies.get(id)
	if proxy != null and is_instance_valid(proxy):
		proxy.apply_state(pos, yaw)

# --- enemies (host -> clients) ----------------------------------------------

func _send_enemy_snapshot() -> void:
	var list: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if bool(e.get("puppet")):
			continue
		list.append({
			"id": int(e.get("net_id")),
			"v": String(e.get("variant")),
			"p": e.global_position,
			"y": e.rotation.y,
			"a": String(e.call("net_action")),
			"d": bool(e.call("is_dead")),
		})
	# Chunk so each unreliable packet stays under the MTU.
	var chunk: Array = []
	for entry in list:
		chunk.append(entry)
		if chunk.size() >= 6:
			net_enemy_snapshot.rpc(chunk)
			chunk = []
	if not chunk.is_empty():
		net_enemy_snapshot.rpc(chunk)

func _send_enemy_roster() -> void:
	var ids := PackedInt32Array()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not bool(e.get("puppet")):
			ids.append(int(e.get("net_id")))
	net_enemy_roster.rpc(ids)

@rpc("authority", "unreliable_ordered", "call_remote")
func net_enemy_snapshot(list: Array) -> void:
	for entry in list:
		var id: int = int(entry["id"])
		var puppet = _puppets.get(id)
		if puppet == null or not is_instance_valid(puppet):
			puppet = _spawn_puppet(id, String(entry["v"]))
		puppet.call("apply_net", entry["p"], entry["y"], String(entry["a"]), bool(entry["d"]))

@rpc("authority", "reliable", "call_remote")
func net_enemy_roster(ids: PackedInt32Array) -> void:
	var keep: Dictionary = {}
	for id in ids:
		keep[int(id)] = true
	for id in _puppets.keys():
		if not keep.has(int(id)):
			var puppet = _puppets[id]
			if is_instance_valid(puppet):
				puppet.queue_free()
			_puppets.erase(id)

func _spawn_puppet(id: int, variant: String) -> Node:
	var e := Enemy.new()
	e.puppet = true
	e.net_id = id
	e.variant = variant
	_remotes.add_child(e)
	_puppets[id] = e
	print("COOP puppet id=%d variant=%s" % [id, variant])
	return e

# --- combat ------------------------------------------------------------------

## Client -> host: resolve my shot.
func report_fire(origin: Vector3, direction: Vector3, damage: float) -> void:
	net_client_fire.rpc_id(1, origin, direction, damage)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func net_client_fire(origin: Vector3, direction: Vector3, damage: float) -> void:
	if not Net.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var world := (gm as Node3D).get_world_3d()
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * 300.0)
	query.collide_with_areas = false
	var proxy = _proxies.get(sender)
	if proxy != null and is_instance_valid(proxy):
		query.exclude = [proxy.get_rid()]
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return
	var collider = result.collider
	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(damage)
		if collider.is_in_group("enemies"):
			net_hit_confirm.rpc_id(sender)

@rpc("authority", "reliable", "call_remote")
func net_hit_confirm() -> void:
	if gm != null and gm.has_method("_on_hit_confirmed"):
		gm._on_hit_confirmed()

@rpc("authority", "reliable", "call_remote")
func net_apply_damage(amount: float) -> void:
	var p := _local_player()
	if p == null:
		return
	var h := p.get_node_or_null("Health")
	if h != null and h.has_method("take_damage"):
		h.take_damage(amount)

# --- loot (host-authoritative) ----------------------------------------------

## Client -> host: I walked into loot `index`.
func request_pickup(index: int) -> void:
	net_request_pickup.rpc_id(1, index)

@rpc("any_peer", "reliable", "call_remote")
func net_request_pickup(index: int) -> void:
	if not Net.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var who: Node3D = _proxies.get(sender) if sender != 1 else _local_player()
	if who == null or not is_instance_valid(who):
		return
	if gm != null and gm.has_method("host_try_pickup"):
		gm.host_try_pickup(index, who.global_position)

## Host -> everyone: loot `index` is gone.
func broadcast_loot_taken(index: int) -> void:
	net_loot_taken.rpc(index)

@rpc("authority", "reliable", "call_remote")
func net_loot_taken(index: int) -> void:
	if gm != null and gm.has_method("on_loot_taken_remote"):
		gm.on_loot_taken_remote(index)

# --- shared objective --------------------------------------------------------

func broadcast_intel(count: int) -> void:
	net_intel.rpc(count)

@rpc("authority", "reliable", "call_remote")
func net_intel(count: int) -> void:
	if gm != null and gm.has_method("on_intel_remote"):
		gm.on_intel_remote(count)
