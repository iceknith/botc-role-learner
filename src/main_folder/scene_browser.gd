extends ScrollContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	
	for sibling in $"..".get_children():
		if sibling as Scene:
			add_new_scene(sibling)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func add_new_scene(new_scene:Scene) -> void:
	var scene_snapshot:SceneSnapshot = SceneSnapshot.new(new_scene)
	
	$HFlowContainer.add_child(scene_snapshot)
	scene_snapshot.pressed.connect($"../../../".select_scene_as_current)
