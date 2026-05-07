extends Node

# Tracks spawn/life tickets for both sides in a battle.
# Placed in the scene by WorldGenerator; found via group "battle_tracker".

const MAX_TICKETS := 10

var enemy_tickets: int = MAX_TICKETS
var player_tickets: int = MAX_TICKETS

func use_enemy_ticket() -> bool:
	if enemy_tickets <= 0:
		return false
	enemy_tickets -= 1
	return true

func use_player_ticket() -> bool:
	if player_tickets <= 0:
		return false
	player_tickets -= 1
	return true
