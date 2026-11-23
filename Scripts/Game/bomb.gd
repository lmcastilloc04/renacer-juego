class_name Bomb
extends Node2D
## Bomba ficticia de demolicion controlada. La coloca el jugador (tecla E).
## Explota a los FUSE_TIME segundos y afecta lo que este dentro de BLAST_RADIUS:
##   - los edificios cercanos reciben una carga (ver building.gd)
##   - si el jugador esta pegado a la bomba, pierde puntos

const FUSE_TIME: float = 2.5
const BLAST_RADIUS: float = 36.0
const BOMB_TEXTURE: Texture2D = preload("res://PackPlayerOctorok/01_Items/Bomb.png")

var _exploded: bool = false
var _radius: float = 0.0
var _alpha: float = 0.0
var _sprite: Sprite2D


func _ready() -> void:
	z_index = 40
	_sprite = Sprite2D.new()
	_sprite.texture = BOMB_TEXTURE
	add_child(_sprite)

	# Parpadeo mientras se consume la mecha
	var blink := create_tween().set_loops()
	blink.tween_property(_sprite, "modulate", Color(1.0, 0.35, 0.35), 0.25)
	blink.tween_property(_sprite, "modulate", Color.WHITE, 0.25)

	get_tree().create_timer(FUSE_TIME).timeout.connect(_explode)


func _process(_delta: float) -> void:
	if _exploded:
		queue_redraw()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_sprite.visible = false

	GameManager.sfx("explosion", 0.0, randf_range(0.94, 1.06))

	_apply_damage()

	# Animacion: circulo que crece y se desvanece
	_alpha = 0.85
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_radius", BLAST_RADIUS, 0.25)
	tw.tween_property(self, "_alpha", 0.0, 0.35)
	tw.chain().tween_callback(_finish)


func _apply_damage() -> void:
	for b in get_tree().get_nodes_in_group("edificios"):
		if b.has_method("distance_to_rect") and b.has_method("receive_blast"):
			if b.call("distance_to_rect", global_position) <= BLAST_RADIUS:
				b.call("receive_blast")

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(global_position) <= BLAST_RADIUS * 0.8:
		GameManager.add_score(-20, "junto a la bomba")
		GameManager.say("¡Estabas pegado a la bomba! -20", Color("ef476f"))
		if player.has_method("flash_hurt"):
			player.call("flash_hurt")


func _finish() -> void:
	queue_free()


func _draw() -> void:
	if not _exploded:
		return
	draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.55, 0.1, _alpha))
	draw_circle(Vector2.ZERO, _radius * 0.55, Color(1.0, 0.9, 0.4, _alpha))
