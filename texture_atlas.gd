class_name TextureAtlas extends Node2D

const NAMES = {
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
@export var symbol:String = ""

@export var cur_frame:int = 0:
	set(value):
		cur_frame = value
		queue_redraw()

@export var animation_json:JSON:
	set(value):
		animation_json = value
		
		if animation_json != null:
			var dir = animation_json.resource_path.get_base_dir()
			spritemap_tex = load(dir.path_join("spritemap1.png"))
			spritemap_json = load(dir.path_join("spritemap1.json"))
			
			if animation_json.data.has("AN"):
				is_optimized = true

var is_optimized:bool = false

var spritemap_tex:Texture2D
var spritemap_json:JSON

var limbs:Dictionary[String, Rect2i] = {}
var symbols:Dictionary[String, Array] = {}

func _gkey(key:String):
	if is_optimized && NAMES.has(key):
		return NAMES[key]
	else:
		return key

func _ready() -> void:
	for _sprite in spritemap_json.data["ATLAS"]["SPRITES"]:
		var sprite = _sprite["SPRITE"] # i dont know why these are in their own dict
		limbs[sprite["name"]] = Rect2i(int(sprite["x"]), int(sprite["y"]), int(sprite["w"]), int(sprite["h"]))
	
	if animation_json.data.has(_gkey("SYMBOL_DICTIONARY")):
		for symbol_data in animation_json.data[_gkey("SYMBOL_DICTIONARY")][_gkey("Symbols")]:
			symbols[symbol_data[_gkey("SYMBOL_name")]] = symbol_data[_gkey("TIMELINE")][_gkey("LAYERS")]
			symbols[symbol_data[_gkey("SYMBOL_name")]].reverse()
	
	# lets just hope no one names their symbol this lol
	symbols["_timeline"] = animation_json.data[_gkey("ANIMATION")][_gkey("TIMELINE")][_gkey("LAYERS")]
	symbols["_timeline"].reverse()

var count = 0.0
func _process(delta: float) -> void:
	#temp
	count += delta
	
	if count >= 1./24.:
		count = 0
		cur_frame += 1

func _draw() -> void:
	if symbol == "" || !symbols.has(symbol):
		_draw_timeline(symbols["_timeline"])
	else:
		_draw_timeline(symbols[symbol])

func _draw_timeline(layers:Array, starting_frame:int = 0, transformation:Transform2D = Transform2D()):
	for layer in layers:
		var frame = get_index_at_frame(cur_frame, layer[_gkey("Frames")])
		
		if frame.is_empty(): continue
		
		for _element:Dictionary in frame[_gkey("elements")]:
			var type = _element.keys()[0]
			var element = _element[type]
			
			var transform_2d = transformation * m3d_to_transform2d(element[_gkey("Matrix3D")])
			
			match type:
				"ATLAS_SPRITE_instance", "ASI":
					var limb = limbs[element[_gkey("name")]]
					
					draw_set_transform_matrix(transform_2d)
					draw_texture_rect_region(spritemap_tex, Rect2i(0, 0, limb.size.x, limb.size.y), limbs[element[_gkey("name")]])
				"SYMBOL_Instance", "SI":
					if element[_gkey("symbolType")] == _gkey("movieclip"):
						starting_frame = 0
					else:
						starting_frame += element[_gkey("firstFrame")]
					
					_draw_timeline(symbols[element[_gkey("SYMBOL_name")]], starting_frame, transform_2d)
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
		x_axis = Vector2(matrix[_gkey("m00")], matrix[_gkey("m01")])
		y_axis = Vector2(matrix[_gkey("m10")], matrix[_gkey("m11")])
		translation = Vector2(matrix[_gkey("m30")], matrix[_gkey("m31")])

	return Transform2D(x_axis, y_axis, translation)

func get_index_at_frame(target_frame: int, frames: Array) -> Dictionary:
	var total_duration:int = 0
	
	for frame in frames:
		total_duration += frame[_gkey("duration")]
	
	target_frame = target_frame % total_duration
	
	var accumulated_frames = 0
	for frame in frames:
		accumulated_frames += frame[_gkey("duration")]
		if target_frame < accumulated_frames:
			return frame
	
	return {}
