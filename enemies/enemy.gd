extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var decision_timer: Timer = $DecisionTimer
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var shoot_cd: Timer = $shoot_cd
@onready var marker_2d: Marker2D = $Marker2D

# --- CONFIGURAÇÕES DO BOSS ---
const GRAVITY = 1000
const SPEED_RUN = 200        
const SPEED_DASH = 400       
const SPEED_DASH_ATTACK = 400 
const JUMP_FORCE = -400      
const ATTACK_RANGE = 70 
const DASH_ATTACK_RANGE = 130 
const THROW_RANGE = 400 

# --- CARREGAR A CENA DA BALA DO INIMIGO ---
const BULLET_SCENE = preload("res://enemies/enemy_shuriken.tscn") 

# Referência ao Player
var player = null

enum State { Idle, Run, Jump, Attack, Dash, Hurt, Dead, Throw }
var current_state = State.Idle

# Variáveis de controle
var is_dashing = false
var dash_duration = 0.15 
var dash_time = 0.0
var health = 200

# Sistema de Combo
var combo_stage = 0 
var is_comboing = false 

# --- Contador para variar os ataques ---
var consecutive_combos = 0 

func _ready():
	player = get_tree().get_first_node_in_group("player")
	animated_sprite.animation_finished.connect(_on_animation_finished)
	decision_timer.timeout.connect(_on_decision_timer_timeout)

func _physics_process(delta):
	# 1. Gravidade
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if current_state == State.Dead or current_state == State.Hurt:
		move_and_slide()
		return

	# 2. Lógica do Dash
	if is_dashing:
		dash_time += delta
		if dash_time >= dash_duration:
			is_dashing = false
			velocity.x = 0 
			
			if current_state == State.Dash:
				current_state = State.Idle

	# 3. Virar para o player
	if player and current_state != State.Attack and current_state != State.Hurt and current_state != State.Dash and current_state != State.Throw:
		var direction_to_player = global_position.direction_to(player.global_position).x
		if direction_to_player > 0:
			animated_sprite.flip_h = false
		else:
			animated_sprite.flip_h = true

	move_and_slide()
	enemy_animations()

# --- CÉREBRO DO BOSS ---
func _on_decision_timer_timeout():
	if current_state != State.Idle and current_state != State.Run and current_state != State.Jump:
		return
		
	if player == null: return

	var distance = global_position.distance_to(player.global_position)
	var dir_x = sign(player.global_position.x - global_position.x)
	if dir_x == 0: dir_x = 1

	# Lógica de Alternância (Combo vs Dash)
	if distance <= ATTACK_RANGE:
		
		if attack_cooldown.is_stopped():
			# Calcula a chance de Dash Attack baseada no histórico recente
			var dash_chance = 0.2 # Base: 20% de chance
			
			if consecutive_combos == 1: dash_chance = 0.5 # 50% se já fez 1 combo
			if consecutive_combos >= 2: dash_chance = 0.9 # 90% se já fez 2+ combos (Força a troca)

			if randf() < dash_chance:
				perform_dash_attack(dir_x)
				consecutive_combos = 0 # Reseta o contador ao dar Dash
			else:
				velocity.x = 0 
				start_combo()
				consecutive_combos += 1 # Aumenta o contador ao dar Combo
		else:
			current_state = State.Idle

	# DASH ATTACK
	elif distance <= DASH_ATTACK_RANGE:
		if attack_cooldown.is_stopped():
			perform_dash_attack(dir_x)
			consecutive_combos = 0 # Reseta se atacar de longe também
		else:
			current_state = State.Idle
			
	# 3. MÉDIA/LONGA DISTÂNCIA: PERSEGUIR ou THROW
	else:
		if shoot_cd.is_stopped() and distance <= THROW_RANGE and randf() < 0.4:
			perform_throw()
		elif randf() < 0.2 and is_on_floor():
			start_dash(dir_x)
		else:
			chase_player(dir_x)

