class_name FV_player
extends CharacterBody2D

@export var speed := 60.0
var can_move : bool = true

var is_attacking : bool = false 
# Direccion hacia donde esta mirando Link
var facing_direction := Vector2.DOWN
@onready var sword_hitbox: Area2D = $SwordHitbox

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

#Lanzamiento de la espada
@export var sword_magic_scene: PackedScene
#Controlar el casteo con varaible
var can_cast_sword: bool = true


func _ready() -> void:
	add_to_group("player")
	sword_hitbox.monitoring = false

func _physics_process(delta: float) -> void:
	
	if not can_move:
		velocity = Vector2.ZERO
		return
		
		#Atacar
	if Input.is_action_just_pressed("ATAQUE"):
		attack()
	
	if is_attacking:
		return
	
	var direction := Input.get_vector(
		"IZQUIERDA",
		"DERECHA",
		"ARRIBA",
		"ABAJO"
		)
		
	velocity = direction * speed
	
	# Aplicar Animaciones al personaje
	if direction == Vector2.ZERO:
		if facing_direction == Vector2.DOWN:
			animated_sprite_2d.play("walk_down")
		elif facing_direction == Vector2.UP:
			animated_sprite_2d.play("walk_up")
		elif  facing_direction == Vector2.RIGHT:
			animated_sprite_2d.play("walk_right")
		elif facing_direction == Vector2.LEFT:
			animated_sprite_2d.play("walk_left")
		animated_sprite_2d.pause()
		return
		
	if direction.x > 0:
		facing_direction = Vector2.RIGHT
		animated_sprite_2d.play("walk_right")
		
	elif direction.x < 0:
		facing_direction = Vector2.LEFT
		animated_sprite_2d.play("walk_left")
		
	elif direction.y > 0:
		facing_direction = Vector2.DOWN
		animated_sprite_2d.play("walk_down")
		
	elif direction.y < 0:
		facing_direction = Vector2.UP
		animated_sprite_2d.play("walk_up")
		
	move_and_slide()
		
func move_screen_transition(direction: Vector2, distance: float) -> void:
	
	can_move = false
	
	# Animación durante la transición
	if direction.x > 0:
		animated_sprite_2d.play("walk_right")

	elif direction.x < 0:
		animated_sprite_2d.play("walk_left")

	elif direction.y > 0:
		animated_sprite_2d.play("walk_down")

	elif direction.y < 0:
		animated_sprite_2d.play("walk_up")


	var tween = create_tween()
	tween.tween_property(self, "position", position + direction * distance, 0.5)
	await  tween.finished
	
func attack() -> void:
	is_attacking = true
	#Ya tenemos guardado la direccion hacia donde mira el jugador y hacia esa
	#direccion ejecutamos la animacion correspondiente.
	if facing_direction == Vector2.RIGHT:
		sword_hitbox.position = Vector2(14,0)
		animated_sprite_2d.play("Sword_Right")
	
	elif facing_direction == Vector2.LEFT:
		sword_hitbox.position = Vector2(-14,0)
		animated_sprite_2d.play("Sword_Left")
		
	elif  facing_direction == Vector2.UP:
		sword_hitbox.position = Vector2(0,-14)
		animated_sprite_2d.play("Sword_Up")
	
	elif facing_direction == Vector2.DOWN:
		sword_hitbox.position = Vector2(0,14)
		animated_sprite_2d.play("Sword_Down")
		
	sword_hitbox.monitoring = true
	
	#Lanzar espada magica
	cast_sword()
	
	await animated_sprite_2d.animation_finished
	sword_hitbox.monitoring = false
	
	
	
	is_attacking = false
	print(is_attacking)

func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	print("Area Detectada" + area.name)
	var enemy = area.get_parent()
	
	print("Padre: ", enemy.name)
	print("Pertece al grupo: ", area.get_parent().get_groups())
	
	if enemy.is_in_group("ENEMIES"):
		enemy.take_damage()
	
func cast_sword()-> void:
	
	if not can_cast_sword:
		return
		
	can_cast_sword = false
	
	var swordMagic : FV_swordMagic_scene = sword_magic_scene.instantiate()
	
	get_parent().add_child(swordMagic)
	
	swordMagic.global_position = global_position
	swordMagic.direction = facing_direction
	swordMagic.rotation = facing_direction.angle() + PI / 2
	
	await  get_tree().create_timer(1.0).timeout
	
	can_cast_sword = true


# ======================================================================
#  Renacer: bombas y evaluacion de edificios
#    E = colocar bomba      F = evaluar el edificio mas cercano
# ======================================================================
const BOMB_SCENE_PATH: String = "res://Scripts/Game/bomb.tscn"
const EVALUATE_DISTANCE: float = 56.0


func _unhandled_input(event: InputEvent) -> void:
	if not can_move or is_attacking:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = (event as InputEventKey).physical_keycode
		if key == KEY_E:
			place_bomb()
		elif key == KEY_F:
			evaluate_nearby()


func place_bomb() -> void:
	var scene := load(BOMB_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("No encuentro la escena de la bomba: " + BOMB_SCENE_PATH)
		return
	if not GameManager.use_bomb():
		GameManager.say("¡Ya no te quedan bombas!", Color("ef476f"))
		return
	var bomb := scene.instantiate() as Node2D
	get_parent().add_child(bomb)
	bomb.global_position = global_position + facing_direction * 12.0


func evaluate_nearby() -> void:
	var target: Node = GameManager.find_target(global_position)
	if target != null:
		target.call("interact")
	else:
		GameManager.toast("info", "Nada cerca", "Acércate a un edificio, una persona o un objeto y presiona F.")

## Parpadeo rojo cuando el jugador pierde puntos por imprudencia.
func flash_hurt() -> void:
	var tw := create_tween()
	tw.tween_property(animated_sprite_2d, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	tw.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.25)
