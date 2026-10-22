class_name ArtLib
extends RefCounted

## Painted art is optional. Every texture is looked up by name in res://assets/art/<name>.png
## (or .webp / .jpg — big room paintings are kept as .jpg/.webp to keep the repo small);
## when a file is missing the game falls back to its built-in shape drawing, so new art can be
## dropped into that folder later without touching code.

const ART_DIR := "res://assets/art/"
static var _cache: Dictionary = {}

static func path_for(art_name: String) -> String:
	return ART_DIR + art_name + ".png"

static func has(art_name: String) -> bool:
	return tex(art_name) != null

const EXTENSIONS: Array[String] = [".png", ".webp", ".jpg"]

static func tex(art_name: String) -> Texture2D:
	if _cache.has(art_name):
		return _cache[art_name]
	var t: Texture2D = null
	for ext in EXTENSIONS:
		var p: String = ART_DIR + art_name + ext
		if ResourceLoader.exists(p):
			t = load(p) as Texture2D
			break
	_cache[art_name] = t
	return t

static func forget(art_name: String) -> void:
	_cache.erase(art_name)

static func clear_cache() -> void:
	_cache.clear()

## Rect that covers `area` with a texture of size tex_size (like CSS background-size: cover), centred.
static func cover_rect(tex_size: Vector2, area: Rect2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return area
	var sc: float = maxf(area.size.x / tex_size.x, area.size.y / tex_size.y)
	var sz: Vector2 = tex_size * sc
	return Rect2(area.position + (area.size - sz) * 0.5, sz)

## Rect that fits inside `area` keeping aspect, centred.
static func fit_rect(tex_size: Vector2, area: Rect2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return area
	var sc: float = minf(area.size.x / tex_size.x, area.size.y / tex_size.y)
	var sz: Vector2 = tex_size * sc
	return Rect2(area.position + (area.size - sz) * 0.5, sz)

## Opaque bounds of a texture (for feet baselines etc.). Falls back to the full texture.
static func used_rect(t: Texture2D) -> Rect2:
	if t == null:
		return Rect2()
	var full := Rect2(Vector2.ZERO, t.get_size())
	var img: Image = t.get_image()
	if img == null:
		return full
	if img.is_compressed():
		if img.decompress() != OK:
			return full
	var used: Rect2i = img.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return full
	return Rect2(used)
