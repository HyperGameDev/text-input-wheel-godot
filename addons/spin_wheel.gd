extends Control


@export var coin_flip_mode: bool = false
var heads: bool
var is_spin: bool = false
@export var speed: int = 10
@export_range(-2,2) var power: float = 2
@export var reward_position: float = 0
@export var text_box: LineEdit
@export var coin_icon: TextureRect
var focused_text_box: LineEdit
var text_boxes: Array[LineEdit] = []
var target_rot: float = 0
var from_rot: float

var save_path: String = "res://data.json"


@onready var history_label: Control = %History_Label
@onready var history_animations: AnimationPlayer = $History/Panel_History/HistoryAnimations
@onready var wheel: TextureRect = %wheel_outline
@onready var arrow: TextureRect = %arrow

@onready var animation: AnimationPlayer = %AnimationPlayer
@onready var coin: MeshInstance3D = $SubViewport/coin_mesh/Cylinder
@onready var coin_flip_minigame: Control = %Coin_Flip_Minigame
var current_choice_memory: String


var vat_pham: Array[Dictionary] = [
	{
		"name": "Dark blue",
		"from": 0,
		"to": 45,
		"color": Color(0.0,0.329,1.0),
		"has_coin": false
	},
	{
		"name": "Pink",
		"from": 315,
		"to": 360,
		"color": Color(0.871,0.071,0.412),
		"has_coin": false
	},
	{
		"name": "Orange",
		"from": 270,
		"to": 315,
		"color": Color(1.0,0.467,0.016),
		"has_coin": false
	},
	{
		"name": "Green",
		"from": 225,
		"to": 270,
		"color": Color(0.084,0.749,0.098),
		"has_coin": false
	},
	{
		"name": "Purple",
		"from": 180,
		"to": 225,
		"color": Color(0.624,0.039,0.624),
		"has_coin": false
	},
	{
		"name": "Yellow",
		"from": 135,
		"to": 180,
		"color": Color(1.0,0.765,0.043),
		"has_coin": false
	},
	{
		"name": "Blue",
		"from": 90,
		"to": 135,
		"color": Color(0.008,0.675,1.0),
		"has_coin": false
	},
	{
		"name": "Dark green",
		"from": 45,
		"to": 90,
		"color": Color(0.075,0.596,0.027),
		"has_coin": false
	}
]

var history : Dictionary = {} #Structured as {"theme_name", amount_on_wheel}

func _ready() -> void:
	%History_Label.meta_clicked.connect(_on_history_url_clicked)
	%Panel.get_parent().position.y = %Panel.size.y
	history = load_history(save_path)
	for i in 8:
		var new_text_box: LineEdit = text_box.duplicate()
		var new_coin_icon: TextureRect = coin_icon.duplicate()
		add_slice_element(i,new_text_box,0,0)
		
		if i % 2 == 0 and coin_flip_mode:
			add_slice_element(i,new_coin_icon,-8,100)
			vat_pham[i].has_coin = true
			

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
	coin_icon.queue_free()
	text_boxes[0].grab_focus()
	
func add_slice_element(slice_id,new_element,x_offset,y_offset):
	var text_container: Control = text_box.get_parent()
	text_container.add_child(new_element)
	new_element.rotation_degrees = 45 * slice_id
	new_element.pivot_offset = new_element.size / 2
	new_element.position = (Vector2(0 + x_offset, -331 + y_offset)).rotated(new_element.rotation) - new_element.size / 2

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
		#print("Wheel spun! On: ",selected)
		var current_choice: String = selected.text_box.text
		%Theme.text = current_choice
		
		assign_banner_colors(selected)
		var old_rotation_degrees = %front.rotation_degrees
		#set is_spin = false to tell for user can press again
		is_spin = false
		%front.rotation_degrees = fmod(old_rotation_degrees, 360)
		
		if selected.has_coin:
			show_coin_flip()
			current_choice_memory = current_choice
		else:
			show_banner()
			purge_history(current_choice)
			
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
		#print("Data purge attempted on ",winner)
		if data.has(winner):
			#print("Data has ",winner)
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
	
func assign_banner_colors(selected):
		(%Panel as Panel).get_theme_stylebox("panel").bg_color = selected.color
		#(%Panel as Panel).get_material().set_shader_parameter("color_one",selected.color)
		(%Theme as Label).add_theme_color_override("font_outline_color", selected.color)
		
func show_banner():
	var banner_tween = get_tree().create_tween()
	banner_tween.set_ease(Tween.EASE_IN_OUT)
	banner_tween.set_trans(Tween.TRANS_QUAD)
	banner_tween.tween_property(%Panel.get_parent(), "position:y", 0, 1.0)
	
func show_coin_flip():
	modulate_wheel_alpha(.255,true)
	
func _animation_coin_entered():
	animation.play("flip")

func _animation_coin_flipped():
	if not coin_flip_is_heads():
		var tails_mat: StandardMaterial3D = preload("res://addons/coin_mesh/tails.tres")
		coin.set_surface_override_material(1,tails_mat)
	
func coin_flip_is_heads() -> bool:
	heads = randi() % 2
	return heads
	
func _animation_coin_side_revealed():
	animation.play("idle")
	if heads:
		show_banner()
		purge_history(current_choice_memory)

func modulate_wheel_alpha(alpha,flip_coin):
	var overlay_tween = get_tree().create_tween()
	overlay_tween.set_ease(Tween.EASE_IN_OUT)
	overlay_tween.set_trans(Tween.TRANS_QUAD)
	overlay_tween.tween_property(arrow, "modulate:a", alpha, 1.0)
	overlay_tween.set_parallel()
	overlay_tween.tween_property(wheel, "modulate:a", alpha, 1.0)
	
	if flip_coin:
		await overlay_tween.finished
	
		coin_flip_minigame.visible = true
		animation.play("coin_enter")
	
	

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
