extends Node

@export var json1:JSON
@export var json2:JSON

func _ready():
	print(flatten_and_merge(json1.data, json2.data))

func flatten_and_merge(dict1: Dictionary, dict2: Dictionary, merged_dict: Dictionary = {}) -> Dictionary:
	var keys1 = dict1.keys()
	var keys2 = dict2.keys()
	
	var min_size = min(keys1.size(), keys2.size())
	
	for i in range(min_size):
		var key1 = keys1[i]
		var key2 = keys2[i]
		var value1 = dict1[key1]
		var value2 = dict2[key2]
		
		if value1 is Dictionary and value2 is Dictionary:
			flatten_and_merge(value1, value2, merged_dict)
		elif value1 is Array and value2 is Array:
			var min_array_size = min(value1.size(), value2.size())
			for j in range(min_array_size):
				if value1[j] is Dictionary and value2[j] is Dictionary:
					flatten_and_merge(value1[j], value2[j], merged_dict)
		else:
			merged_dict[key1] = key2
	
	return merged_dict
