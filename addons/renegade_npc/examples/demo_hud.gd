## DemoHUD: Debug overlay showing NPC system stats in real-time.
## Shows: NPC count, realized count, active drives, reputation, game clock.
## Press F1 to toggle detailed per-NPC view.
## Press F2 to fire a test gunshot event.
## Press F3 to modify reputation with La Mirada.
## Press F7 to kill nearest NPC. F8 to heal. F9 to cycle drive.
## Press [ / ] to step time scale down/up. \ to reset.
## Press F10 to toggle fly cam (WASD + mouse, Q/E up/down, Shift fast).
extends CanvasLayer

var _label: RichTextLabel
var _show_detail: bool = false
var _show_trajectories: bool = true

## --- Invariant tracking ---
var _invariant_timer: float = 0.0
var _invariant_warnings: PackedStringArray = []
## Maps npc_id → { "node": ActivityNode, "timestamp": float (real-time) }
var _npc_activity_tracker: Dictionary = {}

## Drive cycle order for F9
const DRIVE_CYCLE: Array[String] = ["idle", "patrol", "threat", "flee", "socialize"]

## --- Time scale stepping ---
## Negative = sky rewinds, 0 = paused, positive = fast-forward.
const TIME_STEPS: Array[int] = [-50, -20, -10, -5, -2, -1, 0, 1, 2, 5, 10, 20, 50]
var _time_step_index: int = 7  # default = 1 (normal speed)
var _sky_weather: SkyWeather = null

## --- Fly cam ---
const FLY_SPEED: float = 20.0
const FLY_FAST_SPEED: float = 60.0
const FLY_MOUSE_SENS: float = 0.003
var _fly_cam: Camera3D = null
var _fly_cam_active: bool = false
var _fly_last_ticks: int = 0


