## RealizedNPC: The full physical NPC spawned when the player is nearby.
## Composed of Godot built-in nodes + utility module system.
## Created/destroyed by NPCManager based on player proximity.
##
## Expected scene tree (auto-configured if not present):
##   RealizedNPC (CharacterBody3D)
##   ├── CollisionShape3D
##   ├── Model (Node3D placeholder for model scene)
##   ├── NavigationAgent3D
##   ├── InteractionArea (Area3D, ~2.5m)
##   ├── DetectionArea (Area3D, ~15m)
##   └── AnimationTree (optional)
class_name RealizedNPC
extends CharacterBody3D

## Emitted when the NPC's active drive changes.
signal drive_changed(drive_name: String)
## Emitted when the player enters interaction range.
signal player_in_range()
## Emitted when the player leaves interaction range.
signal player_out_of_range()
## Emitted when this NPC takes damage.
signal damaged(amount: int, source: Node)
## Emitted when this NPC dies.
signal died()

## --- References ---
var abstract: AbstractNPC = null
var data: NPCData:
	get: return abstract.data if abstract else null

## --- Utility AI ---
var _modules: Array[UtilityModule] = []
var _active_module: UtilityModule = null
var _active_drive: String = "idle"
var _utility_eval_timer: float = 0.0
var UTILITY_EVAL_INTERVAL: float = NPCConfig.Realized.UTILITY_EVAL_INTERVAL

## --- Navigation ---
var nav_agent: NavigationAgent3D = null
var _move_target: Vector3 = Vector3.ZERO
var _is_moving: bool = false

## --- Activity ---
var _current_activity_node: Node3D = null
var _activity_timer: float = 0.0
## Cooldown after completing a timed activity — suppresses that type in scoring.
var _activity_cooldown: float = 0.0
var _last_completed_activity: String = ""
var _visited_patrol_nodes: Array[Node3D] = []
var _nav_elapsed: float = 0.0

## --- State ---
var _player_nearby: bool = false
var _wander_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("realized_npcs")

	_setup_navigation()
	_setup_areas()


## Initialize from an AbstractNPC record. Called by NPCManager.
func initialize(p_abstract: AbstractNPC) -> void:
	abstract = p_abstract
	abstract.is_realized = true

	# Apply data
	if abstract.world_position != Vector3.ZERO:
		global_position = abstract.world_position

	# Modules need abstract to be set (e.g. for personality)
	_setup_modules()


func _setup_navigation() -> void:
	nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if not nav_agent:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 1.0
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.4
		nav_agent.max_speed = data.run_speed if data else 6.0
		add_child(nav_agent)

	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.navigation_finished.connect(_on_navigation_finished)


func _setup_areas() -> void:
	# Interaction area
	var interact_area: Area3D = get_node_or_null("InteractionArea")
	if not interact_area:
		interact_area = Area3D.new()
		interact_area.name = "InteractionArea"
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = data.interaction_range if data else 2.5
		shape.shape = sphere
		interact_area.add_child(shape)
		add_child(interact_area)
	
	interact_area.body_entered.connect(_on_interaction_body_entered)
	interact_area.body_exited.connect(_on_interaction_body_exited)
	
	# Detection area
	var detect_area: Area3D = get_node_or_null("DetectionArea")
	if not detect_area:
		detect_area = Area3D.new()
		detect_area.name = "DetectionArea"
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = data.detection_range if data else 15.0
		shape.shape = sphere
		detect_area.add_child(shape)
		add_child(detect_area)


func _setup_modules() -> void:
	# Create standard module set
	var module_classes: Array = [
		IdleModule,
		ThreatModule,
		OpportunityModule,
		SocialModule,
		FleeModule,
	]
	
	for ModuleClass: Variant in module_classes:
		var module: UtilityModule = ModuleClass.new()
		module.setup(self, abstract)
		
		# Apply weight overrides from NPCData
		var module_name: String = module.get_module_name()
		if data and data.module_weight_overrides.has(module_name):
			module.weight = data.module_weight_overrides[module_name]
		
		_modules.append(module)


