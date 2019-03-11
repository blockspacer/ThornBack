extends Node

const Chunk = preload("res://Scripts/Chunk.gd")
var noise = OpenSimplexNoise.new()

func _ready():
	noise.seed = 43
	noise.octaves = 4
	noise.period = 20.0
	noise.persistence = 0.8

	for x in range(-5, 5):
		for y in range(-5, 5):
			print("Generating chunk [", x, ", ", y, "]...")
			add_child(Chunk.new(x, y))