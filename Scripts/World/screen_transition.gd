class_name Screen_Transition
extends Node2D
## Transicion de pantalla estilo Zelda: cuando el jugador toca un borde de la
## camara, el jugador da un pasito y la camara se desplaza una pantalla.
## Este nodo es hijo de Camera2D, y el jugador (FV_player) es hijo de Scene_Game.

const SCREEN_W: float = 256.0
const SCREEN_H: float = 176.0

@onready var camera_2d: Camera2D = $".."
@onready var player: FV_player = $"../../FV_player"

@onready var area_2d_up: Area2D = $Area2D_UP
@onready var area_2d_down: Area2D = $Area2D_DOWN
@onready var area_2d_left: Area2D = $Area2D_LEFT
@onready var area_2d_right: Area2D = $Area2D_RIGHT

var moving_camera: bool = false


func disable_borders() -> void:
	area_2d_up.set_deferred("monitoring", false)
	area_2d_down.set_deferred("monitoring", false)
	area_2d_left.set_deferred("monitoring", false)
	area_2d_right.set_deferred("monitoring", false)


func enable_borders() -> void:
	area_2d_up.set_deferred("monitoring", true)
	area_2d_down.set_deferred("monitoring", true)
	area_2d_left.set_deferred("monitoring", true)
	area_2d_right.set_deferred("monitoring", true)


func _transition(body: Node2D, direction: Vector2) -> void:
	# Solo reacciona al jugador y evita transiciones simultaneas
	if not body.is_in_group("player") or moving_camera:
		return
	moving_camera = true
	disable_borders()

	# El jugador avanza un poco hacia el nuevo cuarto
	await player.move_screen_transition(direction, 20)

	# Desplazar la camara una pantalla completa
	var offset := Vector2(direction.x * SCREEN_W, direction.y * SCREEN_H)
	var tween := create_tween()
	tween.tween_property(camera_2d, "position", camera_2d.position + offset, 0.8)
	await tween.finished

	enable_borders()
	moving_camera = false
	player.can_move = true


func _on_area_2d_up_body_entered(body: Node2D) -> void:
	_transition(body, Vector2.UP)


func _on_area_2d_down_body_entered(body: Node2D) -> void:
	_transition(body, Vector2.DOWN)


func _on_area_2d_left_body_entered(body: Node2D) -> void:
	_transition(body, Vector2.LEFT)


func _on_area_2d_right_body_entered(body: Node2D) -> void:
	_transition(body, Vector2.RIGHT)
