extends Node

# Global game state that persists across scene changes
var has_seen_farm_intro = false
var planted_seeds = {}  # Dictionary to track planted seeds by tile position across scenes
var player_points = 0  # Track player's total points
var game_time_remaining = 30 * 60  # Game timer in seconds (60 minutes)
var game_timer_started = false
var selected_inventory_slot: int = 0


# Farming bonuses
var growth_speed_multiplier: float = 1.0
var synergy_bonus_multiplier: float = 1.0
var farming_efficiency: float = 1.0

func reset_bonuses():
	growth_speed_multiplier = 1.0
	synergy_bonus_multiplier = 1.0
	farming_efficiency = 1.0
