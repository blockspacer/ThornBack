extends MeshInstance

const Block = preload("res://Scenes/Block.tscn")
onready var World = $".."
const CHUNK_SIZE = 16
const SURFACE_HEIGHT = 60
const WORLD_HEIGHT = 128

const SOUTH = 0
const NORTH = 1
const EAST = 2
const WEST = 3
const TOP = 4
const BOTTOM = 5

var offset

var voxels
var material

func _ready():
	mesh = ArrayMesh.new()
	material = SpatialMaterial.new()
	material.vertex_color_use_as_albedo = true
	
	var face
	voxels = []
	voxels.resize(CHUNK_SIZE)
	for i in range(CHUNK_SIZE):
		voxels[i] = []
		voxels[i].resize(WORLD_HEIGHT)
		for j in range(WORLD_HEIGHT):
			voxels[i][j] = []
			voxels[i][j].resize(CHUNK_SIZE)
			for k in range(CHUNK_SIZE):
				face = VoxelFace.new()
				face.type = 0
				face.transparent = true
				voxels[i][j][k] = face
	
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var pos = Vector3(x, 0, z)
			pos.y = floor((World.noise.get_noise_2d((pos.x + translation.x) / 5, (pos.z + translation.z) / 5) / 2 + 0.5) * SURFACE_HEIGHT)
			newBlock(pos, 1)
	
			for y in range(pos.y):
				newBlock(Vector3(pos.x, y, pos.z), 2 if y < 2 else 3)
	
	greedy_mesher()

func newBlock(pos, type):
	#var block = Block.instance()
	#block.translate(pos)
	voxels[pos.x][pos.y][pos.z].type = type
	voxels[pos.x][pos.y][pos.z].transparent = false
	#add_child(block)

#TODO add rob's comments
#TODO consider turning x and q into vectors
#TODO probably (re)port greedy_mesher to C++

#Port of Rob O'Leary's implementation of a greedy meshing algorithm
#https://github.com/roboleary/GreedyMesh/
#which in turn is a port of Mikola Lysenko's implementation
#https://0fps.net/2012/06/30/meshing-in-a-minecraft-game/
func greedy_mesher():
	var n
	var side = 0
	var mesh_width
	var mesh_height
	
	var x = Vector3()
	var q = Vector3()
	var chunk_size = Vector3(CHUNK_SIZE, WORLD_HEIGHT, CHUNK_SIZE)
	var du = Vector3()
	var dv = Vector3()
	
	#might produce an issue with size
	var mask = []
	mask.resize(CHUNK_SIZE * WORLD_HEIGHT)
	
	#Working variables for comparison
	var voxel_face1
	var voxel_face2
	
	#TODO find a way to write traditional for loops
	var back_face = true
	var b = false
	while b != back_face:
		for axis in range(3):
			var u = (axis + 1) % 3
			var v = (axis + 2) % 3
			
			x = Vector3()
			q = Vector3()
			q[axis] = 1
			
			match axis:
				0:
					side = WEST if back_face else EAST
				1:
					side = BOTTOM if back_face else TOP
				2:
					side = SOUTH if back_face else NORTH
			
			
			x[axis] = -1
			while x[axis] < chunk_size[axis]:
				n = 0
				
				x[v] = 0
				while x[v] < chunk_size[v]:
					x[u] = 0
					while x[u] < chunk_size[u]:
						voxel_face1 = get_voxel_face(x,		side) 	if x[axis] >= 0				else null
						voxel_face2 = get_voxel_face(x + q,	side) 	if x[axis] < chunk_size[axis] - 1 else null
						
						mask[n] = null if (voxel_face1 != null && voxel_face2 != null && voxel_face1.equals(voxel_face2)) else (voxel_face2 if back_face else voxel_face1)
						n += 1
						
						x[u] += 1
					x[v] += 1
				
				x[axis] += 1
				
				#Generating the mesh for the mask
				n = 0
				
				for j in range(chunk_size[v]):
					var i = 0
					while i < chunk_size[u]:
						if mask[n] != null:
							
							mesh_width = 1
							while i + mesh_width < chunk_size[u] && mask[n + mesh_width] != null && mask[n + mesh_width].equals(mask[n]):
								mesh_width += 1
							
							var done = false
							
							mesh_height = 1
							while j + mesh_height < chunk_size[v]:
								for k in range(mesh_width):
									if mask[n + k + mesh_height * chunk_size[u]] == null || !mask[n + k + mesh_height * chunk_size[u]].equals(mask[n]):
										done = true
										break
								
								if done:
									break
								
								mesh_height += 1
							
							if !mask[n].transparent:
								x[u] = i
								x[v] = j
								
								du = Vector3()
								du[u] = mesh_width
								
								dv = Vector3()
								dv[v] = mesh_height
								
								add_quad(
									x,
									x + du,
									x + du + dv,
									x + dv,
									mask[n], back_face)
							
							for l in range(mesh_height):
								for k in range(mesh_width):
									mask[n + k + l * chunk_size[u]] = null
							
							i += mesh_width
							n += mesh_width
							
						else:
							i += 1
							n += 1
		
		back_face = back_face && b
		b = !b

func _init(x, z):
	translation = Vector3(x, 0, z) * CHUNK_SIZE
	offset = Vector2(x, z)

#TODO consider changing param order
func add_quad(bottom_left, top_left, top_right, bottom_right, voxel, back_face):
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	
	arrays[ArrayMesh.ARRAY_VERTEX] = [
		bottom_left, bottom_right, top_left, top_right
	]
	
	arrays[ArrayMesh.ARRAY_INDEX] = PoolIntArray([2,0,1, 1,3,2] if back_face else [2,3,1, 1,0,2])
	var color_array = []
	for i in range(4):
		match voxel.type:
			1:
				color_array.push_back(Color.red)
			2:
				color_array.push_back(Color.green)
			_:
				color_array.push_back(Color.blue)
				
	arrays[ArrayMesh.ARRAY_COLOR] = PoolColorArray(color_array)
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)

func get_voxel_face(pos, side):
	var voxel_face = voxels[pos.x][pos.y][pos.z]
	voxel_face.side = side
	
	return voxel_face

class VoxelFace:
	var transparent
	var type
	var side
	
	func equals(other):
		return other.transparent == transparent && other.type == type