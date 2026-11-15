## Headless entry:
##   Godot --headless --path godot --script res://apis/headless.gd
extends SceneTree


func _init() -> void:
	var runner := ApisHeadless.new()
	var result: Dictionary = runner.run()
	print(JSON.stringify(result, "\t"))
	quit(0 if bool(result.get("ok", false)) else 1)