func _physics_process(delta: float) -> void:
	if not abstract or not abstract.is_alive:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	# Tick down activity cooldown
	_activity_cooldown = maxf(_activity_cooldown - delta, 0.0)

	# Process movement FIRST — targets were set on the previous frame,
	# giving NavigationServer time to compute the path.
	if _is_moving:
		_process_movement(delta)
	elif not is_on_floor():
		move_and_slide()

	# Periodic utility evaluation
	_utility_eval_timer += delta
	if _utility_eval_timer >= UTILITY_EVAL_INTERVAL:
		_utility_eval_timer = 0.0
		_evaluate_utilities()

	# Execute current drive (may set new navigation targets for next frame)
	_execute_drive(delta)


## --- UTILITY AI CORE ---

func _evaluate_utilities() -> void:
	# Decay short-term emotions in real time so flee/threat states recover
	# without waiting for the game clock cycle_tick (which can be minutes).
	var decay_amount: float = UTILITY_EVAL_INTERVAL * NPCConfig.Realized.EMOTION_DECAY_RATE
	for target_id: String in abstract.social_memories:
		var mem: SocialMemory = abstract.social_memories[target_id]
		mem.temp_fear = maxf(mem.temp_fear - decay_amount, 0.0)
		mem.temp_like = maxf(mem.temp_like - decay_amount, 0.0)

	var best_module: UtilityModule = null
	var best_score: float = -1.0

	for module: UtilityModule in _modules:
		var score: float = module.get_weighted_score()
		if score > best_score:
			best_score = score
			best_module = module
	
	if best_module and best_module != _active_module:
		_active_module = best_module
		var new_drive: String = best_module.get_drive_name()
		if new_drive != _active_drive:
			var old_drive := _active_drive
			_active_drive = new_drive
			abstract.current_drive = new_drive
			drive_changed.emit(new_drive)
			_on_drive_changed(old_drive, new_drive)


func _on_drive_changed(old_drive: String, new_drive: String) -> void:
	# Release previous activity node before switching
	_release_current_activity()
	_activity_timer = 0.0

	# Start new drive behavior
	match new_drive:
		"flee", "threat":
			_start_flee()
		"patrol":
			_find_patrol_node()
		"deal", "work", "socialize":
			_find_activity_for_drive(new_drive)
		"idle":
			_start_idle()


## --- DRIVE EXECUTION ---

func _execute_drive(delta: float) -> void:
	match _active_drive:
		"idle":
			_do_idle(delta)
		"flee", "threat":
			_do_flee(delta)
		"patrol":
			_do_patrol(delta)
		"socialize":
			_do_socialize(delta)
		"work", "deal", "guard":
			_do_activity(delta)


func _do_idle(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		# Pick a random nearby point and wander to it
		_wander_target = global_position + Vector3(
			randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0)
		)
		_navigate_to(_wander_target)
		_wander_timer = randf_range(3.0, 8.0)


