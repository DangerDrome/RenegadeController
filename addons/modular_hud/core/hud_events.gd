extends Node
## Minimal event bus for one-off HUD events.
## Registered as autoload by plugin.

signal damage_taken(amount: float, direction: Vector2)
signal notification_requested(text: String)
signal objective_updated(id: String, progress: float)

# Sky/Weather events (emitted by SkyWeather plugin if present)
signal time_changed(hour: float, period: String)
signal weather_changed(weather_name: String)
