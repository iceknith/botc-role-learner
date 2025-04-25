extends Control

signal new_data_download(String)
signal debug_signal(String)
signal all_roles_downloaded

const DATA_PATH = "data"
const IMAGE_PATH = DATA_PATH + "/images"
const DATA_VERSION = "1.2"

var request_answer_bytes:Dictionary
var request_answer:Dictionary


var summary_rx:RegEx
var quick_summary_rx:RegEx
var how_to_run_rx:RegEx
var examples_rx:RegEx
var tips_n_tricks_rx:RegEx
var bluffing_rx:RegEx
var remove_start_rx:RegEx
var remove_end_rx:RegEx
var remove_classes_rx:RegEx
var remove_role_start_rx:RegEx
var remove_role_end_rx:RegEx
var remove_title_rx:RegEx
var reminder_rx:RegEx
var jinxes_rx:RegEx
var remove_non_alphanumerical_rx:RegEx
var find_img_url_rx:RegEx

var role_processed:int = 0
var role_count:int = 0

var currently_processed_roles:Array

var role_infos:Dictionary = Dictionary();
	# Json Architechture:
	# role: Str
	#  display_name: Str
	#  image_path: Str
	#  category: Str
	#  quick_summary: Str
	#  how_to_run: Str
	#  reminder_list: Str[]
	#  jinx_list:Dict
	#    [
	#      role: Str
	#      description: Str
	#    ]
	#  examples : List
	#  tips_n_tricks : List
	#  bluffing : List

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	initialize_regex()
	new_data_download.connect(display_new_message)
	debug_signal.connect(display_debug_message)
	
	await get_tree().process_frame
	# Launch wiki datas in seperate thread
	Thread.new().start(get_missing_datas)

func initialize_regex():
	summary_rx = RegEx.new()
	quick_summary_rx = RegEx.new()
	how_to_run_rx = RegEx.new()
	examples_rx = RegEx.new()
	tips_n_tricks_rx = RegEx.new()
	bluffing_rx = RegEx.new()
	remove_start_rx = RegEx.new()
	remove_end_rx = RegEx.new()
	remove_classes_rx = RegEx.new()
	remove_role_start_rx = RegEx.new()
	remove_role_end_rx = RegEx.new()
	remove_title_rx = RegEx.new()
	reminder_rx = RegEx.new()
	jinxes_rx = RegEx.new()
	remove_non_alphanumerical_rx = RegEx.new()
	find_img_url_rx = RegEx.new()
	
	summary_rx.compile("== Summary ==(.|\n)*?</div>")
	quick_summary_rx.compile("(\"|”).*?(\"|”) *\n")
	how_to_run_rx.compile("== How to Run ==(.|\n)*?</div>")
	examples_rx.compile("== Examples ==(.|\n)*?<div class='row'>")
	tips_n_tricks_rx.compile("== Tips & Tricks ==(.|\n)*?</div>")
	bluffing_rx.compile("== Bluffing(.|\n)*?</div>")
	remove_start_rx.compile("\\A(\n|\t)*")
	remove_end_rx.compile("(\n|\t)*\\Z")
	remove_classes_rx.compile("<.*>")
	remove_role_start_rx.compile("{{.*?[|]")
	remove_role_end_rx.compile("}}")
	remove_title_rx.compile("==.*?==")
	reminder_rx.compile("'''[^'.]*?''' reminder")
	jinxes_rx.compile("{{Jinx.*?}}")
	remove_non_alphanumerical_rx.compile("[^a-zA-Z1-9]")

func on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_key:String, parse_to_string:bool):
	if parse_to_string:
		request_answer[request_key] = body.get_string_from_utf8()
	else:
		request_answer_bytes[request_key] = body

func date1_gt_date2(date1:String, date2:String) -> bool:
	var date1_numerized = date1.replace("-", "").replace(":", "").replace("T", "").replace("Z", "").to_int()
	var date2_numerized = date2.replace("-", "").replace(":", "").replace("T", "").replace("Z", "").to_int()
	return date1_numerized > date2_numerized

