extends Sprite2D

# Cosmetic-only shot effect. Damage is applied instantly by the shooter;
# this sprite just flies from the muzzle to the impact point and frees itself.

const SPEED = 1800.0
const TARGET_SPRITE_PX = 24.0
const THROW_TARGET_SPRITE_PX = 40.0
const THROW_ARC_SCALE = 1.6

static func spawn(parent: Node, tex: Texture2D, from: Vector2, to: Vector2) -> void:
	var p = load("res://src/projectile.gd").new()
	p.texture = tex
	p.position = from
	p.rotation = (to - from).angle()
	p._fit_to(tex, TARGET_SPRITE_PX)
	parent.add_child(p)

	var duration = max(from.distance_to(to) / SPEED, 0.05)
	var tween = p.create_tween()
	tween.tween_property(p, "position", to, duration)
	tween.tween_callback(p.queue_free)

# Lobbed variant for thrown weapons: spins and scales up then back down to
# fake an arc.
static func spawn_thrown(parent: Node, tex: Texture2D, from: Vector2, to: Vector2) -> void:
	var p = load("res://src/projectile.gd").new()
	p.texture = tex
	p.position = from
	p._fit_to(tex, THROW_TARGET_SPRITE_PX)
	parent.add_child(p)

	var base_scale = p.scale
	var duration = max(from.distance_to(to) / SPEED, 0.2)
	var tween = p.create_tween()
	tween.tween_property(p, "position", to, duration)
	tween.parallel().tween_property(p, "rotation", TAU, duration)
	tween.parallel().tween_property(p, "scale", base_scale * THROW_ARC_SCALE, duration * 0.5)
	tween.parallel().tween_property(p, "scale", base_scale, duration * 0.5).set_delay(duration * 0.5)
	tween.tween_callback(p.queue_free)

func _fit_to(tex: Texture2D, target_px: float) -> void:
	var size = tex.get_size()
	var longest = max(size.x, size.y)
	if longest > 0:
		var s = target_px / longest
		scale = Vector2(s, s)
