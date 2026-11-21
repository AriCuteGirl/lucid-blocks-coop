extends Node
# One-off probe: load a disposable world, call the mod's Steam host path, report whether a
# friends-only lobby and a Steam host peer come up, then leave the lobby and quit.
# Sends no invites. Results go to godot.log as STEAM_PROBE lines.
var seeded := false
var checks := 0
var failures := 0

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_observe)
	_scan(get_tree().root)

func _ready() -> void:
	call_deferred("_run")

func _scan(node: Node) -> void:
	_observe(node)
	for child in node.get_children():
		_scan(child)

func _observe(node: Node) -> void:
	if node.get_script() == null:
		return
	var p: String = node.get_script().resource_path
	if p == "res://main/items/icon_generator/icon_generator.gd":
		node.skip = true
	if p == "res://main/save_file/save_file_manager.gd":
		if node.is_node_ready():
			_seed(node)
		elif not node.ready.is_connected(_seed.bind(node)):
			node.ready.connect(_seed.bind(node), CONNECT_ONE_SHOT)

func _seed(m: Node) -> void:
	m.device_file.set_data("save_version", ProjectSettings.get_setting("application/config/version"))
	m.device_file.set_data("shaders_baked", true)
	m.device_file.set_data("tutorial", false)
	seeded = true

var beat_path := ""
func _step(name_value: String) -> void:
	print("STEAM_PROBE_STEP ", name_value)
	if beat_path != "":
		var f := FileAccess.open(beat_path + ".steps", FileAccess.READ_WRITE if FileAccess.file_exists(beat_path + ".steps") else FileAccess.WRITE)
		f.seek_end()
		f.store_line("%d %s" % [Time.get_ticks_msec(), name_value])
		f.close()

func _process(_delta: float) -> void:
	if beat_path != "" and Engine.get_process_frames() % 10 == 0:
		var f := FileAccess.open(beat_path, FileAccess.WRITE)
		f.store_string(str(Time.get_ticks_msec()))
		f.close()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("STEAM_PROBE_CHECK ", "PASS " if ok else "FAIL ", label)

func _wait(pred: Callable, label: String, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not pred.call():
		if Time.get_ticks_msec() > deadline:
			check(false, "deadline " + label)
			return false
		await get_tree().create_timer(0.1, true, false, true).timeout
	return true

func _run() -> void:
	var uargs := OS.get_cmdline_user_args()
	var open_invite := uargs.has("invite")
	for a in uargs:
		if a.begins_with("beat="):
			beat_path = a.substr(5)
	_step("start invite=%s" % open_invite)
	if not await _wait(func(): return seeded and Ref.main != null and Ref.main.loaded and Ref.coop_manager != null, "menu", 120.0):
		return _finish()
	var steam = get_node_or_null("/root/Steamworks")
	var api = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if api != null:
		print("STEAM_PROBE steam_running=", api.call("isSteamRunning"), " logged_on=", api.call("loggedOn"), " app=", api.call("getAppID"))
	print("STEAM_PROBE steamworks_node=", steam != null)
	var manager = Ref.coop_manager
	check(manager._can_use_steam_sessions(), "mod sees Steam lobby API and SteamMultiplayerPeer")
	var files = Ref.save_file_manager
	files.initialize_file()
	var reg = files.loaded_file_register
	for k in {"dimension": 1, "divine": true, "progression_disabled": true, "world_seed": 12345, "find_spawn": false, "reset_world": false, "title": "Disposable steam probe"}:
		reg.set_data(k, {"dimension": 1, "divine": true, "progression_disabled": true, "world_seed": 12345, "find_spawn": false, "reset_world": false, "title": "Disposable steam probe"}[k], true)
	files.initialize_save_file_directory(reg.get_data("uuid"), false)
	files.load_file(reg)
	await Ref.main.enter_game()
	if not await _wait(func(): return Ref.world.load_enabled and Ref.world.is_all_loaded() and not Ref.player.disabled, "world loaded", 180.0):
		return _finish()
	_step("world loaded, calling host_steam_session")
	if open_invite:
		manager.host_steam_session(true)
	else:
		manager.host_steam_session()
	_step("host_steam_session returned")
	var ok := await _wait(func(): return manager.active_steam_lobby_id > 0 and manager._has_live_peer(), "lobby + Steam host peer", 30.0)
	_step("after wait: " + manager.status_message)
	if open_invite:
		await get_tree().create_timer(5.0, true, false, true).timeout
		_step("5s after invite: " + manager.status_message)
	print("STEAM_PROBE status=", manager.status_message, " lobby=", manager.active_steam_lobby_id)
	if ok:
		check(true, "friends-only lobby created and Steam host peer live")
		check(multiplayer.is_server(), "host is multiplayer server")
		if not open_invite:
			check(manager.status_message.begins_with("Hosting Steam lobby"), "default host left the overlay closed")
		if api != null:
			var owner = api.call("getLobbyOwner", manager.active_steam_lobby_id)
			check(int(owner) == int(api.call("getSteamID")), "lobby owner is this account")
			check(str(api.call("getLobbyData", manager.active_steam_lobby_id, manager.STEAM_LOBBY_DATA_TRANSPORT)) == "steam", "lobby advertises steam transport")
	await get_tree().create_timer(3.0, true, false, true).timeout
	_step("shutting down")
	await manager._shutdown_host_session(false, "steam probe finished")
	manager._clear_active_steam_session_state(true)
	_finish()

func _finish() -> void:
	_step("finish")
	print("STEAM_PROBE_RESULT ", checks, " checks ", failures, " failures")
	await get_tree().create_timer(1.0, true, false, true).timeout
	get_tree().quit(1 if failures else 0)
