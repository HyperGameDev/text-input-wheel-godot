extends Control

@export var is_spin: bool = false
@export var speed: int = 10
@export var power: int = 2
@export var reward_position: float = 0
@export var text_box: LineEdit
var focused_text_box: LineEdit
var text_boxes: Array[LineEdit] = []
var target_rot: float = 0
var from_rot: float

var save_path: String = "res://data.json"

@onready var history_label: Control = %History_Label
@onready var history_animations: AnimationPlayer = $History/Panel_History/HistoryAnimations

var vat_pham: Array[Dictionary] = [
	{
		"name": "Dark blue",
		"from": 0,
		"to": 45,
		"color": Color(0.0,0.329,1.0)
	},
	{
		"name": "Pink",
		"from": 315,
		"to": 360,
		"color": Color(0.871,0.071,0.412)
	},
	{
		"name": "Orange",
		"from": 270,
		"to": 315,
		"color": Color(1.0,0.467,0.016)
	},
	{
		"name": "Green",
		"from": 225,
		"to": 270,
		"color": Color(0.084,0.749,0.098)
	},
	{
		"name": "Purple",
		"from": 180,
		"to": 225,
		"color": Color(0.624,0.039,0.624)
	},
	{
		"name": "Yellow",
		"from": 135,
		"to": 180,
		"color": Color(1.0,0.765,0.043)
	},
	{
		"name": "Blue",
		"from": 90,
		"to": 135,
		"color": Color(0.008,0.675,1.0)
	},
	{
		"name": "Dark green",
		"from": 45,
		"to": 90,
		"color": Color(0.075,0.596,0.027)
	}
]

var history : Dictionary = {} #Structured as {"theme_name", amount_on_wheel}

func _ready() -> void:
	%History_Label.meta_clicked.connect(_on_history_url_clicked)
	%Panel.get_parent().position.y = %Panel.size.y
	var text_container: Control = text_box.get_parent()
	history = load_history(save_path)
	for i in 8:
		var new_text_box: LineEdit = text_box.duplicate()
		text_container.add_child(new_text_box)
		new_text_box.rotation_degrees = 45 * i
		new_text_box.pivot_offset = new_text_box.size / 2
		new_text_box.position = (Vector2(0, -331)).rotated(new_text_box.rotation) - new_text_box.size / 2
		text_boxes.append(new_text_box)
		vat_pham[i].text_box = new_text_box
		new_text_box.connect("focus_entered", func():
			focused_text_box = new_text_box
			var new_target = -new_text_box.rotation_degrees * TAU / 360
			if target_rot != new_target:
				from_rot = %front.rotation
				target_rot = new_target
				var tween := get_tree().create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.set_trans(Tween.TRANS_QUAD)
				tween.tween_method((func(x):
					%front.rotation = lerp_angle(from_rot, target_rot, x)
				), 0.0, 1.0, 0.5)
		)
		new_text_box.connect("text_changed", func(new_text: String):
			new_text_box.pivot_offset = new_text_box.size / 2
		)
	text_box.queue_free()
	text_boxes[0].grab_focus()

func _on_btn_spin_pressed():
	if is_spin == false:
		log_history(vat_pham, history) # Log new entries on spin
		is_spin = true
		var tween := get_tree().create_tween().set_parallel()
		reward_position = randi_range(0, 360) - 22.5 #random position from 0 to 360 degrees

		var selected: Dictionary
		for item in vat_pham:
			if reward_position >= item.from - 22.5 and reward_position <= item.to - 22.5:
				selected = item
		tween.tween_property(%Panel.get_parent(), "position:y", %Panel.size.y, 0.5)
		tween.tween_property(%front, "rotation_degrees", reward_position +  360 * speed * power , 3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
		await tween.finished
		var current_choice = selected.text_box.text
		%Theme.text = current_choice
		purge_history(current_choice)
		(%Panel as Panel).get_theme_stylebox("panel").bg_color = selected.color
		#(%Panel as Panel).get_material().set_shader_parameter("color_one",selected.color)
		(%Theme as Label).add_theme_color_override("font_outline_color", selected.color)
		var old_rotation_degrees = %front.rotation_degrees
		#set is_spin = false to tell for user can press again
		is_spin = false
		%front.rotation_degrees = fmod(old_rotation_degrees, 360)
		tween = get_tree().create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(%Panel.get_parent(), "position:y", 0, 1.0)

## HISTORY CODE

func log_history(entries: Array, history: Dictionary):
	for i in entries:
		if i.text_box.text == "": # if box is empty don't add
			continue
		var entry = i.text_box.text.capitalize() #format nicely
		if history.has(entry): # If already in history
			history[entry] += 1 # increment counter
		else: # not in history
			history[entry] = 1 # create the entry
	save_history(history, save_path)
	update_history_label(history)
	
func purge_history(winner):
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var content = JSON.parse_string(file.get_as_text())
		var data = content as Dictionary
		if data.has(winner):
			data.erase(winner)
			file = FileAccess.open(save_path, FileAccess.WRITE)
			file.store_string(JSON.stringify(data, "\t"))
			file.close()
			load_history(save_path)

func save_history(history: Dictionary, path: String):
	var data = JSON.stringify(history, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data)

func load_history(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content: Dictionary = JSON.parse_string(file.get_as_text())
		update_history_label(content)
		return content
	return {}

func update_history_label(history: Dictionary):
	var str = ""
	for i in history:
		str += "    ([url={0}]{0}[/url]: {1})    ".format({"0": i, "1": str(history[i])})
	%History_Label.bbcode_enabled = true
	%History_Label.text = str
	history_label.text = str

func _on_history_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%Panel_History.visible = true
		history_animations.play("Show_fade")
	else:
		history_animations.play("Hide_fade")
	
func history_animation_hide():
	%Panel_History.visible = false
		
func _on_history_url_clicked(tag):
	focused_text_box.text = tag


func _on_button_reset_pressed() -> void:
	get_tree().reload_current_scene()
