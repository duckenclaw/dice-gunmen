extends Area2D
class_name WeaponPickup

const GRID_SIZE = 60

enum WeaponType { PISTOL, SNIPER, RPG }

@export var weapon_type: WeaponType = WeaponType.PISTOL
@export var ammo: int = 0  # 0 = use default for this weapon

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("weapon")
	position = _snap_to_grid(position)
	_apply_visual()

func try_pickup(player) -> bool:
	var actual_ammo = ammo if ammo > 0 else default_ammo(weapon_type)
	player.equip_weapon(weapon_type, actual_ammo)
	queue_free()
	return true

static func default_ammo(t: int) -> int:
	match t:
		WeaponType.PISTOL: return 5
		WeaponType.SNIPER: return 2
		WeaponType.RPG: return 1
	return 0

func _apply_visual():
	if sprite == null:
		return
	match weapon_type:
		WeaponType.PISTOL:
			sprite.modulate = Color(1.0, 0.4, 0.4)
		WeaponType.SNIPER:
			sprite.modulate = Color(0.4, 0.6, 1.0)
		WeaponType.RPG:
			sprite.modulate = Color(1.0, 0.9, 0.3)

func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / GRID_SIZE) * GRID_SIZE,
		round(pos.y / GRID_SIZE) * GRID_SIZE
	)
