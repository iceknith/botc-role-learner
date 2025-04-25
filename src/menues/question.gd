extends Control

var types:Array = []
# Types:
# Image
# Text

var data:Array = []

var current_role:int = 0
var correct_answer_count:float = 0

@onready var clue_container:VBoxContainer = $VBoxContainer/ScrollContainer/MarginContainer/ClueContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect_signals()
	
	var labelsettings = LabelSettings.new()
	labelsettings.font_size = 17
	
	for type in types:
		if type == "Image":
			var img = TextureRect.new()
			img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.custom_minimum_size.y = 350
			clue_container.add_child(img)
		
		elif type == "Text":
			var txt = Label.new()
			txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			txt.custom_minimum_size.x = 440
			txt.label_settings = labelsettings
			clue_container.add_child(txt)
	
	load_role(current_role)

func _notification(what):
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			queue_free.call_deferred()

func connect_signals() -> void:
	$VBoxContainer/MarginContainer/LineEdit.text_submitted.connect(role_submitted)
	$VBoxContainer/MarginContainer3/HBoxContainer/SubmitButton.pressed.connect(role_submitted_button)
	$ResultTimer.timeout.connect(result_timer_timeout)
	$VBoxContainer/MarginContainer3/HBoxContainer/ResultsButton.pressed.connect(show_results)
	$VBoxContainer/MarginContainer3/HBoxContainer/BackButton.pressed.connect(queue_free.call_deferred)
	$End/VBoxContainer/MarginContainer/BackToMenu.pressed.connect(queue_free.call_deferred)

func role_submitted_button() -> void:
	role_submitted($VBoxContainer/MarginContainer/LineEdit.text)

func role_submitted(new_text:String) -> void:
	var role_name = data[current_role]["name"].to_lower()
	if is_levenstein_distance_smaller(new_text.to_lower(), role_name, roundf(role_name.length() * 0.25)):
		correct_answer_count += 1
		$Correct.show()
	else:
		$Wrong.show()
		$Wrong/VBoxContainer/Label2.text = "The correct answer was:\n" + data[current_role]["name"]
	$ResultTimer.start()

func is_levenstein_distance_smaller(txt1:String, txt2:String, max_size:float) -> bool:
	# trivial cases
	if txt1.is_empty(): return txt2.length() <= max_size
	if txt2.is_empty(): return txt1.length() <= max_size
	
	if txt1[0] == txt2[0]: 
		return is_levenstein_distance_smaller(txt1.substr(1), txt2.substr(1), max_size)
	
	if max_size <= 0: return false
	
	# Non trivial case (difference)
	return is_levenstein_distance_smaller(txt1.substr(1), txt2, max_size-1) || \
		is_levenstein_distance_smaller(txt1, txt2.substr(1), max_size-1) || \
		is_levenstein_distance_smaller(txt1.substr(1), txt2.substr(1), max_size-1)

func result_timer_timeout() -> void:
	$Correct.hide()
	$Wrong.hide()
	
	current_role += 1
	if current_role >= data.size():
		show_results()
	else:
		load_role(current_role)

func show_results():
	if current_role != 0:
		$End/VBoxContainer/Results.text = str(correct_answer_count * 100 / current_role) + "% Accuracy"
	else:
		$End/VBoxContainer/Results.text = "No roles were guessed"
	$End.show()

func load_img(file) -> ImageTexture:
	var img = Image.new()
	img.load(file)
	return ImageTexture.create_from_image(img)

func load_role(index:int) -> void:
	var role_data:Array = data[index]["clues"]
	var question_nodes:Array = clue_container.get_children()
	
	for i in range(role_data.size()):
		if types[i] == "Image":
			question_nodes[i].texture = load_img(role_data[i])
		elif types[i] == "Text":
			question_nodes[i].text = role_data[i]
	
	$VBoxContainer/MarginContainer/LineEdit.text = ""
	$VBoxContainer/PageCountLabel.text = str(index+1) + "/" + str(data.size())