func _ready() -> void:
	# Build the HUD
	_label = RichTextLabel.new()
	_label.name = "DebugLabel"
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.fit_content = true
	_label.position = Vector2(10, 10)
	_label.size = Vector2(500, 800)
	_label.add_theme_font_size_override("normal_font_size", 14)
	_label.add_theme_font_size_override("bold_font_size", 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	# Semi-transparent background panel behind the text
	var panel := Panel.new()
	panel.name = "BG"
	panel.position = Vector2(5, 5)
	panel.size = Vector2(510, 800)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	move_child(panel, 0)  # Behind the label

	# Instructions label at the bottom
	var help := Label.new()
	help.text = "F1: Detail | F2: Gunshot | F3: Rep | F4: Dmg | F5: Trajectories | F7: Kill | F8: Heal | F9: Drive | [ ]: Time | \\: Reset | F10: Fly cam"
	help.position = Vector2(10, 0)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_top = -30
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(help)

	# Cache SkyWeather reference (sibling node in the demo scene)
	_sky_weather = get_parent().get_node_or_null("SkyWeather") as SkyWeather

	# Start in fly cam mode by default (deferred so player node is ready)
	_toggle_fly_cam.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	# Fly cam mouse look
	if _fly_cam_active and _fly_cam and event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_fly_cam.rotate_y(-event.relative.x * FLY_MOUSE_SENS)
			_fly_cam.rotate_object_local(Vector3.RIGHT, -event.relative.y * FLY_MOUSE_SENS)
			# Clamp pitch
			var rot := _fly_cam.rotation
			rot.x = clampf(rot.x, -PI * 0.49, PI * 0.49)
			_fly_cam.rotation = rot
			get_viewport().set_input_as_handled()
		return

	# Fly cam: Esc toggles mouse capture
	if _fly_cam_active and event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_home") or (event is InputEventKey and event.pressed and event.keycode == KEY_F1):
		_show_detail = not _show_detail

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F2:
				_fire_test_gunshot()
			KEY_F3:
				_toggle_reputation()
			KEY_F4:
				_damage_nearest_npc()
			KEY_F5:
				_toggle_trajectories()
			KEY_F7:
				_kill_nearest_npc()
			KEY_F8:
				_heal_nearest_npc()
			KEY_F9:
				_cycle_nearest_npc_drive()
			KEY_F10:
				_toggle_fly_cam()
			KEY_BRACKETLEFT:
				_step_time(-1)
			KEY_BRACKETRIGHT:
				_step_time(1)
			KEY_BACKSLASH:
				_reset_time()


func _process(_delta: float) -> void:
	_update_hud()

	if _fly_cam_active:
		_process_fly_cam()

	# Throttled invariant check (every 2s real-time)
	var now := Time.get_ticks_msec() / 1000.0
	# Use a simple real-time timer instead of delta (which is 0 when paused)
	if now - _invariant_timer >= 2.0:
		_invariant_timer = now
		_check_invariants()


## --- TIME SCALE ---

func _step_time(direction: int) -> void:
	_time_step_index = clampi(_time_step_index + direction, 0, TIME_STEPS.size() - 1)
	_apply_time_scale()


func _reset_time() -> void:
	_time_step_index = 7  # 1x normal
	_apply_time_scale()


func _apply_time_scale() -> void:
	var step: int = TIME_STEPS[_time_step_index]
	var clock = get_node_or_null("/root/GameClock")

	if step > 0:
		# Forward: Engine scales everything, sky runs forward
		Engine.time_scale = float(step)
		if _sky_weather:
			_sky_weather.time_scale = 1
		if clock and clock.has_method("resume_clock"):
			clock.resume_clock()
	elif step < 0:
		# Rewind: Engine scales NPC/physics speed, sky runs backward
		Engine.time_scale = float(-step)
		if _sky_weather:
			_sky_weather.time_scale = -1
		# Pause GameClock so game-time doesn't advance while sky rewinds
		if clock and clock.has_method("pause_clock"):
			clock.pause_clock()
	else:
		# Paused: delta = 0 everywhere, fly cam uses real time
		Engine.time_scale = 0.0
		if _sky_weather:
			_sky_weather.time_scale = 0
		if clock and clock.has_method("pause_clock"):
			clock.pause_clock()

	print("[Demo] Time step: %dx%s" % [step,
		" (rewind)" if step < 0 else " (paused)" if step == 0 else ""])


## --- FLY CAM ---

func _toggle_fly_cam() -> void:
	_fly_cam_active = not _fly_cam_active
	var player := get_tree().get_first_node_in_group("player") as Node3D

	if _fly_cam_active:
		_fly_cam = Camera3D.new()
		_fly_cam.name = "FlyCam"

		# Add to scene root first so global transforms work
		get_parent().add_child(_fly_cam)

		# 3/4 overhead view: high up, angled down ~60°
		var look_target := Vector3.ZERO
		if player:
			look_target = player.global_position
		_fly_cam.global_position = look_target + Vector3(15, 25, 15)
		_fly_cam.look_at(look_target)
		_fly_cam.current = true
		_fly_last_ticks = Time.get_ticks_msec()

		# Disable player movement and camera
		if player:
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("[Demo] Fly cam ON")
	else:
		# Restore player camera
		if player:
			var player_cam := player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
			if player_cam:
				player_cam.current = true
			player.set_physics_process(true)
			player.set_process_unhandled_input(true)

		if _fly_cam:
			_fly_cam.queue_free()
			_fly_cam = null

		print("[Demo] Fly cam OFF")


func _process_fly_cam() -> void:
	if not _fly_cam:
		return

	# Use real time so it works even when Engine.time_scale = 0 (paused)
	var now := Time.get_ticks_msec()
	var real_delta := float(now - _fly_last_ticks) / 1000.0
	_fly_last_ticks = now
	real_delta = minf(real_delta, 0.1)  # Clamp to avoid huge jumps

	var speed := FLY_FAST_SPEED if Input.is_key_pressed(KEY_SHIFT) else FLY_SPEED
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.z -= 1
	if Input.is_key_pressed(KEY_S): input_dir.z += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_key_pressed(KEY_E): input_dir.y += 1
	if Input.is_key_pressed(KEY_Q): input_dir.y -= 1

	if input_dir.length_squared() > 0.001:
		input_dir = input_dir.normalized()
		_fly_cam.global_translate(_fly_cam.global_basis * input_dir * speed * real_delta)


## --- HUD ---

func _update_hud() -> void:
	var text := ""

	# Header
	text += "[b][color=cyan]═══ RENEGADE NPC DEMO ═══[/color][/b]\n"

	# Fly cam indicator
	if _fly_cam_active:
		text += "[color=magenta]FLY CAM[/color]  WASD+Mouse  Q/E=up/down  Shift=fast\n"

	# Time scale indicator
	var step: int = TIME_STEPS[_time_step_index]
	if step > 1:
		text += "[color=yellow]⏩ TIME: %dx[/color]\n" % step
	elif step == 0:
		text += "[color=red]⏸ PAUSED[/color]\n"
	elif step < 0:
		text += "[color=orange]⏪ REWIND: %dx[/color]\n" % step

	text += "\n"

	# Sky time (from SkyWeather directly)
	if _sky_weather:
		text += "[color=yellow]Sky:[/color] %s  Day %d  (%s)\n" % [
			_sky_weather.get_time_string(), _sky_weather.day_count, _sky_weather.get_period()
		]

	# Clock
	var clock = get_node_or_null("/root/GameClock")
	if clock:
		text += "[color=yellow]Clock:[/color] %s\n" % clock.get_time_string()

	# Stats
	var manager = get_node_or_null("/root/NPCManager")
	if manager:
		var stats: Dictionary = manager.get_stats()
		text += "\n[b][color=lime]── NPC Stats ──[/color][/b]\n"
		text += "Total: [b]%d[/b]  Alive: [b]%d[/b]  Realized: [b]%d[/b]  Blocks: [b]%d[/b]\n" % [
			stats.get("total", 0), stats.get("alive", 0),
			stats.get("realized", 0), stats.get("blocks", 0)
		]

	# Reputation
	var rep_mgr = get_node_or_null("/root/ReputationManager")
	if rep_mgr:
		text += "\n[b][color=orange]── Player Reputation ──[/color][/b]\n"
		for faction: String in rep_mgr.city_reputation:
			var rep: float = rep_mgr.city_reputation[faction]
			var standing: String = rep_mgr.get_player_standing(faction)
			var color: String = _rep_color(standing)
			text += "  %s: [color=%s]%.0f (%s)[/color]\n" % [faction, color, rep, standing]
		if rep_mgr.city_reputation.is_empty():
			text += "  [color=gray](no faction rep yet)[/color]\n"

	# Invariant warnings
	if not _invariant_warnings.is_empty():
		text += "\n[b][color=red]── Warnings ──[/color][/b]\n"
		for warning: String in _invariant_warnings:
			text += "[color=red]%s[/color]\n" % warning

	# Realized NPCs detail
	if manager and _show_detail:
		text += "\n[b][color=aqua]── Realized NPCs (F1 toggle) ──[/color][/b]\n"
		var realized: Dictionary = manager._realized_npcs
		if realized.is_empty():
			text += "  [color=gray](none realized - move closer to NPCs)[/color]\n"
		else:
			for npc_id: String in realized:
				var rnpc: RealizedNPC = realized[npc_id]
				if not is_instance_valid(rnpc):
					continue
				var a: AbstractNPC = rnpc.abstract
				var drive_color := _drive_color(rnpc.get_active_drive())
				var p := a.personality
				text += "\n  [b]%s[/b] [%s]\n" % [a.data.npc_name, a.data.faction]
				text += "    Drive: [color=%s]%s[/color]  HP: %d/%d\n" % [
					drive_color, rnpc.get_active_drive(), a.current_health, a.data.max_health
				]
				text += "    Grit:%.1f Hust:%.1f Emp:%.1f → Agg:%.1f Inf:%.1f Anx:%.1f\n" % [
					p.grit, p.hustle, p.empathy, p.aggression, p.influence, p.anxiety
				]
				# Show player memory if exists
				if a.social_memories.has("player"):
					var mem: SocialMemory = a.social_memories["player"]
					text += "    Player memory: disp=%.2f trust=%.2f know=%.2f\n" % [
						mem.get_disposition(), mem.get_trust(), mem.know
					]
	elif manager:
		text += "\n[color=gray]Press F1 for per-NPC detail[/color]\n"
		# Show drive summary
		var drive_counts: Dictionary = {}
		for npc_id: String in manager._realized_npcs:
			var rnpc = manager._realized_npcs[npc_id]
			if is_instance_valid(rnpc):
				var d: String = rnpc.get_active_drive()
				drive_counts[d] = drive_counts.get(d, 0) + 1
		if not drive_counts.is_empty():
			text += "\n[b]Active Drives:[/b] "
			var parts: PackedStringArray = []
			for d: String in drive_counts:
				parts.append("[color=%s]%s×%d[/color]" % [_drive_color(d), d, drive_counts[d]])
			text += ", ".join(parts) + "\n"

	_label.text = text

	# Resize background
	var bg: Panel = get_node_or_null("BG")
	if bg:
		bg.size.y = _label.get_content_height() + 20


## --- NPC ACTIONS ---

func _fire_test_gunshot() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var pos: Vector3 = player.global_position + player.global_basis.z * -3.0
		NPCManager.broadcast_threat({"position": pos, "type": "gunfire"})
		print("[Demo] Gunshot event at ", pos)


func _toggle_trajectories() -> void:
	_show_trajectories = not _show_trajectories
	for node: Node in get_tree().get_nodes_in_group("trajectory_lines"):
		node.visible = _show_trajectories
	print("[Demo] Trajectories: %s" % ("ON" if _show_trajectories else "OFF"))


func _toggle_reputation() -> void:
	var rep_mgr = get_node_or_null("/root/ReputationManager")
	if rep_mgr:
		# Alternate between positive and negative
		var current: float = rep_mgr.city_reputation.get(NPCConfig.Factions.LA_MIRADA, 0.0)
		var amount: float = -10.0 if current >= 0.0 else 10.0
		rep_mgr.modify_reputation(NPCConfig.Factions.LA_MIRADA, amount, "downtown_east")
		print("[Demo] La Mirada rep modified by %.0f → %.0f" % [amount, rep_mgr.city_reputation.get(NPCConfig.Factions.LA_MIRADA, 0.0)])


func _damage_nearest_npc() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var nearest: RealizedNPC = null
	var nearest_dist: float = INF
	for npc: Node in get_tree().get_nodes_in_group("realized_npcs"):
		if npc is RealizedNPC:
			var dist: float = player.global_position.distance_to(npc.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = npc
	if nearest and nearest_dist < 20.0:
		nearest.take_damage(25, player)
		print("[Demo] Damaged %s for 25 HP (now %d/%d)" % [
			nearest.abstract.data.npc_name, nearest.abstract.current_health, nearest.abstract.data.max_health
		])


## Find the nearest realized NPC within 20m of the player.
func _find_nearest_npc() -> RealizedNPC:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return null
	var nearest: RealizedNPC = null
	var nearest_dist: float = INF
	for npc: Node in get_tree().get_nodes_in_group("realized_npcs"):
		if npc is RealizedNPC:
			var dist: float = player.global_position.distance_to(npc.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = npc
	if nearest and nearest_dist < 20.0:
		return nearest
	return null


func _kill_nearest_npc() -> void:
	var nearest := _find_nearest_npc()
	if nearest:
		nearest.take_damage(9999, get_tree().get_first_node_in_group("player"))
		print("[Demo] Killed %s" % nearest.abstract.data.npc_name)


func _heal_nearest_npc() -> void:
	var nearest := _find_nearest_npc()
	if nearest:
		var max_hp: int = nearest.abstract.data.max_health
		nearest.abstract.current_health = max_hp
		print("[Demo] Healed %s to %d/%d" % [
			nearest.abstract.data.npc_name, max_hp, max_hp
		])


func _cycle_nearest_npc_drive() -> void:
	var nearest := _find_nearest_npc()
	if not nearest:
		return
	var current_drive: String = nearest.get_active_drive()
	var idx: int = DRIVE_CYCLE.find(current_drive)
	var next_idx: int = (idx + 1) % DRIVE_CYCLE.size() if idx >= 0 else 0
	var new_drive: String = DRIVE_CYCLE[next_idx]

	# Force the drive by writing directly to the NPC's internal state
	var old_drive: String = nearest._active_drive
	nearest._active_drive = new_drive
	nearest.abstract.current_drive = new_drive
	nearest.drive_changed.emit(new_drive)
	nearest._on_drive_changed(old_drive, new_drive)
	print("[Demo] Forced %s drive: %s → %s" % [
		nearest.abstract.data.npc_name, old_drive, new_drive
	])


## --- INVARIANT CHECKS ---

func _check_invariants() -> void:
	_invariant_warnings.clear()
	var manager = get_node_or_null("/root/NPCManager")
	if not manager:
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	var realized: Dictionary = manager._realized_npcs
	var tracked_ids: Dictionary = {}

	for npc_id: String in realized:
		var rnpc: RealizedNPC = realized[npc_id]
		if not is_instance_valid(rnpc) or not rnpc.abstract.is_alive:
			continue
		tracked_ids[npc_id] = true

		var activity_node: Node3D = rnpc._current_activity_node

		# Update tracker
		if _npc_activity_tracker.has(npc_id):
			var entry: Dictionary = _npc_activity_tracker[npc_id]
			if activity_node == entry.get("node"):
				# Same node — check duration
				var elapsed: float = now - entry["timestamp"]
				if elapsed > 60.0:
					_invariant_warnings.append(
						"⚠ %s stuck at %s for %.0fs+" % [
							rnpc.abstract.data.npc_name,
							_activity_node_name(activity_node),
							elapsed
						]
					)
			else:
				# Changed node — reset tracker
				_npc_activity_tracker[npc_id] = {"node": activity_node, "timestamp": now}
		else:
			_npc_activity_tracker[npc_id] = {"node": activity_node, "timestamp": now}

		# Orphaned occupation: drive changed but still listed as occupant somewhere
		# (heuristic: if drive is idle/flee/threat but has an activity node assigned)
		var drive: String = rnpc.get_active_drive()
		if drive in ["flee", "threat"] and activity_node != null and is_instance_valid(activity_node):
			_invariant_warnings.append(
				"⚠ %s drive=%s but still at activity %s" % [
					rnpc.abstract.data.npc_name, drive, _activity_node_name(activity_node)
				]
			)

	# Clean up tracker for despawned NPCs
	for npc_id: String in _npc_activity_tracker.keys():
		if not tracked_ids.has(npc_id):
			_npc_activity_tracker.erase(npc_id)

	# Over-capacity check on activity nodes
	for node: Node in get_tree().get_nodes_in_group("activity_nodes"):
		if node.has_method("get_occupant_count") and "capacity" in node:
			var count: int = node.get_occupant_count()
			var cap: int = node.capacity
			if count > cap:
				_invariant_warnings.append(
					"⚠ %s over-capacity: %d/%d" % [node.name, count, cap]
				)


func _activity_node_name(node: Node3D) -> String:
	if node == null or not is_instance_valid(node):
		return "(none)"
	if node.has_method("get_activity_type"):
		return "%s (%s)" % [node.name, node.get_activity_type()]
	return node.name


func _rep_color(standing: String) -> String:
	match standing:
		"hostile": return "red"
		"neutral": return "yellow"
		"friendly": return "lime"
		"allied": return "cyan"
		_: return "white"


func _drive_color(drive: String) -> String:
	match drive:
		"idle": return "gray"
		"patrol": return "yellow"
		"flee", "threat": return "red"
		"socialize": return "lime"
		"work": return "cyan"
		"deal": return "orange"
		"guard": return "purple"
		_: return "white"
