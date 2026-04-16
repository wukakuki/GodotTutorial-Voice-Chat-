# Godot Example project for Voice Chat Plugin
The main scene is `scenes/main.tscn `. It works as a root. Level scenes will be loaded in `$Level` and `$MultiplayerSpawner` will sync the level scenes to clients.

The default scene is `scenes/level.tscn`. Player scene will be loaded in `$Players` and `$MultiplayerSpawner` will sync the Player scenes to clients. Each player will be assigned with a player id which equals his multiplayer unique id.

The default player character is `character/player.tscn`. It will check if the current client owns itself in `_ready`:

```gdscript
func _ready():
	if player_id == -1:
		print("didn't receive player id")
		queue_free()
		return
		
	is_local_player = (player_id == multiplayer.get_unique_id())
```

If current client owns the player character, it will join `Default` voice chat group:

```````gdscript
		$RPCGroup.join_group("Default")
```````

and instantiate audio recorder scene, audio listener scene from EmbeddedVoiceChat plugin.

````gdscript
		audio_recorder = audio_recorder_scene.instantiate()
		audio_recorder.bus = record_bus
		# to debug audio, enable below line, it will generate a pcm file for Post-mortem Debugging
		#audio_recorder.debug_audio = true
		$CollisionShape3D/MeshInstance3D.add_child(audio_recorder)
		audio_listener = audio_listener_3d_scene.instantiate()
		# to debug audio, enable below line, it will generate a pcm file for Post-mortem Debugging
		#audio_listener.debug_audio = true
		$CameraPivot/SpringArm3D/Camera3D.add_child(audio_listener)
		audio_listener.make_current()
````

Audio recorder scene is used to capture audio from `record_bus`, which should contain an Audio Effect Capture. You can add other audio effects on top of Audio Effect Capture to make the player sounds like in a special space.

![Screenshot 2026-04-16 at 1.12.48 AM](/Users/siqiwu/Documents/godot tutorial/Screenshot 2026-04-16 at 1.12.48 AM.png)

Audio listener scene is used to capture audio from `Master` bus, which should also contain an Audio Effect Capture. The audio data will be used for echo cancellation system. You can add other audio effects on top of Audio Effect Capture to make the player feels like in a special space.

![Screenshot 2026-04-16 at 2.48.08 PM](/Users/siqiwu/Desktop/Screenshot 2026-04-16 at 2.48.08 PM.png)

The player character also contains a `$AudioStreamPlayer3D`, which will be used to play the audio data from `$RPCGroup`. It should use Audio Stream Generator and be attached with a group node. 

![Screenshot 2026-04-16 at 2.45.35 PM](/Users/siqiwu/Desktop/Screenshot 2026-04-16 at 2.45.35 PM.png)
