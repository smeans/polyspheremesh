@tool
extends MeshInstance3D

class_name PolySphereMesh

@export var radius := 1.0: set = set_radius
@export var levels := 6: set = set_levels
@export var slices := 5: set = set_slices
@export var flip_normals := false: set = set_flip_normals
func set_flip_normals(new_flip_normals):
	flip_normals = new_flip_normals
	_trigger_refresh()

@export var value := .5: set = set_value
func set_value(new_value):
	value = new_value
	_trigger_refresh()

@export var show_level := 1: set = set_show_level
func set_show_level(new_level):
	show_level = new_level
	_trigger_refresh()

@export var filter_level := false: set = set_filter_level
func set_filter_level(new_filter_level):
	filter_level = new_filter_level
	_trigger_refresh()
	
@export var only_points := false: set = set_only_points
func set_only_points(new_only_points):
	only_points = new_only_points
	_trigger_refresh()

var _is_valid: bool = false
var _refresh_pending: bool = false
var _has_equator: bool
var _vertex_count: int
var _triangle_count: int
var _level_vertex_count: Array = []
var _level_vertex_offset: Array = []
var _twist: Array = []
var _middle_level: int
var _arrays: Array = []


func _init():
	_arrays.resize(Mesh.ARRAY_MAX)
	
	_trigger_refresh()
	
func set_radius(new_radius):
	radius = new_radius
	_trigger_refresh()
	
func set_levels(new_levels: int):
	levels = max(new_levels, 3)
	_trigger_refresh()

func set_slices(new_slices: int):
	slices = max(new_slices, 3)
	_trigger_refresh()

func _build_vertex_array():
	var vertex_array := PackedVector3Array()
	vertex_array.resize(_vertex_count)
	
	var i = 0
	var inclination = PI/2.0
	var inclination_step = -PI/(levels-1)
	
	for level in range(0, levels):
		var radial_step = 2.0*PI/_level_vertex_count[level]
		var radial_angle = -PI -_twist[level]
				
		log_debug(['\nlevel ', level, ' inclination ', inclination, ' radial_step ', radial_step])
		
		for radial in range(0, _level_vertex_count[level]):
			log_debug(['radial ', radial, ' radial_angle ', radial_angle])
			var point_vector = Vector3(cos(inclination)*sin(radial_angle), sin(inclination), cos(inclination)*cos(radial_angle)).normalized()
			log_debug(['vector ', point_vector])
				
			vertex_array[i] = point_vector * radius
			i += 1
			radial_angle += radial_step
			
		inclination += inclination_step
			
	return vertex_array

func _build_index_array():
	var index_array := PackedInt32Array()
	
	index_array.resize(_triangle_count*3)
	log_debug(['_triangle_count', _triangle_count])
	
	var ii = 0
	var level = 1
	
	while level < levels:
		log_debug(['\nprocessing level ', level])
		var vo = [_level_vertex_offset[level], _level_vertex_offset[level-1]]
		var vc = [_level_vertex_count[level], _level_vertex_count[level-1]]
		var tc = [
			(vc[0] if vc[0] > 1 else 0),
			(vc[-1] if vc[-1] > 1 else 0)
		]
		var bs = [min(max(vc[0]/slices, 1), tc[0]), min(max(vc[-1]/slices, 1), tc[-1])]
		var vi = [0, 0]
		var turn = 0 if bs[0] >= bs[-1] else -1

		log_debug([' vc ', vc, ' bs ', bs, ' tc ', tc, ' ~turn ', ~turn])
		
		while tc[turn] > 0 or tc[~turn] > 0:
			log_debug(['turn starting tc ', tc, ' vi ', vi, ' ~turn ', ~turn])
			var bc = min(bs[turn], tc[turn])
			
			while bc > 0:
				assert(tc[turn] > 0)
				log_debug(['tc ', tc, ' bc ', bc, ' vi ', vi])
				var a = abs(turn-1) if flip_normals else (turn+2)
				var b = 0
				var c = (turn+2) if flip_normals else abs(turn-1)
				index_array[ii+a] = vo[turn] + (vi[turn]%vc[turn])
				index_array[ii+b] = vo[~turn] + (vi[~turn]%vc[~turn])
				vi[turn] += 1
				index_array[ii+c] = vo[turn] + (vi[turn]%vc[turn])
				ii += 3
				log_debug([index_array[ii-3], '-', index_array[ii-2], '-', index_array[ii-1]])
				tc[turn] -= 1
				bc -= 1
			
			log_debug(['switching turn ', turn, ' to ', ~turn])
			turn = ~turn
		
		level += 1

	log_debug(['ii ', ii, ' index_array size ', len(index_array)])
	
	return index_array

