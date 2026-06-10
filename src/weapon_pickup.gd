extends Area2D
class_name WeaponPickup

const GRID_SIZE = 60

enum WeaponType { PISTOL, SNIPER, RPG, MOLOTOV, GRENADE }

const TARGET_SPRITE_PX = 50.0

@export var weapon_type: WeaponType = WeaponType.PISTOL
@export var ammo: int = 0  # 0 = use default for this weapon

@export var pistol_texture: Texture2D
@export var sniper_texture: Texture2D
@export var rpg_texture: Texture2D
@export var molotov_texture: Texture2D
@export var grenade_texture: Texture2D

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
		WeaponType.MOLOTOV: return 1
		WeaponType.GRENADE: return 1
	return 0

func _apply_visual():
	if sprite == null:
		return
	var tex: Texture2D = null
	match weapon_type:
		WeaponType.PISTOL: tex = pistol_texture
		WeaponType.SNIPER: tex = sniper_texture
		WeaponType.RPG: tex = rpg_texture
		WeaponType.MOLOTOV: tex = molotov_texture
		WeaponType.GRENADE: tex = grenade_texture
	if tex == null:
		return
	sprite.texture = tex
	var size = tex.get_size()
	var longest = max(size.x, size.y)
	if longest > 0:
		var s = TARGET_SPRITE_PX / longest
		sprite.scale = Vector2(s, s)

func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / GRID_SIZE) * GRID_SIZE,
		round(pos.y / GRID_SIZE) * GRID_SIZE
	)
