class_name Bomb
extends Node2D
## Bomba ficticia de demolicion controlada. La coloca el jugador (tecla E).
## Explota a los FUSE_TIME segundos y afecta lo que este dentro de BLAST_RADIUS:
##   - los edificios cercanos reciben una carga (ver building.gd)
##   - los escombros cercanos se retiran (ver rubble.gd)
##   - si el jugador esta pegado a la bomba, pierde puntos
## Se dibuja por codigo (no usa imagenes).

const FUSE_TIME: float = 2.5
const BLAST_RADIUS: float = 36.0

var _exploded: bool = false
var _radius: float = 0.0
var _alpha: float = 0.0
var _age: float = 0.0


func _ready() -> void:
	z_index = 40
	add_to_group("bombas")
	get_tree().create_timer(FUSE_TIME).timeout.connect(_explode)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _explode() -> void:
	if _exploded or not is_inside_tree():
		return
	_exploded = true
	remove_from_group("bombas")
	GameManager.sfx("explosion", 0.0, randf_range(0.94, 1.06))
	_apply_damage()

	# Animacion: circulo que crece y se desvanece
	_alpha = 0.85
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_radius", BLAST_RADIUS, 0.25)
	tw.tween_property(self, "_alpha", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)


func _apply_damage() -> void:
	for group in ["edificios", "escombros"]:
		for b in get_tree().get_nodes_in_group(group):
			if b.has_method("distance_to_rect") and b.has_method("receive_blast"):
				if float(b.call("distance_to_rect", global_position)) <= BLAST_RADIUS:
					b.call("receive_blast")

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(global_position) <= BLAST_RADIUS * 0.8:
		GameManager.add_score(-20, "junto a la bomba")
		GameManager.stat("bomb_self")
		GameManager.toast("error", "¡Junto a la bomba!", "Debiste alejarte. -20 puntos")
		if player.has_method("flash_hurt"):
			player.call("flash_hurt")


func _draw() -> void:
	if _exploded:
		draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.55, 0.1, _alpha))
		draw_circle(Vector2.ZERO, _radius * 0.55, Color(1.0, 0.9, 0.4, _alpha))
		return
	# Bomba: cuerpo oscuro, brillo, mecha y chispa que parpadea cada vez mas rapido
	var fast: float = 6.0 + 14.0 * (_age / FUSE_TIME)
	var flash: bool = sin(_age * fast * 2.0) > 0.0
	draw_circle(Vector2(0, -5), 5.0, Color("1f1b2e") if not flash else Color("5a1f2a"))
	draw_arc(Vector2(0, -5), 5.0, 0.0, TAU, 16, Color("0d0a18"), 1.0)
	draw_circle(Vector2(-1.8, -7.0), 1.3, Color(1, 1, 1, 0.55))
	draw_line(Vector2(2, -9), Vector2(4, -12), Color("b08968"), 1.5)
	draw_circle(Vector2(4.5, -12.5), 1.8 if flash else 1.2, Color("ffd166") if flash else Color("ff7b00"))
