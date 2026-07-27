extends Node2D
## Auto-connecting canal segment for the Ancient Egypt flood quest.
##
## A placed canal looks at which of its 4 neighbours also hold a canal (the
## connection mask) and shows the matching sprite from a 16-tile pixel-art
## sheet. Because each tile extends a stone-lined water arm toward every
## connected neighbour, adjacent pieces line up into one seamless waterway
## instead of disconnected blocks.
##
## Sheet layout: 4x4 grid of 16x16 tiles, indexed by the 4-bit mask
## N=1 E=2 S=4 W=8 (assets/generated/canal/canal_tiles.png).

const N := 1
const E := 2
const S := 4
const W := 8
const SHEET_TILE := 16

@export var tile_position := Vector2i.ZERO
@export var tile_size: float = 16.0

var connection_mask: int = 0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply()


func set_connections(mask: int) -> void:
	connection_mask = mask
	_apply()


func _apply() -> void:
	if sprite == null:
		return
	var idx := connection_mask & 15
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.region_rect = Rect2((idx % 4) * SHEET_TILE, (idx / 4) * SHEET_TILE, SHEET_TILE, SHEET_TILE)
	# Scale the 16px art to the world tile size (usually 1:1 at 16px tiles).
	var s := tile_size / float(SHEET_TILE)
	sprite.scale = Vector2(s, s)
