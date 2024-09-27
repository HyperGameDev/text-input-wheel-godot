extends Control

@export var is_spin: bool = false
@export var speed: int = 10
@export var power: int = 2
@export var reward_position: float = 0
@export var text_box: LineEdit
var text_boxes: Array[LineEdit] = []
var target_rot: float = 0
var from_rot: float

var vat_pham: Array[Dictionary] = [
    {
        "name": "Dark blue",
        "from": 0,
        "to": 45,
        "color": Color.BLUE
    },
    {
        "name": "Pink",
        "from": 315,
        "to": 360,
        "color": Color.MAGENTA
    },
    {
        "name": "Orange",
        "from": 270,
        "to": 315,
        "color": Color.ORANGE
    },
    {
        "name": "Green",
        "from": 225,
        "to": 270,
        "color": Color.GREEN
    },
    {
        "name": "Purple",
        "from": 180,
        "to": 225,
        "color": Color.PURPLE
    },
    {
        "name": "Yellow",
        "from": 135,
        "to": 180,
        "color": Color.YELLOW
    },
    {
        "name": "Blue",
        "from": 90,
        "to": 135,
        "color": Color.CYAN
    },
    {
        "name": "Dark green",
        "from": 45,
        "to": 90,
        "color": Color.DARK_GREEN
    }
]

func _ready() -> void:
    %Panel.get_parent().position.y = %Panel.size.y
    var text_container: Control = text_box.get_parent()
    for i in 8:
        var new_text_box: LineEdit = text_box.duplicate()
        text_container.add_child(new_text_box)
        new_text_box.rotation_degrees = 45 * i
        new_text_box.pivot_offset = new_text_box.size / 2
        new_text_box.position = (Vector2(0, -331)).rotated(new_text_box.rotation) - new_text_box.size / 2
        text_boxes.append(new_text_box)
        vat_pham[i].text_box = new_text_box
        new_text_box.connect("focus_entered", func():
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
        is_spin = true
        var tween := get_tree().create_tween().set_parallel()
        reward_position = randi_range(0, 360) #random position from 0 to 360 degrees

        var selected: Dictionary
        for item in vat_pham:
            if reward_position >= item.from - 22.5 and reward_position <= item.to - 22.5:
                selected = item
        tween.tween_property(%Panel.get_parent(), "position:y", %Panel.size.y, 0.5)
        tween.tween_property(%front, "rotation_degrees", reward_position +  360 * speed * power , 3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
        await tween.finished
        %Theme.text = selected.text_box.text
        (%Panel as Panel).get_theme_stylebox("panel").bg_color = selected.color
        var old_rotation_degrees = %front.rotation_degrees
        #set is_spin = false to tell for user can press again
        is_spin = false
        %front.rotation_degrees = fmod(old_rotation_degrees, 360)
        tween = get_tree().create_tween()
        tween.set_ease(Tween.EASE_IN_OUT)
        tween.set_trans(Tween.TRANS_QUAD)
        tween.tween_property(%Panel.get_parent(), "position:y", 0, 1.0)
