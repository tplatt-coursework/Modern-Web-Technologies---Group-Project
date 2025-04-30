extends CharacterBody2D



#for space jump
#const SPEED = 300.0
const JUMP_HEIGHT = 17.5
const MOVE_DISTANCE = 17.5
const MAX_MOVE_MULTIPLIER = 10
const MAX_JUMP_MULTIPLIER = 10
#
#
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	if velocity.x != 0:
		velocity.x *= 0.965
		if abs(velocity.x) < 1:
			velocity.x = 0

	# Handle jump.
	#if Input.is_action_just_pressed("up") and is_on_floor():
		#velocity.y = JUMP_VELOCITY
#
	# was the below stuff ai generated or from docs?
	## Get the input direction and handle the movement/deceleration.
	## As good practice, you should replace UI actions with custom gameplay actions.
	#var direction := Input.get_axis("left", "right")
	#if direction:
		#velocity.x = direction * SPEED
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)
#
	move_and_slide()

# Naming convention: PC_ for Player Controller
func PC_left(x):
	if x < 0:
		velocity.x = -sqrt(2*500*(MOVE_DISTANCE))
	else: 
		velocity.x = -min(sqrt(2*500*(x*MOVE_DISTANCE)),sqrt(2*500*(MAX_MOVE_MULTIPLIER*MOVE_DISTANCE)))
	print("main/GameBox/Player: Moved Left, v="+str(velocity.x))

func PC_right(x):
	if x < 0:
		velocity.x = sqrt(2*500*(MOVE_DISTANCE))
	else: 
		velocity.x = min(sqrt(2*500*(x*MOVE_DISTANCE)),sqrt(2*500*(MAX_MOVE_MULTIPLIER*MOVE_DISTANCE)))
	print("main/GameBox/Player: Moved Right, v="+str(velocity.x))

func PC_jump(x):
	if is_on_floor():
		if x < 0:
			velocity.y = -sqrt(2*2000*(JUMP_HEIGHT))
		else: 
			velocity.y = -min(sqrt(2*2000*(x*JUMP_HEIGHT)),sqrt(2*2000*(JUMP_HEIGHT * MAX_JUMP_MULTIPLIER)))
		print("main/GameBox/Player: Jumped, v="+str(velocity.y))
	else:
		print("main/GameBox/Player: Jumped while in air")
