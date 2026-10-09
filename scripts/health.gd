extends Node
class_name Health

## Reusable health component. Attach as a child of anything that can be hurt.

signal damaged(amount: float, current: float, maximum: float)
signal healed(amount: float, current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var current_health: float = 0.0
var is_dead: bool = false
## Worn armour: absorbs `armor_fraction` of incoming damage until depleted.
var armor_points: float = 0.0
var armor_fraction: float = 0.0

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var final := amount
	if armor_points > 0.0 and armor_fraction > 0.0:
		var absorbed := minf(amount * armor_fraction, armor_points)
		armor_points -= absorbed
		final = amount - absorbed
	current_health = clampf(current_health - final, 0.0, max_health)
	damaged.emit(amount, current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = clampf(current_health + amount, 0.0, max_health)
	healed.emit(amount, current_health, max_health)

func reset() -> void:
	current_health = max_health
	is_dead = false

func get_fraction() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0
