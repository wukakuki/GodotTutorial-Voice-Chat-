class_name ErrorDisplay
extends Label


var game_instance: GameInstance = null


func _init():
	game_instance = GameInstance.singleton
	game_instance.notification.connect(show_error)


func show_error(level: GameInstance.NotificationLevel, error: String):
	if level <= GameInstance.NotificationLevel.Error:
		text = error


func _on_tab_container_tab_changed(_tab):
	text = ""
