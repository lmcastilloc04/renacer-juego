class_name LevelManager
extends Node
## Gestor de los 6 mapas del juego. Lee res://Data/levels.json y, para cada mapa:
##   - pinta el terreno (suelo, obstaculos, decoracion) en las capas del mapa
##   - crea edificios, personas, senales, recursos, zonas restringidas y escombros
##   - coloca al jugador, la camara y la meta
##   - revisa la victoria (llegar a la meta con lo pedido hecho) y la derrota
##   - lanza las replicas sismicas, las pantallas de resultado y el final
## Es hijo de Scene_Game: lo crea scene_game.gd.

signal final_quiz_requested
signal final_quiz_done
signal quit_to_title
signal play_again

const DATA_PATH: String = "res://Data/levels.json"
## Esquina superior izquierda del mapa dentro de Scene_Game (la misma de la capa Ciudad).
const ORIGIN: Vector2 = Vector2(-288.0, 1392.0)
const CELL: float = 16.0
const LEGACY_NODES: Array[String] = ["TileMapLayer_Mountain", "TileMapLayer_Renacer", "Map_help", "WallMaster"]
const DYNAMIC_GROUPS: Array[String] = ["edificios", "interactuables", "civiles", "zonas", "escombros"]
const SCRIPT_BUILDING: String = "res://Scripts/Game/building.gd"
const SCRIPT_INTERACTABLE: String = "res://Scripts/Game/interactable.gd"
const SCRIPT_ZONE: String = "res://Scripts/Game/restricted_zone.gd"
const SCRIPT_RUBBLE: String = "res://Scripts/Game/rubble.gd"
const TEXTURE: Texture2D = preload("res://Assets/Kenney/tilemap_packed.png")

var index: int = 0
var level: Dictionary = {}
var ui: LevelUI

var _scene: Node2D
var _levels: Array = []
var _tiles: Dictionary = {}
var _frames: Dictionary = {}
var _cars: Dictionary = {}
var _ground: TileMapLayer
var _obstacles: TileMapLayer
var _deco: TileMapLayer
var _origin_cell: Vector2i = Vector2i.ZERO
var _playing: bool = false
var _busy: bool = false
var _score_start: int = 0
var _stats_start: Dictionary = {}
var _max_points: int = 0
var _tremor_timer: float = 0.0
var _check_timer: float = 0.0
var _goal_msg_cooldown: float = 0.0
var _summaries: Array = []


func _ready() -> void:
	_scene = get_parent() as Node2D
	_load_data()
	_cleanup_legacy()
	_setup_layers()
	ui = LevelUI.new()
	add_child(ui)


