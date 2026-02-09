extends SubViewportContainer
## Minimap component: Real top-down camera view of the level.
## Uses a SubViewport with orthographic camera following the player.
## Embed inside a Panel that has the background/rounded corners.

class_name HUDMinimap

## How much of the world is visible (orthographic size in meters)
@export var view_size: float = 30.0

## Height of the camera above the player
@export var camera_height: float = 50.0

## Whether the map rotates with player facing (true) or stays north-up (false)
@export var rotate_with_player: bool = true

## Show player marker overlay
@export var show_player_marker: bool = true

## Player marker color
@export var player_marker_color: Color = Color(0.2, 0.8, 1.0)

## Player marker size
@export var player_marker_size: float = 8.0

## Render unshaded (no lighting)
@export var unshaded: bool = true

## Mask for what layers the minimap camera sees (default excludes layer 2 for ground)
@export_flags_3d_render var camera_cull_mask: int = 0b11111111111111111111111111111101

## Corner radius for rounded corners
@export var corner_radius: float = 8.0

# Shader for rounded corners
const ROUNDED_SHADER := """
shader_type canvas_item;

uniform float radius : hint_range(0.0, 100.0) = 8.0;

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 pixel = UV * size;

	// Check corners
	vec2 tl = vec2(radius, radius);
	vec2 tr = vec2(size.x - radius, radius);
	vec2 bl = vec2(radius, size.y - radius);
	vec2 br = vec2(size.x - radius, size.y - radius);

	float alpha = 1.0;

	if (pixel.x < radius && pixel.y < radius) {
		alpha = 1.0 - smoothstep(radius - 1.0, radius, distance(pixel, tl));
	} else if (pixel.x > size.x - radius && pixel.y < radius) {
		alpha = 1.0 - smoothstep(radius - 1.0, radius, distance(pixel, tr));
	} else if (pixel.x < radius && pixel.y > size.y - radius) {
		alpha = 1.0 - smoothstep(radius - 1.0, radius, distance(pixel, bl));
	} else if (pixel.x > size.x - radius && pixel.y > size.y - radius) {
		alpha = 1.0 - smoothstep(radius - 1.0, radius, distance(pixel, br));
	}

	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
}
"""

# Internal nodes
var _viewport: SubViewport
var _camera: Camera3D
var _player: Node3D = null
var _world_3d: World3D = null


func _ready() -> void:
	# Set up the container
	stretch = true

	# Apply rounded corners shader
	var shader := Shader.new()
	shader.code = ROUNDED_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("radius", corner_radius)
	material = mat

	# Build the viewport
	_build_viewport()

	# Find player
	_find_player()

	# Get the world
	_find_world()


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Viewport"
	_viewport.size = Vector2i(256, 256)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	_viewport.audio_listener_enable_3d = false
	_viewport.positional_shadow_atlas_size = 0
	if unshaded:
		_viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	add_child(_viewport)

	_camera = Camera3D.new()
	_camera.name = "MinimapCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = view_size
	_camera.near = 0.1
	_camera.far = camera_height + 100.0
	_camera.cull_mask = camera_cull_mask
	_camera.rotation_degrees = Vector3(-90, 0, 0)

	# Custom environment with black background (no sky)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	_camera.environment = env

	_viewport.add_child(_camera)


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _find_world() -> void:
	var main_viewport := get_viewport()
	if main_viewport:
		_world_3d = main_viewport.world_3d
		if _world_3d and _viewport:
			_viewport.world_3d = _world_3d


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_find_player()

	if _world_3d == null or (_viewport and _viewport.world_3d == null):
		_find_world()

	if _viewport and size.x > 0 and size.y > 0:
		var new_size := Vector2i(int(size.x), int(size.y))
		if _viewport.size != new_size:
			_viewport.size = new_size

	_update_camera()

	if show_player_marker:
		queue_redraw()


func _update_camera() -> void:
	if not _camera or not is_instance_valid(_player):
		return

	var player_pos := _player.global_position
	_camera.global_position = Vector3(player_pos.x, player_pos.y + camera_height, player_pos.z)
	_camera.size = view_size

	if rotate_with_player:
		var player_yaw := _player.global_rotation.y
		_camera.rotation = Vector3(-PI / 2.0, player_yaw, 0)
	else:
		_camera.rotation = Vector3(-PI / 2.0, 0, 0)


func _draw() -> void:
	if not show_player_marker or not is_instance_valid(_player):
		return

	var center := size / 2.0
	var forward := Vector2(0, -1)

	if not rotate_with_player:
		var player_yaw := _player.global_rotation.y
		forward = Vector2(sin(player_yaw), -cos(player_yaw))

	var right := Vector2(forward.y, -forward.x)
	var tip := center + forward * player_marker_size
	var left_pt := center - forward * player_marker_size * 0.6 - right * player_marker_size * 0.6
	var right_pt := center - forward * player_marker_size * 0.6 + right * player_marker_size * 0.6

	draw_polygon(PackedVector2Array([tip, left_pt, right_pt]), PackedColorArray([player_marker_color, player_marker_color, player_marker_color]))
	draw_polyline(PackedVector2Array([tip, left_pt, right_pt, tip]), player_marker_color.lightened(0.3), 1.5, true)


func set_view_size(meters: float) -> void:
	view_size = maxf(10.0, meters)
	if _camera:
		_camera.size = view_size


func zoom_in(amount: float = 5.0) -> void:
	set_view_size(view_size - amount)


func zoom_out(amount: float = 5.0) -> void:
	set_view_size(view_size + amount)
