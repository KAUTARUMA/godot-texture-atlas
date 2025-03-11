class_name TextureAtlas extends Node2D

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

var spritemap_tex:Texture2D
var spritemap_json:JSON

var limbs:Dictionary[String, Rect2i] = {}
var symbols:Dictionary[String, Array] = {}

func _ready() -> void:
	for _sprite in spritemap_json.data["ATLAS"]["SPRITES"]:
		var sprite = _sprite["SPRITE"] # i dont know why these are in their own dict
		limbs[sprite["name"]] = Rect2i(int(sprite["x"]), int(sprite["y"]), int(sprite["w"]), int(sprite["h"]))
	
	if animation_json.data.has("SYMBOL_DICTIONARY"):
		for symbol_data in animation_json.data["SYMBOL_DICTIONARY"]["Symbols"]:
			symbols[symbol_data["SYMBOL_name"]] = symbol_data["TIMELINE"]["LAYERS"]
			symbols[symbol_data["SYMBOL_name"]].reverse()
	
	# lets just hope no one names their symbol this lol
	symbols["_timeline"] = animation_json.data["ANIMATION"]["TIMELINE"]["LAYERS"]
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
		var frame = get_index_at_frame(cur_frame, layer["Frames"])
		
		if frame.is_empty(): continue
		
		for _element:Dictionary in frame["elements"]:
			var type = _element.keys()[0]
			var element = _element[type]
			
			var transform_2d = transformation * m3d_to_transform2d(element["Matrix3D"])
			
			match type:
				"ATLAS_SPRITE_instance":
					var limb = limbs[element.name]
					
					draw_set_transform_matrix(transform_2d)
					draw_texture_rect_region(spritemap_tex, Rect2i(0, 0, limb.size.x, limb.size.y), limbs[element.name])
				"SYMBOL_Instance":
					if element["symbolType"] == "movieclip":
						starting_frame = 0
					else:
						starting_frame += element["firstFrame"]
					
					_draw_timeline(symbols[element["SYMBOL_name"]], starting_frame, transform_2d)
				_:
					push_warning("Unsupported type ", type, "!")

func m3d_to_transform2d(matrix: Dictionary) -> Transform2D:
	var x_axis := Vector2(matrix["m00"], matrix["m01"])
	var y_axis := Vector2(matrix["m10"], matrix["m11"])
	var translation := Vector2(matrix["m30"], matrix["m31"])

	return Transform2D(x_axis, y_axis, translation)

func get_index_at_frame(target_frame: int, frames: Array) -> Dictionary:
	var total_duration:int = 0
	
	for frame in frames:
		total_duration += frame["duration"]
	
	target_frame = target_frame % total_duration
	
	var accumulated_frames = 0
	for frame in frames:
		accumulated_frames += frame["duration"]
		if target_frame < accumulated_frames:
			return frame
	
	return {}
