extends Node
## Minimal event bus for one-off HUD events.
## Registered as autoload by plugin.

signal damage_taken(amount: float, direction: Vector2)
signal notification_requested(text: String)
signal objective_updated(id: String, progress: float)

# Sky/Weather events (emitted by SkyWeather plugin if present)
signal time_changed(hour: float, period: String)
signal weather_changed(weather_name: String)


## Find a node by its class_name in the scene tree.
## Used by HUD components to locate SkyWeather or other nodes.
static func find_node_by_class(root: Node, class_name_str: String) -> Node:
	var script := root.get_script() as Script
	if script and script.get_global_name() == class_name_str:
		return root
	for child in root.get_children():
		var result := find_node_by_class(child, class_name_str)
		if result:
			return result
	return null
