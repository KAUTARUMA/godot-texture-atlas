@icon("res://addons/godot_texture_atlas/icon_atlas_sprite.svg")
@tool
class_name AtlasSprite extends Node2D

const NAMES_BASE = {
	"ANIMATION": "AN",
	"SYMBOL_DICTIONARY": "SD",
	"TIMELINE": "TL",
	"LAYERS": "L",
	"Frames": "FR",
	"Symbols": "S",
	"name": "N",
	"SYMBOL_name": "SN",
	"elements": "E",
	"Layer_name": "LN",
	"index": "I",
	"duration": "DU",
	"ATLAS_SPRITE_instance": "ASI",
	"Instance_Name": "IN",
	"symbolType": "ST",
	"movieclip": "MC",
	"graphic": "G",
	"firstFrame": "FF",
	"loop": "LP",
	"Matrix3D": "M3D",
	"metadata": "MD",
	"framerate": "FRT"
}

# empty is defaulted to timeline
@export var symbol: String = "":
	set(value):
		symbol = value
		
		if symbols.is_empty() == false:
			timeline_length = get_timeline_length(get_layers())
		
		queue_redraw()

@export var cur_frame: int = 0:
	set(value):
		cur_frame = value
		queue_redraw()

@export var animation_json: JSON
@export_tool_button("Reload Atlas") var reload_atlas = _load_atlas

@export_category("Animation Player")
@export var fps: int = 24
@export var animations: Array[AtlasAnimInfo] = []
@export_tool_button("Create Animation Player") var create_animplayer = _create_animation_player

# duplicate json resource that we can edit
var _animation_json: Dictionary

var NAMES:Dictionary
var timeline_length:int = 0
var is_optimized:bool = false

var spritemap_tex:Texture2D
var spritemap_json:JSON

var limbs:Dictionary[String, Rect2i] = {}
var symbols:Dictionary[String, Array] = {}

func _ready() -> void:
	_load_atlas()

func _load_atlas() -> void:
	if animation_json == null: return
	
	var dir = animation_json.resource_path.get_base_dir()
	spritemap_tex = load(dir.path_join("spritemap1.png"))
	spritemap_json = load(dir.path_join("spritemap1.json"))
	
	_animation_json = animation_json.data.duplicate(true)
	
	is_optimized = _animation_json.has("AN")
	
	NAMES = NAMES_BASE.duplicate()
	limbs.clear()
	symbols.clear()
	
	if !is_optimized:
		for key in NAMES:
			NAMES[key] = key
	
	for _sprite in spritemap_json.data["ATLAS"]["SPRITES"]:
		var sprite = _sprite["SPRITE"] # i dont know why these are in their own dict
		limbs[sprite["name"]] = Rect2i(int(sprite["x"]), int(sprite["y"]), int(sprite["w"]), int(sprite["h"]))
	
	if _animation_json.has(NAMES["SYMBOL_DICTIONARY"]):
		for symbol_data in _animation_json[NAMES["SYMBOL_DICTIONARY"]][NAMES["Symbols"]]:
			symbols[symbol_data[NAMES["SYMBOL_name"]]] = symbol_data[NAMES["TIMELINE"]][NAMES["LAYERS"]]
			symbols[symbol_data[NAMES["SYMBOL_name"]]].reverse()
	
	# lets just hope no one names their symbol this lol
	symbols["_top"] = _animation_json[NAMES["ANIMATION"]][NAMES["TIMELINE"]][NAMES["LAYERS"]]
	symbols["_top"].reverse()
	
	timeline_length = get_timeline_length(get_layers())
	
	queue_redraw()

func get_layers() -> Array:
	if symbol == "" || !symbols.has(symbol):
		return symbols["_top"]
	else:
		return symbols[symbol]

