extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const GRAVITY = 1000
const SPEED = 200
const JUMP = -250
const JUMP_HORIZONTAL = 100

# Configurações de Dash
const DASH_SPEED = 300
const DASH_ATTACK_SPEED = 200
const DASH_DURATION = 0.2

enum State { Idle, Run, Jump, Attack, Dash, Guard }
var current_state = State.Idle

# Combo normal (U)
var attack_stage = 0
var queued_attack = false

# Strong attack (I)
var strong_attack = false

# Dash attack (O)
var dash_attack = false

# Dash
var is_dashing = false
var dash_time = 0.0
var dash_direction = 0

# Guard
var is_guarding = false

var last_animation = ""

func _ready():
	animated_sprite_2d.connect("animation_finished", Callable(self, "_on_animation_finished"))

func _physics_process(delta):
	player_gravity(delta)
	player_move(delta)
	player_jump(delta)
	player_dash(delta)

	move_and_slide()

	player_attack()
	player_state()
	player_animations()

func player_gravity(delta):
	if !is_on_floor():
		velocity.y += GRAVITY * delta

func player_move(_delta):
	if is_dashing:
		# LÓGICA NOVA: Escolhe a velocidade com base no tipo de dash
		var current_speed = DASH_SPEED
		if dash_attack:
			current_speed = DASH_ATTACK_SPEED
			
		velocity.x = dash_direction * current_speed
		return

	var direction = Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED

	if direction != 0:
		animated_sprite_2d.flip_h = direction < 0

func player_jump(delta):
	if is_dashing or is_guarding:
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP

	if !is_on_floor():
		var direction = Input.get_axis("move_left", "move_right")
		velocity.x += direction * JUMP_HORIZONTAL * delta

func player_dash(delta):
	if !is_dashing:
		return

	dash_time += delta
	# Se for dash attack, a animação que controla o fim, mas mantemos isso pro dash normal
	if dash_time >= DASH_DURATION and !dash_attack:
		is_dashing = false

func player_attack():
	# Se estiver dando dash NORMAL, não ataca. Se for dash attack, deixa passar.
	if is_dashing and !dash_attack:
		return
	
	if is_guarding:
		return

	# COMBO NORMAL
	if Input.is_action_just_pressed("attack_1"):
		if current_state != State.Attack:
			attack_stage = 1
			current_state = State.Attack
			queued_attack = false
		else:
			if attack_stage < 3:
				queued_attack = true

	# STRONG ATTACK
	if Input.is_action_just_pressed("attack_strong") and current_state != State.Attack:
		strong_attack = true
		current_state = State.Attack
	
	# DASH ATTACK
	if Input.is_action_just_pressed("dash_attack") and current_state != State.Attack:
		dash_attack = true
		current_state = State.Attack
		
		# Inicia o dash junto com o ataque
		is_dashing = true
		dash_time = 0

		dash_direction = Input.get_axis("move_left", "move_right")
		if dash_direction == 0:
			dash_direction = -1 if animated_sprite_2d.flip_h else 1
		
	# DASH COMUM
	if Input.is_action_just_pressed("dash") and current_state != State.Attack:
		is_dashing = true
		dash_time = 0

		dash_direction = Input.get_axis("move_left", "move_right")
		if dash_direction == 0:
			dash_direction = -1 if animated_sprite_2d.flip_h else 1

func player_state():
	# Impede que o estado "Dash" sobrescreva o estado "Attack" durante o dash attack
	if is_dashing and !dash_attack:
		current_state = State.Dash
		return

	# DEFESA
	if Input.is_action_pressed("guard"):
		is_guarding = true
		current_state = State.Guard
		return
	else:
		is_guarding = false

	if current_state == State.Attack:
		return

	if !is_on_floor():
		current_state = State.Jump
	else:
		var direction = Input.get_axis("move_left", "move_right")
		if direction != 0:
			current_state = State.Run
		else:
			current_state = State.Idle

func player_animations():
	if current_state == State.Idle:
		animated_sprite_2d.play("idle")
		last_animation = "idle"

	elif current_state == State.Run:
		animated_sprite_2d.play("run")
		last_animation = "run"

	elif current_state == State.Jump:
		animated_sprite_2d.play("jump")
		last_animation = "jump"

	elif current_state == State.Dash:
		if last_animation != "dash":
			animated_sprite_2d.play("dash")
			last_animation = "dash"

	elif current_state == State.Guard:
		if last_animation != "guard":
			animated_sprite_2d.play("guard")
			last_animation = "guard"

	elif current_state == State.Attack:
		if strong_attack:
			if last_animation != "strong_attack":
				animated_sprite_2d.play("strong_attack")
				last_animation = "strong_attack"
			return

		if dash_attack:
			if last_animation != "dash_attack":
				animated_sprite_2d.play("dash_attack", 1.5)
				last_animation = "dash_attack"
			return

		var anim = "attack_" + str(attack_stage)
		if last_animation != anim:
			animated_sprite_2d.play(anim)
			last_animation = anim

func _on_animation_finished():
	if current_state == State.Dash:
		is_dashing = false
		current_state = State.Idle
		return

	if current_state != State.Attack:
		return

	if strong_attack:
		strong_attack = false
		current_state = State.Idle
		return

	if dash_attack:
		dash_attack = false
		is_dashing = false # Para o movimento quando o golpe acaba
		current_state = State.Idle
		return

	if queued_attack:
		attack_stage += 1
		queued_attack = false
		return

	attack_stage = 0
	current_state = State.Idle
