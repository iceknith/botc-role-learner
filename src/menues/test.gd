extends Node2D

func load_img(file) -> ImageTexture:
	var img = Image.new()
	img.load(file)
	return ImageTexture.create_from_image(img)

func set_values(botc_role:Dictionary):
	$SubViewport/VScrollBar/VBoxContainer/Name.text = botc_role["display_name"]
	$SubViewport/VScrollBar/VBoxContainer/TextureRect.texture = load_img(botc_role["image_path"])
	$"SubViewport/VScrollBar/VBoxContainer/Role Type".text = botc_role["category"]
	$SubViewport/VScrollBar/VBoxContainer/QuickSummary.text += botc_role["quick_summary"]
	$SubViewport/VScrollBar/VBoxContainer/Summary.text += botc_role["summary"]
	$SubViewport/VScrollBar/VBoxContainer/HowToRun.text += botc_role["how_to_run"]