func _process(delta: float) -> void:
	$completionLabel.text = str(role_processed) + "/" + str(role_count)


# Get datas
func get_missing_datas() -> void:
	# Check if the directory path exists, if not create it
	var dir = DirAccess.open("user://")
	if (!dir.dir_exists(DATA_PATH)): dir.make_dir_recursive(DATA_PATH)
	if (!dir.dir_exists(IMAGE_PATH)): dir.make_dir_recursive(IMAGE_PATH)
	
	# Defining the primary HTTPRequest
	var request = HTTPRequest.new()
	request.request_completed.connect(on_request_completed.bind("main", true));
	add_child.bind(request).call_deferred()
	await request.tree_entered
	
	# Defining role processed variables
	role_processed = 0
	role_count = 0
	
	if dir.file_exists(DATA_PATH+"/last_update_date.date"):
		var roles_to_process = await get_out_of_date_roles(request)
		
		if roles_to_process == null: # if dictionary empty, we must download everything
			await download_all_wiki_datas(request)
		
		else: # If not, download only the roles that need it
			load_json_role_infos()
			
			for category in roles_to_process.keys():
				currently_processed_roles = roles_to_process[category]
				role_count += 2*currently_processed_roles.size()
				var task_id1 = WorkerThreadPool.add_group_task(download_wiki_role_datas.bind(category), currently_processed_roles.size())
				var task_id2 = WorkerThreadPool.add_group_task(download_wiki_role_images, currently_processed_roles.size())
				
				WorkerThreadPool.wait_for_group_task_completion(task_id1)
				WorkerThreadPool.wait_for_group_task_completion(task_id2)
		
	else: # If it is the first time downloading (or if all the files disapeared) download everything
		await download_all_wiki_datas(request)
		if $Error.visible: return
	
	# wait process end if there are processes
	if role_count != 0: await all_roles_downloaded
	
	# Write the date & json files
	await write_update_date(request);
	write_json_role_infos()
	
	request.queue_free.call_deferred()
	
	on_data_download_finished()

func load_json_role_infos():
	var json_file = FileAccess.open("user://"+DATA_PATH+"/role_infos.json", FileAccess.READ)
	role_infos = JSON.parse_string(json_file.get_as_text())
	json_file.close()

func get_out_of_date_roles(request:HTTPRequest):
	# Request every change
	request.request(
		"https://wiki.bloodontheclocktower.com/api.php?action=query&format=json&prop=categories&list=recentchanges&generator=recentchanges&cllimit=500&rclimit=500&grclimit=500"
		)
	# While the request is goind on, get the last update date
	var last_update_date_file = FileAccess.open("user://"+DATA_PATH+"/last_update_date.date", FileAccess.READ)
	var last_update_date_txt:String = last_update_date_file.get_as_text()
	last_update_date_file.close()
	
	# Wait for the request to be finished
	await request.request_completed
	
	# Process last update date
	if last_update_date_txt.split("\n", false).size() != 2: return null #If the format isn't correct
	
	var last_update_date:String = last_update_date_txt.split("\n", false)[0]
	var last_update_data_version:String = last_update_date_txt.split("\n", false)[1]
	if last_update_data_version != DATA_VERSION: return null # If the Data version isn't the corrcet one
	
	if !request_answer["main"]:
		return {}
	
	# Define variables
	var json_querry = JSON.parse_string(request_answer["main"])["query"]
	var update_list:Array = json_querry["recentchanges"]
	var update_pages:Dictionary = json_querry["pages"]
	
	# See if our version if too old: in wich case, we return null
	var last_querried_update_date = update_list[-1]["timestamp"]
	if date1_gt_date2(last_querried_update_date, last_update_date): # if last_querried_update_date > last_update_date, there is 500 changes to go over (so we will update everything)
		return null
	
	# Compute 
	var out_of_date_roles = Dictionary()
	var page_titles = []
	
	for update in update_list:
		
		if !date1_gt_date2(update["timestamp"], last_update_date): break # If last_update_date >= update["timestamp"] we have caught back with all the changes
		
		var page = update_pages.get(str(update["pageid"]))
		if page and not page["title"] in page_titles:
			var categories = page.get("categories")
			if categories:
				for category in categories:
					var category_title:String = category["title"].replace("Category:", "")
					if category_title in ["Townsfolk", "Outsiders", "Minions", "Demons", "Travellers", "Fabled"]:
						page_titles.append(page["title"])
						if out_of_date_roles.get(category_title): 
							out_of_date_roles[category_title].append(page)
						else:
							out_of_date_roles[category_title] = [page]
	
	return out_of_date_roles