func get_timeline_length(layers:Array) -> int:
	var longest_length = 0
	for layer in layers:
		var total_duration:int = 0
		
		for frame in layer[NAMES["Frames"]]:
			total_duration += frame[NAMES["duration"]]
		
		if total_duration > longest_length:
			longest_length = total_duration
	
	return longest_length

func _draw() -> void:
	if !symbols.is_empty():
		_draw_timeline(get_layers(), cur_frame)

func _draw_timeline(layers:Array, starting_frame:int, transformation:Transform2D = Transform2D()) -> void:
	for layer in layers:
		var frame = get_index_at_frame(starting_frame, layer[NAMES["Frames"]])
		
		if frame.is_empty(): continue
		
		for _element:Dictionary in frame[NAMES["elements"]]:
			var type = _element.keys()[0]
			var element = _element[type]
			
			var transform_2d = transformation * m3d_to_transform2d(element[NAMES["Matrix3D"]])
			
			match type:
				"ATLAS_SPRITE_instance", "ASI":
					var limb = limbs[element[NAMES["name"]]]
					
					draw_set_transform_matrix(transform_2d)
					draw_texture_rect_region(spritemap_tex, Rect2i(0, 0, limb.size.x, limb.size.y), limbs[element[NAMES["name"]]])
				"SYMBOL_Instance", "SI":
					var new_starting_frame = 0
					if element[NAMES["symbolType"]] == NAMES["movieclip"]:
						new_starting_frame = cur_frame
					else:
						new_starting_frame = element[NAMES["firstFrame"]] + 1
					
					_draw_timeline(symbols[element[NAMES["SYMBOL_name"]]], new_starting_frame, transform_2d)
				_:
					push_warning("Unsupported type ", type, "!")

func m3d_to_transform2d(matrix) -> Transform2D:
	var x_axis:Vector2
	var y_axis:Vector2
	var translation:Vector2
	
	if is_optimized:
		x_axis = Vector2(matrix[0], matrix[1])
		y_axis = Vector2(matrix[4], matrix[5])
		translation = Vector2(matrix[12], matrix[13])
	else:
		x_axis = Vector2(matrix["m00"], matrix["m01"])
		y_axis = Vector2(matrix["m10"], matrix["m11"])
		translation = Vector2(matrix["m30"], matrix["m31"])

	return Transform2D(x_axis, y_axis, translation)

func get_index_at_frame(target_frame:int, frames:Array) -> Dictionary:
	var accumulated_frames = 0
	for frame in frames:
		accumulated_frames += frame[NAMES["duration"]]
		if target_frame <= accumulated_frames:
			return frame
	
	return {}

func _create_animation_player() -> void:
	var anim_player:AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
	if anim_player == null:
		push_error("Must have AnimationPlayer as a child!")
		return

	for anim_info in animations:
		if !symbols.has(anim_info.symbol_name): continue
		
		var layers = symbols[anim_info.symbol_name]
		var total_frames = get_timeline_length(layers)
		if total_frames <= 0:
			continue

		var anim = Animation.new()
		anim.length = float(total_frames) / fps
		anim.loop_mode = anim_info.loop_mode
		
		var track_symbol = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_symbol, ".:symbol")
		anim.value_track_set_update_mode(track_symbol, Animation.UPDATE_DISCRETE)
		anim.track_insert_key(track_symbol, 0.0, anim_info.symbol_name)
		
		var track_frame = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_frame, ".:cur_frame")
		
		anim.track_insert_key(track_frame, 0, 0)
		anim.track_insert_key(track_frame, anim.length, total_frames)
		
		var anim_name = anim_info.symbol_name.replace("/", "_").replace(" ", "_")
		
		var lib:AnimationLibrary
		if not anim_player.has_animation_library("AtlasSymbols"):
			lib = AnimationLibrary.new()
			anim_player.add_animation_library("AtlasSymbols", lib)
		else:
			lib = anim_player.get_animation_library("AtlasSymbols")
		
		lib.add_animation(anim_name, anim)