# ================================================================== datos y escena
func _load_data() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("No puedo abrir " + DATA_PATH + ". Copia la carpeta Data/ al proyecto.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("levels.json no es un JSON valido.")
		return
	_tiles = parsed["tiles"]
	_frames = parsed["frames"]
	_cars = parsed["cars"]
	_levels = parsed["levels"]


## Quita lo que quedo del juego de Zelda (solo mientras se juega; la escena en el editor no cambia).
func _cleanup_legacy() -> void:
	for n in LEGACY_NODES:
		var node := _scene.get_node_or_null(n)
		if node != null:
			node.queue_free()


func _setup_layers() -> void:
	_ground = _scene.get_node_or_null("TileMapLayer_Ciudad") as TileMapLayer
	if _ground == null:
		push_error("Falta el nodo TileMapLayer_Ciudad en la escena.")
		return
	_obstacles = _layer("TileMapLayer_Obstaculos", 1)
	_deco = _layer("TileMapLayer_Decoracion", 2)
	_origin_cell = Vector2i(((ORIGIN - _ground.position) / CELL).round())


func _layer(layer_name: String, offset: int) -> TileMapLayer:
	var layer := _scene.get_node_or_null(layer_name) as TileMapLayer
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = layer_name
		_scene.add_child(layer)
		_scene.move_child(layer, mini(_ground.get_index() + offset, _scene.get_child_count() - 1))
	layer.tile_set = _ground.tile_set
	layer.position = _ground.position
	layer.collision_enabled = true
	return layer


func total_levels() -> int:
	return _levels.size()


# ================================================================== flujo de la partida
## Construye el mapa 1 (se ve detras de la trivia inicial).
func prepare() -> void:
	index = 0
	_build_level(index)


## Muestra la mision del mapa y empieza a jugar.
func begin() -> void:
	await _start_current()


func _start_current() -> void:
	_playing = false
	_busy = true
	GameManager.play_music(String(level["music"]))
	await ui.show_briefing(level, index, _levels.size())
	_busy = false
	_playing = true


## La llama la meta (goal_zone.gd) a traves de scene_game.finish_mission().
func try_finish() -> void:
	if not _playing or _busy:
		return
	var missing: String = _missing()
	if missing != "":
		if _goal_msg_cooldown <= 0.0:
			_goal_msg_cooldown = 3.0
			GameManager.toast("warning", "Aún no", missing)
		return
	_busy = true
	_playing = false
	await _complete_level()


func _complete_level() -> void:
	var summary: Dictionary = _build_summary()
	_summaries.append(summary)
	if index >= _levels.size() - 1:
		await _final_sequence()
		return
	GameManager.sfx("success")
	await ui.show_complete(summary)
	index += 1
	_build_level(index)
	await _start_current()


func _fail(reason: String) -> void:
	if _busy:
		return
	_busy = true
	_playing = false
	GameManager.sfx("defeat")
	var choice: String = await ui.show_failed(reason, String(level["lesson"]))
	if choice == "retry":
		GameManager.score = _score_start
		GameManager.stats = _stats_start.duplicate()
		GameManager.score_changed.emit(GameManager.score)
		_build_level(index)
		await _start_current()
	else:
		quit_to_title.emit()


func _final_sequence() -> void:
	await _arrival_cutscene()
	GameManager.mission_finished = true
	final_quiz_requested.emit()
	await final_quiz_done
	var choice: String = await ui.show_ending(_final_summary())
	if choice == "again":
		play_again.emit()
	else:
		quit_to_title.emit()


# ================================================================== construccion del mapa
func _build_level(i: int) -> void:
	level = _levels[i]
	_purge()
	_paint(level)
	_spawn(level)
	_place_player_goal_camera(level)
	_score_start = GameManager.score
	_stats_start = GameManager.stats.duplicate()
	GameManager.reset_level_counters(int(level["bombs"]))
	GameManager.set_level_label("Mapa %d/%d" % [i + 1, _levels.size()])
	GameManager.stat("bld_total", GameManager.total_buildings())
	GameManager.stat("civ_total", GameManager.total_civilians())
	_max_points = _compute_max_points(level)
	var tr: Variant = level.get("tremors")
	_tremor_timer = randf_range(float(tr[0]), float(tr[1])) + 8.0 if tr != null else -1.0
	_check_timer = 1.0


func _purge() -> void:
	for g in DYNAMIC_GROUPS:
		for n in get_tree().get_nodes_in_group(g):
			for g2 in DYNAMIC_GROUPS:
				n.remove_from_group(g2)
			n.queue_free()
	for b in get_tree().get_nodes_in_group("bombas"):
		b.queue_free()


func _t(tile_name: String) -> Vector2i:
	var a: Array = _tiles[tile_name]
	return Vector2i(int(a[0]), int(a[1]))


func _put_tile(layer: TileMapLayer, x: int, y: int, tile: Vector2i) -> void:
	layer.set_cell(_origin_cell + Vector2i(x, y), 0, tile)


func _layer_for(code: String) -> TileMapLayer:
	match code:
		"g":
			return _ground
		"o":
			return _obstacles
	return _deco


func _paint(lv: Dictionary) -> void:
	_ground.clear()
	_obstacles.clear()
	_deco.clear()
	for op in lv["ops"]:
		var layer: TileMapLayer = _layer_for(String(op[0]))
		match String(op[1]):
			"put":
				_put_tile(layer, int(op[2]), int(op[3]), _t(String(op[4])))
			"fill":
				for x in range(int(op[2]), int(op[4]) + 1):
					for y in range(int(op[3]), int(op[5]) + 1):
						_put_tile(layer, x, y, _t(String(op[6])))
			"frame":
				_frame(layer, int(op[2]), int(op[3]), int(op[4]), int(op[5]), _frames[String(op[6])])
			"car":
				var pieces: Array = _cars[String(op[4])]
				for k in 4:
					var p: Array = pieces[k]
					_put_tile(layer, int(op[2]) + (k % 2), int(op[3]) + (k >> 1), Vector2i(int(p[0]), int(p[1])))


func _frame(layer: TileMapLayer, x0: int, y0: int, w: int, h: int, pieces: Array) -> void:
	for dx in w:
		for dy in h:
			var col: int = 0 if dx == 0 else (2 if dx == w - 1 else 1)
			var row: int = 0 if dy == 0 else (2 if dy == h - 1 else 1)
			var p: Array = pieces[row * 3 + col]
			_put_tile(layer, x0 + dx, y0 + dy, Vector2i(int(p[0]), int(p[1])))


func _spawn(lv: Dictionary) -> void:
	var building_script := load(SCRIPT_BUILDING) as Script
	var item_script := load(SCRIPT_INTERACTABLE) as Script
	var zone_script := load(SCRIPT_ZONE) as Script
	var rubble_script := load(SCRIPT_RUBBLE) as Script

	for b in lv["buildings"]:
		var body := StaticBody2D.new()
		body.set_script(building_script)
		body.set("floors", int(b["floors"]))
		body.set("safe_to_demolish", bool(b["safe"]))
		body.position = ORIGIN + Vector2(float(b["x"]), float(b["y"]))
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = Vector2(48, 64)
		col.shape = shape
		body.add_child(col)
		_scene.add_child(body)

	for p in lv["people"]:
		var n := _item(item_script, 0, p)
		n.set("display_name", String(p["name"]))
		n.set("tile", Vector2i(int(p["tile"][0]), int(p["tile"][1])))
		n.set("lines", PackedStringArray(p["lines"]))
		n.set("evacuable", bool(p["evac"]))
		var path := PackedVector2Array()
		for q in p["path"]:
			path.append(Vector2(float(q[0]), float(q[1])))
		n.set("safe_path", path)
		n.set("reward_points", 15)
		_scene.add_child(n)

	for s in lv["signs"]:
		var n := _item(item_script, 1, s)
		n.set("display_name", String(s["name"]))
		n.set("tile", Vector2i(int(s["tile"][0]), int(s["tile"][1])))
		n.set("tile_rows", int(s["rows"]))
		n.set("lines", PackedStringArray([String(s["text"])]))
		n.set("reward_points", 5)
		_scene.add_child(n)

	for s in lv["supplies"]:
		var n := _item(item_script, 2, s)
		n.set("display_name", String(s["name"]))
		n.set("tile", Vector2i(int(s["tile"][0]), int(s["tile"][1])))
		n.set("reward_points", int(s["points"]))
		n.set("reward_bombs", int(s["bombs"]))
		_scene.add_child(n)

	for z in lv["zones"]:
		var zone := Node2D.new()
		zone.set_script(zone_script)
		zone.position = ORIGIN + Vector2(float(z["x"]), float(z["y"]))
		zone.set("size", Vector2(float(z["w"]), float(z["h"])))
		zone.set("zone_name", String(z["name"]))
		zone.set("reason", String(z["reason"]))
		_scene.add_child(zone)

	for r in lv["rubble"]:
		var pile := StaticBody2D.new()
		pile.set_script(rubble_script)
		pile.position = ORIGIN + Vector2(float(r["x"]) * CELL, float(r["y"]) * CELL)
		pile.set("size_cells", Vector2i(int(r["w"]), int(r["h"])))
		pile.set("route", bool(r["route"]))
		_scene.add_child(pile)


## Crea el nodo SIN agregarlo: primero se configura y luego se agrega (asi _ready ya ve todo).
func _item(script: Script, kind: int, data: Dictionary) -> Node2D:
	var n := Node2D.new()
	n.set_script(script)
	n.set("kind", kind)
	n.position = ORIGIN + Vector2(float(data["x"]), float(data["y"]))
	return n


func _place_player_goal_camera(lv: Dictionary) -> void:
	var player := _scene.get_node_or_null("FV_player") as FV_player
	if player != null:
		var s: Array = lv["start"]
		player.position = ORIGIN + (Vector2(float(s[0]), float(s[1])) + Vector2(0.5, 0.5)) * CELL
		player.velocity = Vector2.ZERO
		player.can_move = true
	var cam := _scene.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.position = ORIGIN
		cam.offset = Vector2.ZERO
	var goal := _scene.get_node_or_null("Area2D") as Area2D
	var col := _scene.get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
	if goal != null and col != null:
		var g: Array = lv["goal"]
		var rect := RectangleShape2D.new()
		rect.size = Vector2(float(g[2]), float(g[3])) * CELL
		col.shape = rect
		var corner: Vector2 = ORIGIN + Vector2(float(g[0]), float(g[1])) * CELL
		col.position = corner + rect.size / 2.0 - goal.position


# ================================================================== reglas
func _process(delta: float) -> void:
	if not _playing:
		return
	_goal_msg_cooldown = maxf(_goal_msg_cooldown - delta, 0.0)
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.5
		_check_failure()
	if _tremor_timer > 0.0:
		_tremor_timer -= delta
		if _tremor_timer <= 0.0:
			var tr: Array = level["tremors"]
			_tremor_timer = randf_range(float(tr[0]), float(tr[1]))
			_tremor()


## Lo que falta para poder terminar el mapa ("" = todo listo).
func _missing() -> String:
	var req: Dictionary = level.get("require", {})
	if bool(req.get("buildings", true)):
		var n: int = 0
		for b in get_tree().get_nodes_in_group("edificios"):
			if b.get("safe_to_demolish") == true and int(b.get("state")) == 0:
				n += 1
		if n > 0:
			return "Aún faltan %d edificio(s) seguros por despejar." % n
	if bool(req.get("civilians", true)):
		var c: int = 0
		for p in get_tree().get_nodes_in_group("civiles"):
			if p.get("evacuated") == false and p.get("injured") == false:
				c += 1
		if c > 0:
			return "Aún hay %d persona(s) por poner a salvo." % c
	return ""


func _bombs_needed() -> int:
	var n: int = 0
	for b in get_tree().get_nodes_in_group("edificios"):
		if b.get("safe_to_demolish") == true and int(b.get("state")) == 0:
			n += int(b.get("floors")) - int(b.get("hits"))
	for r in get_tree().get_nodes_in_group("escombros"):
		if r.get("route") == true:
			n += 1
	return n


func _bomb_supply_left() -> bool:
	for o in get_tree().get_nodes_in_group("interactuables"):
		if int(o.get("kind")) == 2 and o.get("collected") == false and int(o.get("reward_bombs")) > 0:
			return true
	return false


func _check_failure() -> void:
	if GameManager.civilians_injured >= 2:
		_fail("Dos o más personas quedaron dentro de la zona de peligro cuando cayó un edificio. Antes de demoler, hay que evacuar.")
		return
	if GameManager.bombs <= 0 and get_tree().get_nodes_in_group("bombas").is_empty():
		if _bombs_needed() > 0 and not _bomb_supply_left():
			_fail("Te quedaste sin bombas y aún faltan %d carga(s) para despejar el camino. Planifica cada bomba." % _bombs_needed())


# ================================================================== replicas sismicas
func _tremor() -> void:
	GameManager.sfx("tremor")
	GameManager.toast("warning", "¡Réplica sísmica!", "Aléjate de los edificios dañados.")
	var cam := _scene.get_node_or_null("Camera2D") as Camera2D
	var tw := create_tween()
	for i in 56:
		var amp: float = 3.0 if i < 44 else 1.5
		tw.tween_callback(_shake.bind(cam, Vector2(randf_range(-amp, amp), randf_range(-amp, amp))))
		tw.tween_interval(0.043)
	tw.tween_callback(_shake.bind(cam, Vector2.ZERO))
	await tw.finished
	if not _playing:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for b in get_tree().get_nodes_in_group("edificios"):
		if int(b.get("state")) == 0 and float(b.call("distance_to_rect", player.global_position)) < 22.0:
			GameManager.add_score(-15, "replica sismica")
			GameManager.stat("tremor_hits")
			GameManager.toast("error", "¡Te sorprendió!", "Estabas junto a un edificio. -15 puntos")
			if player.has_method("flash_hurt"):
				player.call("flash_hurt")
			break


func _shake(cam: Camera2D, offset: Vector2) -> void:
	if cam != null:
		cam.offset = offset


# ================================================================== resumen y estrellas
func _compute_max_points(lv: Dictionary) -> int:
	var total: int = 0
	for b in lv["buildings"]:
		total += (10 + 40 * int(b["floors"])) if bool(b["safe"]) else 25
	for p in lv["people"]:
		if bool(p["evac"]):
			total += 15
	for s in lv["supplies"]:
		total += int(s["points"])
	total += 5 * lv["signs"].size() + 10 * lv["rubble"].size()
	return maxi(total, 1)


func _delta(key: String) -> int:
	return GameManager.get_stat(key) - int(_stats_start.get(key, 0))


func _feedback(delta_fn: Callable) -> Dictionary:
	var good: Array = []
	var bad: Array = []
	if delta_fn.call("eval_before") > 0 and delta_fn.call("demo_no_eval") == 0:
		good.append("Evaluaste cada edificio antes de demolerlo.")
	if delta_fn.call("civ_saved") > 0 and delta_fn.call("civ_injured") == 0:
		good.append("Pusiste a salvo a %d persona(s)." % delta_fn.call("civ_saved"))
	if delta_fn.call("unsafe_detected") > 0 and delta_fn.call("unsafe_attempts") == 0:
		good.append("Detectaste una estructura comprometida y la dejaste en pie.")
	if delta_fn.call("eval_before") > 0 and delta_fn.call("too_close") == 0 and delta_fn.call("bomb_self") == 0:
		good.append("Mantuviste distancia segura al demoler.")
	if delta_fn.call("rubble_cleared") > 0:
		good.append("Despejaste %d bloqueo(s) del camino." % delta_fn.call("rubble_cleared"))
	if delta_fn.call("supplies") > 0:
		good.append("Recuperaste %d recurso(s) de forma segura." % delta_fn.call("supplies"))
	if delta_fn.call("signs_read") > 0:
		good.append("Te informaste con las señales.")
	if delta_fn.call("demo_no_eval") > 0:
		bad.append("Demoliste %d edificio(s) sin evaluarlo." % delta_fn.call("demo_no_eval"))
	if delta_fn.call("too_close") > 0:
		bad.append("Estuviste dentro del círculo de peligro %d vez(es)." % delta_fn.call("too_close"))
	if delta_fn.call("bomb_self") > 0:
		bad.append("Te quedaste junto a una bomba %d vez(es)." % delta_fn.call("bomb_self"))
	if delta_fn.call("unsafe_attempts") > 0:
		bad.append("Intentaste demoler una estructura comprometida.")
	if delta_fn.call("civ_injured") > 0:
		bad.append("%d persona(s) quedaron en la zona de peligro." % delta_fn.call("civ_injured"))
	if delta_fn.call("zone_entries") > 0:
		bad.append("Entraste %d vez(es) a una zona restringida." % delta_fn.call("zone_entries"))
	if delta_fn.call("tremor_hits") > 0:
		bad.append("Una réplica te sorprendió junto a un edificio.")
	return {"good": good, "bad": bad}


func _penalties(delta_fn: Callable) -> int:
	var n: int = 0
	for k in ["demo_no_eval", "too_close", "bomb_self", "unsafe_attempts", "civ_injured", "zone_entries", "tremor_hits"]:
		n += int(delta_fn.call(k))
	return n


func _stars_for(ratio: float, penalties: int) -> int:
	if ratio >= 0.8 and penalties == 0:
		return 3
	if ratio >= 0.5 and penalties <= 2:
		return 2
	return 1


func _build_summary() -> Dictionary:
	var fb: Dictionary = _feedback(_delta)
	var points: int = GameManager.score - _score_start
	var stars: int = _stars_for(float(points) / float(_max_points), _penalties(_delta))
	return {
		"name": String(level["name"]), "stars": stars, "points": points, "total": GameManager.score,
		"good": fb["good"], "bad": fb["bad"], "lesson": String(level["lesson"]), "last": index >= _levels.size() - 1,
	}


func _total(key: String) -> int:
	return GameManager.get_stat(key)


func _final_summary() -> Dictionary:
	var fb: Dictionary = _feedback(_total)
	var stars_sum: int = 0
	for s in _summaries:
		stars_sum += int(s["stars"])
	var stars: int = clampi(roundi(float(stars_sum) / float(maxi(_summaries.size(), 1))), 1, 3)
	var trivia: String = "Trivia: antes %d/%d" % [GameManager.pre_correct, GameManager.total_questions]
	if GameManager.post_correct >= 0:
		trivia += "  →  después %d/%d" % [GameManager.post_correct, GameManager.total_questions]
	return {
		"stars": stars, "score": GameManager.score,
		"buildings": "%d/%d" % [_total("bld_cleared"), _total("bld_total")],
		"people": "%d/%d" % [_total("civ_saved"), _total("civ_total")],
		"trivia": trivia, "good": fb["good"], "bad": fb["bad"],
	}


# ================================================================== llegada de los equipos de emergencia
func _arrival_cutscene() -> void:
	GameManager.sfx("victory")
	GameManager.play_music("esperanza", 1.0)
	GameManager.toast("success", "¡Ruta despejada!", "Los equipos de emergencia ya pueden pasar.", "")
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		player.set("can_move", false)
	var g: Array = level["goal"]
	var end_x: float = ORIGIN.x + float(g[0]) * CELL - 30.0
	var start_x: float = maxf(end_x - 240.0, ORIGIN.x)
	var kinds: Array = ["AUTO_ROJO", "TAXI", "AUTO_ROJO"]
	for i in 3:
		var v := Vehicle.new()
		v.texture = TEXTURE
		var pieces: Array = _cars[String(kinds[i])]
		for k in 4:
			var p: Array = pieces[k]
			v.tiles.append(Vector2i(int(p[0]), int(p[1])))
		v.position = Vector2(start_x - float(i) * 44.0, ORIGIN.y + 7.0 * CELL)
		_scene.add_child(v)
		var tw := create_tween()
		tw.tween_property(v, "position:x", end_x - float(i) * 40.0, 3.0 + 0.2 * float(i)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(4.2).timeout


## Vehiculo de emergencia (2x2 casillas del tileset) con luz parpadeante.
class Vehicle extends Node2D:
	var texture: Texture2D
	var tiles: Array = []

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for i in tiles.size():
			var t: Vector2i = tiles[i]
			draw_texture_rect_region(texture, Rect2(Vector2((i % 2) * 16, (i >> 1) * 16), Vector2(16, 16)), Rect2(Vector2(t) * 16.0, Vector2(16, 16)))
		var on: bool = floori(float(Time.get_ticks_msec()) / 220.0) % 2 == 0
		draw_circle(Vector2(16, -3), 3.0, Color("ff2d2d") if on else Color("2d6bff"))