func _do_flee(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		_start_flee()  # Keep fleeing until threat subsides


func _do_patrol(delta: float) -> void:
	if _current_activity_node and not is_instance_valid(_current_activity_node):
		_current_activity_node = null
	# Prune freed nodes from visited list
	_visited_patrol_nodes = _visited_patrol_nodes.filter(func(n: Node3D) -> bool: return is_instance_valid(n))
	if _current_activity_node:
		# We have a patrol point — navigate or dwell
		var dist: float = global_position.distance_to(_current_activity_node.global_position)
		if dist > 1.5:
			# Timeout — node is unreachable (inside geometry, bad navmesh, etc.)
			if _nav_elapsed >= NPCConfig.Realized.NAV_TIMEOUT:
				_visited_patrol_nodes.append(_current_activity_node)
				_release_current_activity()
				_activity_timer = 0.0
				_find_patrol_node()
				return
			if not _is_moving:
				_navigate_to(_current_activity_node.global_position)
		else:
			_is_moving = false
			if _current_activity_node.has_method("occupy"):
				_current_activity_node.occupy(self)
			_activity_timer += delta
			if _activity_timer >= NPCConfig.Realized.PATROL_PAUSE:
				# Done at this patrol point — mark visited, release and find next
				_visited_patrol_nodes.append(_current_activity_node)
				_release_current_activity()
				_activity_timer = 0.0
				_find_patrol_node()
	elif nav_agent.is_navigation_finished():
		# No current activity node — find one
		_find_patrol_node()


func _do_socialize(delta: float) -> void:
	var social_mod: SocialModule = _get_module(SocialModule) as SocialModule
	if social_mod and social_mod.get_social_target():
		var target_pos: Vector3 = social_mod.get_social_target().global_position
		var dist: float = global_position.distance_to(target_pos)
		if dist > 3.0:
			_navigate_to(target_pos)
		else:
			_is_moving = false  # Stay near ally


func _do_activity(delta: float) -> void:
	if _current_activity_node and not is_instance_valid(_current_activity_node):
		_current_activity_node = null
	if _current_activity_node:
		var dist: float = global_position.distance_to(_current_activity_node.global_position)
		if dist > 1.5:
			# Timeout — node is unreachable
			if _nav_elapsed >= NPCConfig.Realized.NAV_TIMEOUT:
				_release_current_activity()
				_activity_timer = 0.0
				_utility_eval_timer = UTILITY_EVAL_INTERVAL
				return
			if not _is_moving:
				_navigate_to(_current_activity_node.global_position)
		else:
			_is_moving = false
			if _current_activity_node.has_method("occupy"):
				_current_activity_node.occupy(self)
			_activity_timer += delta
			var duration: float = _current_activity_node.typical_duration if _current_activity_node.has_method("get_activity_type") else 30.0
			if duration > 0.0 and _activity_timer >= duration:
				# Record what we just completed for cooldown
				if _current_activity_node.has_method("get_activity_type"):
					_last_completed_activity = _current_activity_node.get_activity_type()
					_activity_cooldown = NPCConfig.Realized.ACTIVITY_COOLDOWN
				_release_current_activity()
				_activity_timer = 0.0
				# Force re-evaluation instead of auto-chaining same drive
				_utility_eval_timer = UTILITY_EVAL_INTERVAL


func _start_flee() -> void:
	# Flee away from threat sources
	var threat_mod: ThreatModule = _get_module(ThreatModule) as ThreatModule
	var flee_dir := Vector3.FORWARD
	if threat_mod:
		var sources := threat_mod.get_threat_sources()
		if not sources.is_empty():
			var avg_threat_pos := Vector3.ZERO
			for source: Node3D in sources:
				avg_threat_pos += source.global_position
			avg_threat_pos /= float(sources.size())
			flee_dir = (global_position - avg_threat_pos).normalized()
	
	var flee_target := global_position + flee_dir * 20.0
	_navigate_to(flee_target)


func _start_idle() -> void:
	_wander_timer = randf_range(1.0, 3.0)


func _release_current_activity() -> void:
	if _current_activity_node and _current_activity_node.has_method("release"):
		_current_activity_node.release(self)
	_current_activity_node = null


## Find the next patrol node, skipping visited ones. Resets the visited list
## (keeping the last node) if all patrol nodes have been visited.
func _find_patrol_node() -> void:
	_find_activity_for_drive("patrol", _visited_patrol_nodes)
	if not _current_activity_node and not _visited_patrol_nodes.is_empty():
		# All patrol nodes visited — reset but keep last to prevent re-pick
		var last: Node3D = _visited_patrol_nodes.back()
		_visited_patrol_nodes.clear()
		_visited_patrol_nodes.append(last)
		_find_activity_for_drive("patrol", _visited_patrol_nodes)


func _find_activity_for_drive(drive: String, exclude_nodes: Array[Node3D] = []) -> void:
	# Map drive to activity type
	var activity_type := drive

	# Find nearest matching unoccupied activity node
	var best_node: Node3D = null
	var best_dist: float = INF
	var npc_faction: String = get_faction()

	for node: Node in get_tree().get_nodes_in_group("activity_nodes"):
		if not node is Node3D:
			continue
		if node == _current_activity_node:
			continue  # Don't re-pick the spot we just left
		if node in exclude_nodes:
			continue
		if node.has_method("get_activity_type") and node.get_activity_type() == activity_type:
			if node.has_method("is_occupied") and node.is_occupied():
				continue
			if node.has_method("can_use") and not node.can_use(npc_faction):
				continue
			var dist: float = global_position.distance_to(node.global_position)
			if dist < best_dist:
				best_dist = dist
				best_node = node as Node3D
	
	if best_node:
		_current_activity_node = best_node
		if best_node.has_method("occupy"):
			best_node.occupy(self)
		_navigate_to(best_node.global_position)
	else:
		# No activity found, wander instead
		_start_idle()


## --- NAVIGATION ---

func _navigate_to(target: Vector3) -> void:
	nav_agent.target_position = target
	_move_target = target
	_is_moving = true
	_nav_elapsed = 0.0


func _process_movement(delta: float) -> void:
	_nav_elapsed += delta
	if nav_agent.is_navigation_finished():
		_is_moving = false
		if not is_on_floor():
			move_and_slide()
		return

	var next_pos: Vector3 = nav_agent.get_next_path_position()

	# Flatten to XZ plane — navmesh points are at ground level,
	# NPC origin may be above; gravity handles vertical movement.
	var direction := Vector3(
		next_pos.x - global_position.x,
		0.0,
		next_pos.z - global_position.z
	).normalized()

	if direction.length_squared() < 0.001:
		return

	# Choose speed based on drive
	var speed: float = data.move_speed if data else 3.0
	if _active_drive == "flee":
		speed = data.run_speed if data else 6.0

	var desired_velocity: Vector3 = direction * speed

	# Use avoidance — preserve Y velocity (gravity)
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = desired_velocity
	else:
		velocity = Vector3(desired_velocity.x, velocity.y, desired_velocity.z)
		move_and_slide()

	# Face movement direction
	var look_target := global_position + direction
	look_target.y = global_position.y
	if global_position.distance_squared_to(look_target) > 0.001:
		look_at(look_target)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = Vector3(safe_velocity.x, velocity.y, safe_velocity.z)
	move_and_slide()


func _on_navigation_finished() -> void:
	_is_moving = false


## --- INTERACTION ---

func _on_interaction_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		player_in_range.emit()


func _on_interaction_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		player_out_of_range.emit()


## --- PUBLIC API ---

func get_faction() -> String:
	return abstract.data.faction if abstract else "none"


func get_active_drive() -> String:
	return _active_drive


## Returns a dictionary of module_name → weighted score for all utility modules.
func get_module_scores() -> Dictionary:
	var scores: Dictionary = {}
	for module: UtilityModule in _modules:
		scores[module.get_module_name()] = module.get_weighted_score()
	return scores


func take_damage(amount: int, source: Node = null) -> void:
	abstract.current_health = maxi(abstract.current_health - amount, 0)
	damaged.emit(amount, source)
	
	# Record negative memory if source is identifiable
	if source and source.has_method("get_faction"):
		var source_id: String = ""
		if source.is_in_group("player"):
			source_id = "player"
		elif source.has_method("get_npc_id"):
			source_id = source.get_npc_id()
		if not source_id.is_empty():
			var memory := abstract.get_memory(source_id)
			var clock = get_node_or_null("/root/GameClock")
			var time: float = clock.get_total_hours() if clock else 0.0
			memory.add_negative(0.3, time)
	
	# Notify threat module
	var threat_mod: ThreatModule = _get_module(ThreatModule) as ThreatModule
	if threat_mod and source is Node3D:
		threat_mod.notify_gunfire(source.global_position)
	
	if abstract.current_health <= 0:
		_die()


func _die() -> void:
	abstract.is_alive = false
	died.emit()
	# NPCManager handles cleanup


func get_npc_id() -> String:
	return abstract.npc_id if abstract else ""


func is_player_nearby() -> bool:
	return _player_nearby


## Serialize back to abstract when being despawned.
func serialize_to_abstract() -> void:
	if abstract:
		abstract.world_position = global_position
		abstract.current_drive = _active_drive
		abstract.is_realized = false
	
	# Release activity node
	_release_current_activity()


func _get_module(module_class: Variant) -> UtilityModule:
	for module: UtilityModule in _modules:
		if is_instance_of(module, module_class):
			return module
	return null


## Notify all threat modules of a world event (gunfire, explosion).
func on_threat_event(event_data: Dictionary) -> void:
	var threat_mod: ThreatModule = _get_module(ThreatModule) as ThreatModule
	if threat_mod and event_data.has("position"):
		threat_mod.notify_gunfire(event_data["position"])
