class_name SceneSnapshot extends VBoxContainer

signal pressed(scene:Scene)

var custom_size = Vector2(200, 200)

var texture_button:TextureButton
var label:Label
var scene:Scene

func _init(scene:Scene) -> void:
	self.scene = scene
	
	texture_button = TextureButton.new()
	texture_button.texture_normal = scene.subviewport.get_texture()
	texture_button.custom_minimum_size = custom_size
	texture_button.ignore_texture_size = true
	texture_button.stretch_mode = TextureButton.STRETCH_SCALE
	texture_button.pressed.connect(on_button_pressed)
	add_child(texture_button)
	
	label = Label.new()
	label.text = scene.scene_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

func on_button_pressed() -> void:
	pressed.emit(scene)
