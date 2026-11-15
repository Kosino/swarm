## Headless entry:
##   Godot --headless --path godot --script res://mycelium/headless.gd
extends SceneTree


func _init() -> void:
	## Must run synchronously — deferred never fires under --script alone.
	var runner := MyceliumHeadless.new()
	var result: Dictionary = runner.run()
	print(JSON.stringify(result, "\t"))
	quit(0 if bool(result.get("ok", false)) else 1)
