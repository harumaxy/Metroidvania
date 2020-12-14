extends KinematicBody2D

export (int) var ACCELERATION = 512
export (int) var MAX_SPEED = 64
export (float) var FRICTION = 0.25
export (int) var GRAVITY = 200
export (int) var JUMP_FORCE = 128
export (int) var MAX_SLOPE_ANGLE = 46

var motion = Vector2.ZERO

onready var sprite: Sprite = $Sprite
onready var spriteAnimator: AnimationPlayer = $SpriteAnimator

# KinematicBody : Simulated movement

func get_input_vector():
  return Vector2(
    Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
    Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))

func apply_horizontal_force(input_vector: Vector2, delta: float) -> void:
  if input_vector.x != 0:
    motion.x += input_vector.x * ACCELERATION * delta
    motion.x = clamp(motion.x, -MAX_SPEED, MAX_SPEED)

func apply_friction(input_vector: Vector2) -> void:
  if input_vector.x == 0:
   self.motion.x = lerp(motion.x, 0, FRICTION)

func apply_gravity(delta: float):
# Although not on floor, run properly
#  if not self.is_on_floor():
  motion.y += GRAVITY * delta
  motion.y = min(motion.y, JUMP_FORCE)

# Long Jump & Short Jump
# long press = long jump, short press = release button during jumping = short jump
func jump_check():
  if self.is_on_floor() and Input.is_action_just_pressed("ui_up"):
    motion.y = -JUMP_FORCE
  elif Input.is_action_just_released("ui_up") and motion.y < -JUMP_FORCE / 2: # make jump speed half if up button released rapidly
    motion.y = -JUMP_FORCE / 2
      

func update_animation(input_vector: Vector2) -> void:
  if input_vector.x != 0:
    sprite.scale.x = sign(input_vector.x) # Inverse Sprite direction
    spriteAnimator.play("Run")
  else:
    spriteAnimator.play("Idle")
  if not is_on_floor():
    spriteAnimator.play("Jump")
    
func move() -> void:
 self.motion = self.move_and_slide(motion, Vector2.UP)

func _physics_process(delta: float):
  # Get the input vector
  var input_vector = get_input_vector()
  # Apply the acceleration
  apply_horizontal_force(input_vector, delta)
  apply_friction(input_vector)
  jump_check()
  apply_gravity(delta)
  move()
  update_animation(input_vector)

