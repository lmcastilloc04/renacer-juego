extends CharacterBody2D

#Sonido de explosion
@onready var audioexplosion: AudioStreamPlayer2D = $Audioexplosion

#Desactivar la collision
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var health: int = 1
#Colocar una bandera para que no se ejecute muchas veces el metodo Die
var is_dead: bool = false


#Efectos visuales
@export var death_expand_scene: PackedScene
@export var death_effect_scene: PackedScene

#Items
@export var rupie_scene: PackedScene
@export var heart_scene: PackedScene




@export var speed: float = 30.0

var player: Node2D


func _ready():
	$AnimatedSprite2D.play("walk_down")

	# Buscar al jugador en la escena
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta):
	if player == null:
		return

	# Calcular dirección hacia el jugador
	var direction = global_position.direction_to(player.global_position)

	# Aplicar velocidad
	velocity = direction * speed

	# Mover al Wall Master
	move_and_slide()

	# Cambiar la animación dependiendo de la dirección
	update_animation(direction)


func update_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		# Movimiento horizontal
		if direction.x > 0:
			$AnimatedSprite2D.play("walk_right")
		else:
			$AnimatedSprite2D.play("walk_left")
	else:
		# Movimiento vertical
		if direction.y > 0:
			$AnimatedSprite2D.play("walk_down")
		else:
			$AnimatedSprite2D.play("walk_up")
			
			
	
#Recibir daño
func take_damage() -> void:
	#Colocamos la bandera
	if is_dead:
		return
	
	health -= 1
	print("Vida del Octorok: ", health)

	if health <= 0:
		die()
	
	
	
#----------------------------------
#Soltar Objeto Aleatorio
#----------------------------------
func drop_random_item() -> void:
	#Generamos un valor random
	var random_number : int = randi_range(1,100)
	
	#Creamos una variable para almacenar el item a recolectar
	var item_scene: PackedScene = null
	
	#50% no suelta nada
	#30% rupia
	#20% corazon
	
	if random_number <= 30:
		item_scene = rupie_scene
	elif random_number <= 50:
		item_scene = heart_scene
	else:
		item_scene = null
	
	#Instanciamos el item
	if item_scene != null:
		var item = item_scene.instantiate()
		
		#Hacemos que aparesca en la posicion donde murio
		item.global_position = global_position
		
		#Agregamos el item en diferido al mismo padre del este enemigo
		#get_parent().add_child(item)
		get_parent().call_deferred("add_child", item)
		
#Funcion de muerte del enemigo 
func die() -> void:
	
	is_dead = true

	set_physics_process(false)

	# Diagonal arriba-izquierda ↖
	var effect_up_left = death_expand_scene.instantiate()
	effect_up_left.global_position = global_position
	effect_up_left.direction = Vector2(-1, -1)#x(-1) y(-1)
	effect_up_left.get_node("AnimatedSprite2D").scale = Vector2(1, 1)
	get_parent().call_deferred("add_child", effect_up_left)


	# Diagonal arriba-derecha ↗
	var effect_up_right = death_expand_scene.instantiate()
	effect_up_right.global_position = global_position
	effect_up_right.direction = Vector2(1, -1)
	effect_up_right.get_node("AnimatedSprite2D").scale = Vector2(-1, 1)
	get_parent().call_deferred("add_child", effect_up_right)

	# Diagonal abajo-izquierda ↙
	var effect_down_left = death_expand_scene.instantiate()
	effect_down_left.global_position = global_position
	effect_down_left.direction = Vector2(-1, 1)
	effect_down_left.get_node("AnimatedSprite2D").scale = Vector2(1, -1)
	get_parent().call_deferred("add_child", effect_down_left)

	# Diagonal abajo-derecha ↘
	var effect_down_right = death_expand_scene.instantiate()
	effect_down_right.global_position = global_position
	effect_down_right.direction = Vector2(1, 1)
	effect_down_right.get_node("AnimatedSprite2D").scale = Vector2(-1, -1)
	get_parent().call_deferred("add_child", effect_down_right)
	
	#Creamos el efecto normal de muerte
	var effect_death  = death_effect_scene.instantiate()
	effect_death.global_position = global_position
	get_parent().call_deferred("add_child", effect_death)
	
	

	# Soltar objeto
	drop_random_item()
	
	audioexplosion.play()
	animated_sprite_2d.visible = false
	collision_shape_2d.set_deferred("disabled", true)
	audioexplosion.finished.connect(queue_free)