func chase_player(dir):
	velocity.x = dir * SPEED_RUN
	
	if is_on_floor():
		current_state = State.Run
		if randf() < 0.05: 
			velocity.y = JUMP_FORCE
			current_state = State.Jump
	else:
		current_state = State.Jump

# --- COMBATE ---

func perform_throw():
	current_state = State.Throw
	velocity.x = 0 
	animated_sprite.play("throwe")
	spawn_bullet()
	shoot_cd.start()

func spawn_bullet():
	if BULLET_SCENE:
		var bullet = BULLET_SCENE.instantiate()
		
		if animated_sprite.flip_h:
			bullet.direction = -1 
			marker_2d.position.x = -abs(marker_2d.position.x)
		else:
			bullet.direction = 1  
			marker_2d.position.x = abs(marker_2d.position.x)
			
		get_parent().add_child(bullet)
		bullet.global_position = marker_2d.global_position

func perform_dash_attack(dir):
	current_state = State.Attack
	is_dashing = true 
	dash_time = 0
	velocity.x = dir * SPEED_DASH_ATTACK 
	animated_sprite.play("dash_attacke")
	attack_cooldown.start() 

func start_dash(dir):
	current_state = State.Dash
	is_dashing = true
	dash_time = 0
	velocity.x = dir * SPEED_DASH
	velocity.y = 0 
	animated_sprite.play("dashe")

func start_combo():
	combo_stage = 1
	is_comboing = true
	execute_attack_animation()

func execute_attack_animation():
	current_state = State.Attack
	velocity.x = 0 
	
	if combo_stage == 1:
		animated_sprite.play("attack1e")
	elif combo_stage == 2:
		animated_sprite.play("attack2e")
	elif combo_stage == 3:
		animated_sprite.play("attack3e")

func _on_animation_finished():
	if current_state == State.Throw:
		current_state = State.Idle
		return

	if current_state == State.Attack:
		if animated_sprite.animation == "dash_attacke":
			is_dashing = false
			velocity.x = 0
			current_state = State.Idle
			return

		if is_comboing:
			if animated_sprite.animation == "attack1e":
				combo_stage = 2
				if global_position.distance_to(player.global_position) < ATTACK_RANGE + 40:
					execute_attack_animation()
					return
			elif animated_sprite.animation == "attack2e":
				combo_stage = 3
				if global_position.distance_to(player.global_position) < ATTACK_RANGE + 40:
					execute_attack_animation()
					return
			elif animated_sprite.animation == "attack3e":
				is_comboing = false
				combo_stage = 0
				attack_cooldown.start(0.4) 
	
	if current_state == State.Attack or current_state == State.Hurt or current_state == State.Dash:
		is_dashing = false
		is_comboing = false
		current_state = State.Idle
		velocity.x = 0
	
	if animated_sprite.animation == "deathe":
		await get_tree().create_timer(3.0).timeout
		queue_free()

# --- DANO ---
func take_damage(amount):
	if current_state == State.Dead: return
	
	health -= amount
	var should_interrupt = randf() < 0.2
	
	if health <= 0:
		die()
	elif should_interrupt:
		current_state = State.Hurt
		is_comboing = false
		is_dashing = false
		velocity.x = 0
		animated_sprite.play("hurte")

func die():
	current_state = State.Dead
	velocity.x = 0
	animated_sprite.play("deathe")
	$CollisionShape2D.set_deferred("disabled", true)
	decision_timer.stop()
	attack_cooldown.stop()
	shoot_cd.stop()

func enemy_animations():
	if current_state == State.Run:
		animated_sprite.play("rune")
	elif current_state == State.Idle:
		animated_sprite.play("idlee")
	elif current_state == State.Jump:
		animated_sprite.play("jumpe")
	elif current_state == State.Dash:
		animated_sprite.play("dashe")
	elif current_state == State.Throw:
		if animated_sprite.animation != "throwe":
			animated_sprite.play("throwe")