func _build_normal_array():
	var normal_array := PackedVector3Array()
	normal_array.resize(_vertex_count)
	
	var vertex_array = _arrays[Mesh.ARRAY_VERTEX]
	var index_array = _arrays[Mesh.ARRAY_INDEX]
	var x := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	
	for i in range(0, index_array.size(), 3):
		for j in range(0, 3):
			x[j] = vertex_array[index_array[i+(j+1)%3]] - vertex_array[index_array[i+j]]
		
		var cross := Vector3.ZERO
		for j in range(0, 3):
			cross += x[j].cross(x[(j+1)%3]) * -1.0
		
		cross = cross.normalized()
		
		for j in range(0, 3):
			normal_array[index_array[i+j]] = cross
	
	return normal_array

func _build_uv_array():
	var uv_array = PackedVector2Array()
	uv_array.resize(_vertex_count)
	
	var ii = 0
	for level in range(0, levels):
		for i in range(_level_vertex_count[level]):
			uv_array[ii] = Vector2(float(level)/(levels), float(i)/(_level_vertex_count[level]))
			ii += 1
	
	return uv_array
	
func _build_color_array():
	var color_array = PackedColorArray()
	color_array.resize(_vertex_count)
	
	var i = 0
	var hue = .3234
	for level in range(levels):
		for j in range(_level_vertex_count[level]):
			if filter_level and level != show_level:
				color_array[i] = Color(0, 0, 0, 0)
			else:
				color_array[i] = Color.from_hsv(randf(), .7, 1.0, 1.0)
				hue = fmod(hue*1.123, 1.0)
			i += 1
			
	return color_array
	
func _build_arrays():
	log_debug(['building arrays for PolySphere levels ', levels, ' slices ', slices])
	_level_vertex_count.resize(levels)
	_level_vertex_offset.resize(levels)
	
	_has_equator = levels % 2 == 1
	log_debug(['has_equator ', _has_equator])
	_middle_level = levels/2.0
	log_debug(['middle_level ', _middle_level])
	
	_vertex_count = 0

	for i in range(0, _middle_level):
		_level_vertex_count[i] = max(i * slices, 1)
		_level_vertex_count[-i-1] = max(i * slices, 1)
		
	if _has_equator:
		_level_vertex_count[_middle_level] = _middle_level * slices
	
	
	_twist.resize(levels)
	_twist[0] = 0.0
	_twist[1] = 0.0
	_twist[-1] = 0.0
	_twist[-2] = 0.0
	for level in range(2, _middle_level if not _has_equator else _middle_level + 1):
		var radial_step = 2.0*PI/_level_vertex_count[level-1]
		_twist[level] = _twist[level-1] + radial_step/2.0
		
		_twist[-level-1] = _twist[level]

		log_debug(['level ', level, ' twist snapshot ', _twist])
		
	log_debug(['twist ', _twist])
		
		
	_level_vertex_offset[0] = 0
	for i in range(1, levels):
		_level_vertex_offset[i] = _level_vertex_offset[i-1] + _level_vertex_count[i-1]
		
	log_debug(['_level_vertex_count', _level_vertex_count])
	log_debug(['_level_vertex_offset', _level_vertex_offset])
	
	_vertex_count = _level_vertex_offset[-1] + _level_vertex_count[-1]
	_triangle_count = (_vertex_count - 2) * 2
	
	_arrays[Mesh.ARRAY_VERTEX] = _build_vertex_array()
	_arrays[Mesh.ARRAY_INDEX] = _build_index_array()
	_arrays[Mesh.ARRAY_NORMAL] = _build_normal_array()
	_arrays[Mesh.ARRAY_TEX_UV] = _build_uv_array()
	_arrays[Mesh.ARRAY_COLOR] = _build_color_array()		
		
	_is_valid = true

func _refresh_mesh():
	log_debug(['refreshing PolySphereMesh'])
	_refresh_pending = false
	
	if not _is_valid:
		_build_arrays()
		
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS if only_points else Mesh.PRIMITIVE_TRIANGLES, _arrays)
	var aabb = AABB(Vector3(-radius, -radius, -radius), Vector3(radius*2.0, radius*2.0, radius*2.0))
	print_debug('before set ', array_mesh.get_aabb())
	array_mesh.custom_aabb = aabb
	print_debug('custom aabb ', aabb, ' aabb ', array_mesh.get_aabb())
	mesh = array_mesh
	
	set_surface_override_material(0, load("res://TestMaterial.tres"))
	
	_is_valid = true

func _trigger_refresh():
	if _refresh_pending:
		return
	
	_is_valid = false
	call_deferred('_refresh_mesh')
	_refresh_pending = true
	
func log_debug(args):
	pass
