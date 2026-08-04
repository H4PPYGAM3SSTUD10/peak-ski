## mountain_generator.gd
## Procedurally builds the whole mountain at load time: a snow piste running
## down a valley, rocky walls either side, a jump kicker, a flat run-out, and
## trees along the treeline. Generates the visual mesh AND the collision body,
## so there is ground everywhere on the map — no void to fall into.
##
## COORDINATES ARE PLAIN WORLD SPACE. The terrain is a heightmap: y = f(x, z),
## with the run descending along +z. Nothing here needs hand-computed
## transforms, and anything that must sit on the snow (skier, race gates)
## raycasts down to find it rather than hardcoding a height.

extends Node3D

# ── Map extents ───────────────────────────────────────────────────────────────
const MAP_HALF_W := 200.0    ## x spans -200 … +200
const MAP_HALF_L := 450.0    ## z spans -450 … +450  (start at -z, finish at +z)
const CELL       := 6.0      ## heightmap resolution (m). Lower = finer + slower.

# ── Run profile ───────────────────────────────────────────────────────────────
const SLOPE_TAN    := 0.364  ## tan(20°) — steepness of the main pitch
const RUNOUT_START := 300.0  ## z where the pitch begins flattening out
const RUNOUT_LEN   := 140.0  ## how long the flattening takes
const END_RISE     := 40.0   ## upslope at the very end, to catch the skier

# ── Valley shape ──────────────────────────────────────────────────────────────
const PISTE_HALF   := 38.0   ## half-width of the groomed run
const WALL_BLEND   := 95.0   ## distance over which walls rise beyond the piste
const WALL_HEIGHT  := 115.0  ## how high the valley walls get

# ── Jump kicker ───────────────────────────────────────────────────────────────
const JUMP_Z    := -40.0
const JUMP_LEN  := 14.0
const JUMP_RISE := 5.5

# ── Trees ─────────────────────────────────────────────────────────────────────
const TREE_COUNT := 420

var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed             = 1337
	_noise.frequency        = 0.006
	_noise.fractal_octaves  = 4
	_build_terrain()
	_scatter_trees()


# ── The heightmap ─────────────────────────────────────────────────────────────

## Ground height at any point. This is the single source of truth for the
## mountain's shape — the mesh, the collision, and the trees all read from it.
func height_at(x: float, z: float) -> float:
	# Main pitch, easing into a flat run-out. Past RUNOUT_LEN the gradient has
	# reached zero, so the terrain is level from there on.
	var h := 0.0
	if z <= RUNOUT_START:
		h = -SLOPE_TAN * z
	else:
		var d := minf(z - RUNOUT_START, RUNOUT_LEN)
		h = -SLOPE_TAN * RUNOUT_START - SLOPE_TAN * d * (1.0 - d / (2.0 * RUNOUT_LEN))

	# Valley walls: flat inside the piste, climbing steeply outside it.
	var w := smoothstep(PISTE_HALF, PISTE_HALF + WALL_BLEND, absf(x))
	h += w * WALL_HEIGHT

	# Rocky relief on the walls; only gentle rolls on the groomed run.
	h += _noise.get_noise_2d(x, z) * 22.0 * w
	h += _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.7 * (1.0 - w)

	# Jump kicker: ramps up across the piste, then drops away at the lip.
	if z >= JUMP_Z - JUMP_LEN and z <= JUMP_Z:
		var t := (z - (JUMP_Z - JUMP_LEN)) / JUMP_LEN
		h += JUMP_RISE * t * t * (1.0 - w)

	# Terminal upslope so a fast skier is caught rather than launched off the map.
	h += smoothstep(MAP_HALF_L - 90.0, MAP_HALF_L, z) * END_RISE

	return h


## Surface normal, from finite differences of height_at.
func normal_at(x: float, z: float) -> Vector3:
	var h  := height_at(x, z)
	var hx := height_at(x + 1.0, z) - h
	var hz := height_at(x, z + 1.0) - h
	return Vector3(-hx, 1.0, -hz).normalized()


## Snow on gentle ground, bare rock where it gets steep.
func _color_at(x: float, z: float) -> Color:
	var rock := smoothstep(0.86, 0.62, normal_at(x, z).y)
	return Color(0.94, 0.96, 1.0).lerp(Color(0.34, 0.32, 0.31), rock)


# ── Mesh + collision ──────────────────────────────────────────────────────────

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tris := PackedVector3Array()

	var x := -MAP_HALF_W
	while x < MAP_HALF_W:
		var z := -MAP_HALF_L
		while z < MAP_HALF_L:
			var x0 := x
			var x1 := x + CELL
			var z0 := z
			var z1 := z + CELL

			var a := Vector3(x0, height_at(x0, z0), z0)
			var b := Vector3(x1, height_at(x1, z0), z0)
			var c := Vector3(x1, height_at(x1, z1), z1)
			var d := Vector3(x0, height_at(x0, z1), z1)

			for v in [a, b, c, a, c, d]:
				st.set_color(_color_at(v.x, v.z))
				st.add_vertex(v)
				tris.append(v)

			z += CELL
		x += CELL

	st.generate_normals()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	st.set_material(mat)

	var body := StaticBody3D.new()
	body.name = "Terrain"
	add_child(body)

	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = st.commit()
	body.add_child(mi)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(tris)
	var cs := CollisionShape3D.new()
	cs.name  = "TerrainCollision"
	cs.shape = shape
	body.add_child(cs)


# ── Scenery ───────────────────────────────────────────────────────────────────

## Conifers along the treeline: outside the piste, but only where the ground is
## gentle enough that a tree could actually stand.
func _scatter_trees() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius    = 0.0
	cone.bottom_radius = 1.8
	cone.height        = 8.0

	var tree_mat := StandardMaterial3D.new()
	tree_mat.albedo_color = Color(0.09, 0.20, 0.12)
	tree_mat.roughness    = 1.0

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone

	var placed : Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	var attempts := 0
	while placed.size() < TREE_COUNT and attempts < TREE_COUNT * 12:
		attempts += 1
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var tx := side * rng.randf_range(PISTE_HALF + 5.0, PISTE_HALF + 62.0)
		var tz := rng.randf_range(-MAP_HALF_L + 20.0, MAP_HALF_L - 20.0)
		if normal_at(tx, tz).y < 0.82:
			continue   # too steep to hold a tree
		var s := rng.randf_range(0.7, 1.5)
		var t := Transform3D(Basis().scaled(Vector3(s, s, s)),
			Vector3(tx, height_at(tx, tz) + 4.0 * s, tz))
		placed.append(t)

	mm.instance_count = placed.size()
	for i in placed.size():
		mm.set_instance_transform(i, placed[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	mmi.multimesh = mm
	mmi.material_override = tree_mat
	add_child(mmi)