func write_update_date(request):
	# Request every change
	request.request(
		"https://wiki.bloodontheclocktower.com/api.php?action=query&format=json&list=recentchanges&rclimit=1"
		)
	# While the request is goind on, open the last_update_date_file
	var last_update_date_file = FileAccess.open("user://"+DATA_PATH+"/last_update_date.date", FileAccess.WRITE)
	# Wait for the request to be finished
	await request.request_completed
	
	if !request_answer["main"]:
		return
	
	# Write the last update date
	var last_update_date = JSON.parse_string(request_answer["main"])["query"]["recentchanges"][0]["timestamp"]
	last_update_date_file.store_string(last_update_date + "\n" + DATA_VERSION)
	last_update_date_file.close()

func write_json_role_infos():
	var json_file = FileAccess.open("user://"+DATA_PATH+"/role_infos.json", FileAccess.WRITE)
	json_file.store_string(JSON.stringify(role_infos))
	json_file.close()

func download_all_wiki_datas(request:HTTPRequest) -> void:
	for category in ["Townsfolk", "Outsiders", "Minions", "Demons", "Travellers", "Fabled"]:
		# Make request
		request.request(
			"https://wiki.bloodontheclocktower.com/api.php?action=query&format=json&list=categorymembers&cmlimit=500&cmtitle=Category%3A"+category
			)
		await request.request_completed
		
		if !request_answer["main"]:
			$Error.show()
			return
		
		currently_processed_roles = JSON.parse_string(request_answer["main"])["query"]["categorymembers"]
		role_count += 2*currently_processed_roles.size()
		var task_id1 = WorkerThreadPool.add_group_task(download_wiki_role_datas.bind(category), currently_processed_roles.size())
		var task_id2 = WorkerThreadPool.add_group_task(download_wiki_role_images, currently_processed_roles.size())
		
		WorkerThreadPool.wait_for_group_task_completion(task_id1)
		WorkerThreadPool.wait_for_group_task_completion(task_id2)

func download_wiki_role_datas(role_index:int, current_category:String) -> void:
	# Define Str variables
	var role_display_text:String = currently_processed_roles[role_index]["title"]
	var role_page_name:String = role_display_text.replace(" ", "_")
	var role:String = remove_non_alphanumerical_rx.sub(role_page_name, "", true).to_lower()
	var role_img_name = "Icon_" + role + ".png"
	
	# Create own request
	var request = HTTPRequest.new()
	request.request_completed.connect(on_request_completed.bind(role, true));
	add_child.bind(request).call_deferred()
	await request.tree_entered
	
	# Get role infos
	new_data_download.emit(role_display_text+" Role Data")
	var this_role_infos = await scrap_role_summaries(role_page_name, request, role)
	this_role_infos["display_name"] = role_display_text
	this_role_infos["category"] = current_category
	this_role_infos["image_path"] = "user://" + IMAGE_PATH + "/" + role_img_name
	
	role_infos[role] = this_role_infos
	
	# Delete the own request
	request.queue_free.call_deferred()
	role_processed += 1
	
	# Check if all requests are finished
	if role_processed >= role_count:
		all_roles_downloaded.emit()

