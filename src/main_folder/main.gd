extends Control

var botc_infos:Dictionary;

@onready var character_type:VBoxContainer = $VBoxContainer/MarginContainer/HFlowContainer/CharacterType/MarginContainer/VBoxContainer
@onready var clues:VBoxContainer = $VBoxContainer/MarginContainer/HFlowContainer/Clues/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var modifiers:VBoxContainer = $VBoxContainer/MarginContainer/HFlowContainer/Modifiers/MarginContainer/VBoxContainer
@onready var role_count_spin_box:SpinBox = $VBoxContainer/MarginContainer/HFlowContainer/PanelContainer/MarginContainer/VBoxContainer/SpinBox
@onready var error_label = $VBoxContainer/MarginContainer2/VBoxContainer/ErrorLabel

var letters_rx:RegEx
var roles_rx:RegEx

func _ready() -> void:
	load_botc_infos()
	signal_initializer()
	regex_initializer()

func load_botc_infos() -> void:
	var file = FileAccess.open("user://data/role_infos.json", FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	botc_infos = json.data

func signal_initializer() -> void:
	$VBoxContainer/MarginContainer2/VBoxContainer/StartButton.pressed.connect(start_game)

func regex_initializer() -> void:
	letters_rx = RegEx.new()
	roles_rx = RegEx.new()
	
	letters_rx.compile("[a-zA-Z]")
	var roles_rx_pattern = ""
	for role in botc_infos.values():
		roles_rx_pattern += role.display_name + "|"
	roles_rx_pattern = roles_rx_pattern.substr(0, roles_rx_pattern.length() - 1)
	roles_rx.compile(roles_rx_pattern)

func start_game():
	# definitions
	var types = get_selected_types()
	var selected_clues = get_selected_checkbox_names(clues)
	
	if selected_clues.is_empty():
		error_label.show()
		error_label.text = "ERROR: Select at least one clue"
		return
	
	var selected_character_type = get_selected_checkbox_names(character_type)
	
	if selected_character_type.is_empty():
		error_label.show()
		error_label.text = "ERROR: Select at least one character type"
		return
	
	var selected_modifiers = get_selected_checkbox_names(modifiers)
	var max_roles:int = role_count_spin_box.value
	
	# get character list
	var characters = []
	var role_cnt = 0
	var keys =  botc_infos.keys()
	keys.shuffle()
	
	for role_name in keys:
		# Exit condition
		if max_roles > 0 && role_cnt >= max_roles: break
		
		var role = botc_infos[role_name]
		if role["category"] in selected_character_type:
			var role_clues = get_role_clues(role, selected_clues, selected_modifiers)
			
			if !role_clues.is_empty():
				role_cnt += 1
				
				characters.append({
					"name":role["display_name"],
					"clues": role_clues
				})
	
	if characters.is_empty():
		error_label.show()
		error_label.text = "ERROR: No characters could be found with this selection"
		return
	
	# Load question page
	var question_page = load("res://src/menues/question.tscn").instantiate()
	question_page.types = types
	question_page.data = characters
	add_child(question_page)

func get_selected_types() -> Array:
	var types = []

	if clues.get_node("Image").button_pressed:
		types.append("Image")
	if clues.get_node("QuickSummary").button_pressed:
		types.append("Text")
	if clues.get_node("Summary").button_pressed:
		types.append("Text")
	if clues.get_node("HowToRun").button_pressed:
		types.append("Text")
	if clues.get_node("Jinxes").button_pressed:
		types.append("Text")
	if clues.get_node("JinxesHard").button_pressed:
		types.append("Text")
	if clues.get_node("JinxesImpossible").button_pressed:	
		types.append("Text")
	if clues.get_node("Examples").button_pressed:
		types.append("Text")
	if clues.get_node("ExamplesHard").button_pressed:
		types.append("Text")
	if clues.get_node("ExamplesImpossible").button_pressed:	
		types.append("Text")
	if clues.get_node("TipsnTricks").button_pressed:
		types.append("Text")
	if clues.get_node("TipsnTricksHard").button_pressed:
		types.append("Text")
	if clues.get_node("TipsnTricksImpossible").button_pressed:	
		types.append("Text")
	if clues.get_node("BluffingAs").button_pressed:
		types.append("Text")
	if clues.get_node("BluffingAsHard").button_pressed:
		types.append("Text")
	if clues.get_node("BluffingAsImpossible").button_pressed:	
		types.append("Text")
	
	return types

func get_role_clues(role:Dictionary, clues_list:Array, modifiers_list:Array) -> Array:
	var result = []
	var display_name = role["display_name"]
	
	if "Image" in clues_list:
		result.append(role["image_path"])
	
	if "Quick Summary" in clues_list:
		result.append(get_modified_str(
				role["quick_summary"].replacen(display_name, "[?]"), 
			modifiers_list))
	
	if "Summary" in clues_list:
		result.append(get_modified_str(
				role["summary"].replacen(display_name, "[?]"), 
			modifiers_list))
		
	if "How To Run" in clues_list:
		result.append(get_modified_str(
				role["how_to_run"].replacen(display_name, "[?]"), 
			modifiers_list))
	
	# Quick exit
	var not_all_empty = !result.is_empty() || \
						(!role["jinx_list"].is_empty() && ("Jinxes" in clues_list || "Jinxes (Hard)" in clues_list || "Jinxes (Impossible)" in clues_list)) ||\
						(!role["examples"].is_empty() && ("Examples" in clues_list || "Examples (Hard)" in clues_list || "Examples (Impossible)" in clues_list)) ||\
						(!role["bluffing"].is_empty() && ("Bluffing as" in clues_list || "Bluffing as (Hard)" in clues_list || "Bluffing as (Impossible)" in clues_list)) ||\
						(!role["tips_n_tricks"].is_empty() && ("Tips & Tricks" in clues_list || "Tips & Tricks (Hard)" in clues_list || "Tips & Tricks (Impossible)" in clues_list))
	
	if !not_all_empty: return []
	
	# Jinxes
	if role["jinx_list"].is_empty():
		if "Jinxes" in clues_list:
			result.append("No jinxes")
		
		if "Jinxes (Hard)" in clues_list:
			result.append("No jinxes")
		
		if "Jinxes (Impossible)" in clues_list:
			result.append("No jinxes")
	else:
		if "Jinxes" in clues_list:
			result.append(get_modified_str(
					format_jinxes(display_name, role["jinx_list"]), 
				modifiers_list))
			
		if "Jinxes (Hard)" in clues_list:
			result.append(get_modified_str(
					format_jinxes_hard(display_name, role["jinx_list"]), 
				modifiers_list))
			
		if "Jinxes (Impossible)" in clues_list:
			result.append(get_modified_str(
					format_jinxes_impossible(display_name, role["jinx_list"]), 
				modifiers_list))
	
	# Examples
	if role["examples"].is_empty():
		if "Examples" in clues_list:
			result.append("No examples")
		
		if "Examples (Hard)" in clues_list:
			result.append("No examples")
			
		if "Examples (Impossible)" in clues_list:
			result.append("No examples")
	else:
		if "Examples" in clues_list:
			result.append(get_modified_str(
					format_normal(display_name, role["examples"]), 
				modifiers_list))
			
		if "Examples (Hard)" in clues_list:
			result.append(get_modified_str(
					format_hard(display_name, role["examples"]), 
				modifiers_list))
			
		if "Examples (Impossible)" in clues_list:
			result.append(get_modified_str(
					format_impossible(display_name, role["examples"]), 
				modifiers_list))
	
	# Tips & Tricks
	if role["tips_n_tricks"].is_empty():
		if "Tips & Tricks" in clues_list:
			result.append("No Tips & Tricks")
		
		if "Tips & Tricks (Hard)" in clues_list:
			result.append("No Tips & Tricks")
			
		if "Tips & Tricks (Impossible)" in clues_list:
			result.append("No Tips & Tricks")
	else:
		if "Tips & Tricks" in clues_list:
			result.append(get_modified_str(
					format_normal(display_name, role["tips_n_tricks"]), 
				modifiers_list))
			
		if "Tips & Tricks (Hard)" in clues_list:
			result.append(get_modified_str(
					format_hard(display_name, role["tips_n_tricks"]), 
				modifiers_list))
			
		if "Tips & Tricks (Impossible)" in clues_list:
			result.append(get_modified_str(
					format_impossible(display_name, role["tips_n_tricks"]), 
				modifiers_list))
	
	# Bluffing as
	if role["bluffing"].is_empty():
		if "Bluffing as" in clues_list:
			result.append("No bluffing as")
		
		if "Bluffing as (Hard)" in clues_list:
			result.append("No bluffing as")
			
		if "Bluffing as (Impossible)" in clues_list:
			result.append("No bluffing as")
	else:
		if "Bluffing as" in clues_list:
			result.append(get_modified_str(
					format_normal(display_name, role["bluffing"]), 
				modifiers_list))
			
		if "Bluffing as (Hard)" in clues_list:
			result.append(get_modified_str(
					format_hard(display_name, role["bluffing"]), 
				modifiers_list))
			
		if "Bluffing as (Impossible)" in clues_list:
			result.append(get_modified_str(
					format_impossible(display_name, role["bluffing"]), 
				modifiers_list))
	
	return result

func format_jinxes(self_display_name:String, jinx_list:Array) -> String:
	jinx_list.shuffle()
	var result = ""
		
	for jinx in jinx_list: 
		result += botc_infos[jinx["role"]]["display_name"] + " : " + \
					jinx["description"].replacen(self_display_name, "[?]")\
					+ "\n ----- \n"
	
	return result

func format_jinxes_hard(self_display_name:String, jinx_list:Array) -> String:
	jinx_list.shuffle()
	var result = ""
		
	for jinx in jinx_list: 
		result += jinx["description"].replacen(self_display_name, "[?]")\
				.replacen(botc_infos[jinx["role"]]["display_name"], "[!]") + "\n ----- \n"
	
	return result

func format_jinxes_impossible(self_display_name:String, jinx_list:Array) -> String:
	var jinx = jinx_list.pick_random()
	return jinx["description"].replacen(self_display_name, "[?]")\
				.replacen(botc_infos[jinx["role"]]["display_name"], "[!]") + "\n ----- \n"\
				+ str(jinx_list.size()) + " jinxes"

func format_normal(self_display_name:String, text_list:Array) -> String:
	text_list.shuffle()
	var result = ""
	
	for text in text_list:
		result += text.replacen(self_display_name, "[?]") + "\n ----- \n"
	
	return result

func format_hard(self_display_name:String, text_list:Array) -> String:
	text_list.shuffle()
	var result = ""
	
	for text in text_list:
		result += roles_rx.sub(text.replacen(self_display_name, "[?]"), "[!]", true) \
					+ "\n ----- \n"
	
	return result

func format_impossible(self_display_name:String, text_list:Array) -> String:
	var text = text_list.pick_random()
	return roles_rx.sub(text.replacen(self_display_name, "[?]"), "[!]", true)\
			 + "\n ----- \n"\
			 + str(text_list.size()) + " items"

func get_modified_str(text:String, modifiers_list:Array) -> String:
	
	if "Words Outlines" in modifiers_list:
		text = letters_rx.sub(text, "#", true)
	
	if "Word Scramble" in modifiers_list:
		var text_list = text.split(" ", false)
		var indexes_list = range(text_list.size())
		indexes_list.shuffle()
		text = ""
		for i in indexes_list:
			text += text_list[i] + " "
	
	if "Half Words" in modifiers_list:
		var new_text = ""
		var can_replace = randi_range(0,1) == 1
		for word in text.split(" ", false):
			if letters_rx.search(word):
				can_replace = !can_replace
				if !can_replace:
					new_text += word + " "
				elif "\n" in word:
					new_text += "\n"
			else: 
				new_text += word + " "
		text = new_text
	
	if "Half Letters" in modifiers_list:
		var new_text = ""
		var can_replace = true
		for letter in text:
			if letter in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ":
				can_replace = !can_replace
				if can_replace:
					new_text += "#"
				else:
					new_text += letter
			else: 
				new_text += letter
		text = new_text
	
	return text

func get_selected_checkbox_names(parent:Control) -> Array:
	var result = []
	
	for node in parent.get_children():
		if node as CheckBox && node.button_pressed:
			result.append(node.text)
	
	return result
