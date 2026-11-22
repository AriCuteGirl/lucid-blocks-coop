extends Node
# A/B probe: load a disposable world, spawn mobs near the player, attack until they die, repeat.
# Works with or without the co-op mod. Progress goes to a step file so a native crash is located.
var seeded := false
var out := ""
var rounds := 6
var only := ""
var beat := 0

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("rounds="): rounds = int(a.substr(7))
		if a.begins_with("only="): only = a.substr(5)
	get_tree().node_added.connect(_observe)
	_scan(get_tree().root)

func _ready() -> void:
	call_deferred("_run")

func _scan(n: Node) -> void:
	_observe(n)
	for c in n.get_children(): _scan(c)

func _observe(n: Node) -> void:
	if n.get_script() == null: return
	var p: String = n.get_script().resource_path
	if p == "res://main/save_file/save_file_manager.gd":
		if n.is_node_ready(): _seed(n)
		elif not n.ready.is_connected(_seed.bind(n)): n.ready.connect(_seed.bind(n), CONNECT_ONE_SHOT)

func _seed(m: Node) -> void:
	m.device_file.set_data("save_version", ProjectSettings.get_setting("application/config/version"))
	m.device_file.set_data("shaders_baked", true)
	m.device_file.set_data("tutorial", false)
	m.settings_file.set_data("render_distance", 64.0)
	seeded = true

func step(s: String) -> void:
	print("COMBAT_STEP ", s)
	var f := FileAccess.open(out, FileAccess.READ_WRITE if FileAccess.file_exists(out) else FileAccess.WRITE)
	f.seek_end()
	f.store_line("%d %s" % [Time.get_ticks_msec(), s])
	f.close()

func _wait(pred: Callable, secs: float) -> bool:
	var d := Time.get_ticks_msec() + int(secs * 1000)
	while not pred.call():
		if Time.get_ticks_msec() > d: return false
		await get_tree().create_timer(0.1, true, false, true).timeout
	return true

func _sleep(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _run() -> void:
	if not await _wait(func(): return seeded and Ref.main != null and Ref.main.loaded, 120.0):
		step("DEADLINE menu"); get_tree().quit(2); return
	step("menu mod=%s" % ("coop_manager" in Ref))
	var files = Ref.save_file_manager
	files.initialize_file()
	var reg = files.loaded_file_register
	var settings := {"dimension": 1, "divine": true, "progression_disabled": true, "world_seed": 12345, "find_spawn": false, "reset_world": false, "title": "Disposable combat probe"}
	for k in settings: reg.set_data(k, settings[k], true)
	files.initialize_save_file_directory(reg.get_data("uuid"), false)
	files.load_file(reg)
	await Ref.main.enter_game()
	if not await _wait(func(): return Ref.world.load_enabled and Ref.world.is_all_loaded() and not Ref.player.disabled, 180.0):
		step("DEADLINE world"); get_tree().quit(2); return
	Ref.player.invincible = true
	step("world loaded")
	var list: Array = []
	for d in DirAccess.get_directories_at("res://main/entity"):
		for file in DirAccess.get_files_at("res://main/entity/" + d):
			var name_value: String = file.trim_suffix(".remap")
			if name_value == d + ".tscn" and d not in ["player", "entity"] and (only == "" or d in only.split(",")):
				list.append("res://main/entity/%s/%s.tscn" % [d, d])
	step("mobs %d" % list.size())
	for r in range(rounds):
		for path in list:
			var scene = load(path)
			if not scene is PackedScene: continue
			var mob = scene.instantiate()
			if not mob is Entity:
				mob.free(); continue
			step("round %d spawn %s" % [r, path.get_file()])
			get_tree().get_root().add_child(mob)
			mob.global_position = Ref.player.global_position + Vector3(2.0, 1.5, 0).rotated(Vector3.UP, randf() * TAU)
			await _sleep(0.4)
			for h in range(25):
				if not is_instance_valid(mob) or mob.dead: break
				mob.disabled = false
				Ref.player.get_node("%Attack").attack(mob, mob.global_position, 22.0, 0.15)
				await get_tree().physics_frame
				if not is_instance_valid(mob) or mob.dead: break
				mob.direct_damage_cooldown = false
				await get_tree().create_timer(0.03, true, false, true).timeout
			step("hit done %s valid=%s dead=%s" % [path.get_file(), is_instance_valid(mob), is_instance_valid(mob) and mob.dead])
			if is_instance_valid(mob) and not mob.dead: mob.die()
			await _sleep(0.3)
			if is_instance_valid(mob) and not mob.is_queued_for_deletion() and not mob.dead: mob.queue_free()
	await _sleep(3.0)
	step("FINISHED")
	get_tree().quit(0)