func download_wiki_role_images(role_index:int) -> void:
	# Define str variables
	var role:String = currently_processed_roles[role_index]["title"].replace(" ", "_")
	role = remove_non_alphanumerical_rx.sub(role, "", true).to_lower()
	var img_name = "Icon_" + role + ".png"
	
	# Create own request
	var request = HTTPRequest.new()
	var on_request_completed_parse_bytes_callable = on_request_completed.bind(img_name, true)
	request.request_completed.connect(on_request_completed_parse_bytes_callable);
	add_child.bind(request).call_deferred()
	await request.tree_entered
		
	# Get image URL
	while not request_answer.get(img_name):
		new_data_download.emit(img_name)
		request.request("https://wiki.bloodontheclocktower.com/File:"+img_name)
		await request.request_completed
	
	find_img_url_rx.compile("<a href=\"[^>]*?"+img_name+"\">")
	var img_url = find_img_url_rx.search(request_answer[img_name]).get_string()
	img_url = img_url.replace("<a href=\"", "").replace("\">", "")
	img_url = "https://wiki.bloodontheclocktower.com" + img_url
		
	# Disconnect/Reconnect it to not parse only the bytes
	request.request_completed.disconnect(on_request_completed_parse_bytes_callable)
	request.request_completed.connect(on_request_completed.bind(img_name, false));
		
	# Download image
	var bytes:PackedByteArray = PackedByteArray()
	while bytes.size() == 0: # Loop because in early testing, some requests would yield empty bytes
		request.request(img_url);
		await request.request_completed
		bytes = request_answer_bytes[img_name]
	var file = FileAccess.open("user://"+IMAGE_PATH+"/"+img_name, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
		
	# Delete the own request
	request.queue_free.call_deferred()
	
	role_processed += 1
	
	# Check if all requests are finished
	if role_processed >= role_count:
		all_roles_downloaded.emit()

func scrap_role_summaries(page_name:String, request:HTTPRequest, http_request_key:String) -> Dictionary:
	# Make request
	request_answer[http_request_key] = null
	while not request_answer[http_request_key]:
		request.request(
			"https://wiki.bloodontheclocktower.com/api.php?action=parse&format=json&page="+page_name+"&prop=wikitext"
			)
		await request.request_completed
	
	var content:String = JSON.parse_string(request_answer[http_request_key])["parse"]["wikitext"]["*"]
	
	# Stripping infos
	var role_summaries_data:Dictionary = Dictionary()
	
	# Summary
	var summary = summary_rx.search(content).get_string()
	summary = summary.replace("== Summary ==", "").replace("</div>", "")
	summary = remove_start_rx.sub(summary, "", true)
	summary = remove_end_rx.sub(summary, "", true)
	summary = remove_role_start_rx.sub(summary, "", true)
	summary = remove_role_end_rx.sub(summary, "", true)
	role_summaries_data["summary"] = summary
	
	# Quick Summary
	if not quick_summary_rx.search(summary):
		print(summary)
	var quick_summary = quick_summary_rx.search(summary).get_string()
	quick_summary = quick_summary.replace("\"", "").replace("”", "").replace("\n","")
	role_summaries_data["quick_summary"] = quick_summary
	
	# How to run
	var how_to_run_match = how_to_run_rx.search(content)
	var how_to_run = "This section is empty."
	if how_to_run_match:
		how_to_run = how_to_run_match.get_string().replace("== How to Run ==", "").replace("</div>", "")
		how_to_run = remove_start_rx.sub(how_to_run, "", true)
		how_to_run = remove_end_rx.sub(how_to_run, "", true)
		how_to_run = remove_classes_rx.sub(how_to_run, "", true)
		
	role_summaries_data["how_to_run"] = how_to_run
	
	# Reminders
	var reminder_list = Array()
	if how_to_run_match:
		for reminder_match in reminder_rx.search_all(how_to_run):
			var reminder = reminder_match.get_string().replace("'''","").replace(" reminder", "")
			if not reminder in reminder_list:
				reminder_list.append(reminder)
		
		# Edge cases
		if http_request_key == "acrobat":
			if not "DEAD" in reminder_list: reminder_list.append("DEAD")
		
	role_summaries_data["reminder_list"] = reminder_list
	
	# Jinxes
	var jinx_list = Array()
	for jinx_match in jinxes_rx.search_all(content):
		var jinx:PackedStringArray = jinx_match.get_string().replace("{{Jinx|","").replace("}}","").split("|");
		jinx_list.append(
			{
				"role":jinx[1],
				"description":jinx[3]
			}
		)
	
	role_summaries_data["jinx_list"] = jinx_list
	
	# Examples
	var examples_match = examples_rx.search(content)
	var examples = []
	if examples_match:
		var example_txt = examples_match.get_string().replace("== Examples ==", "")
		example_txt = remove_start_rx.sub(example_txt, "", true)
		example_txt = remove_end_rx.sub(example_txt, "", true)
		example_txt = remove_classes_rx.sub(example_txt, "", true)
		example_txt = remove_role_start_rx.sub(example_txt, "", true)
		example_txt = remove_role_end_rx.sub(example_txt, "", true)
		example_txt = example_txt.replace("\t", "")
		examples = example_txt.split("\n", false)
		for i in range(examples.size()):
			examples[i] = examples[i].substr(0, examples[i].length() - 1)
	
	role_summaries_data["examples"] = examples
	
	# Tips & Tricks
	var tips_n_tricks_match = tips_n_tricks_rx.search(content)
	var tips_n_tricks = []
	if tips_n_tricks_match:
		var tips_n_tricks_txt = tips_n_tricks_match.get_string().replace("== Tips & Tricks ==", "").replace("</div>", "")
		tips_n_tricks_txt = remove_start_rx.sub(tips_n_tricks_txt, "", true)
		tips_n_tricks_txt = remove_end_rx.sub(tips_n_tricks_txt, "", true)
		tips_n_tricks_txt = remove_classes_rx.sub(tips_n_tricks_txt, "", true)
		tips_n_tricks_txt = remove_role_start_rx.sub(tips_n_tricks_txt, "", true)
		tips_n_tricks_txt = remove_role_end_rx.sub(tips_n_tricks_txt, "", true)
		tips_n_tricks_txt = tips_n_tricks_txt.replace("\n","")
		tips_n_tricks = tips_n_tricks_txt.split("*", false)
	
	role_summaries_data["tips_n_tricks"] = tips_n_tricks
	
	# Bluffing
	var bluffing_match = bluffing_rx.search(content)
	var bluffing = []
	if bluffing_match:
		var bluffing_txt = remove_title_rx.sub(bluffing_match.get_string(), "", true)
		bluffing_txt = remove_start_rx.sub(bluffing_txt, "", true)
		bluffing_txt = remove_end_rx.sub(bluffing_txt, "", true)
		bluffing_txt = remove_classes_rx.sub(bluffing_txt, "", true)
		bluffing_txt = remove_role_start_rx.sub(bluffing_txt, "", true)
		bluffing_txt = remove_role_end_rx.sub(bluffing_txt, "", true)
		bluffing_txt = bluffing_txt.replace("\n","")
		bluffing = bluffing_txt.split("*", false)
	
	role_summaries_data["bluffing"] = bluffing
	
	return role_summaries_data

func display_new_message(data_name:String) -> void:
	$InfoLabel.text = "Loading data: "+ data_name

func display_debug_message(msg:String) -> void:
	$debug.text = msg

func on_data_download_finished() -> void:
	get_tree().change_scene_to_file.bind("res://src/main_folder/main.tscn").call_deferred()
