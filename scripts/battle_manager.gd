extends Node

# Battle scoring constants
const PERFECT_MATCH_SCORE = 50
const GOOD_MATCH_SCORE = 30
const NEUTRAL_MATCH_SCORE = 10
const BAD_MATCH_SCORE = -10
const SURVIVAL_BONUS = 20

# Calculate battle score
func calculate_battle_score(immune_team: Array, pathogens: Array) -> Dictionary:
	var total_score = 0
	var matchup_details = []
	var perfect_matches = 0
	var good_matches = 0
	var bad_matches = 0
	
	# Evaluate each pathogen
	for pathogen in pathogens:
		var best_counter = find_best_counter(pathogen, immune_team)
		
		if best_counter:
			var matchup = evaluate_matchup(best_counter, pathogen)
			total_score += matchup.score
			matchup_details.append(matchup)
			
			if matchup.rating == "Perfect":
				perfect_matches += 1
			elif matchup.rating == "Good":
				good_matches += 1
			elif matchup.rating == "Bad":
				bad_matches += 1
	
	# Calculate star rating (out of 5)
	var stars = calculate_stars(total_score, perfect_matches, pathogens.size())
	
	return {
		"total_score": total_score,
		"stars": stars,
		"perfect_matches": perfect_matches,
		"good_matches": good_matches,
		"bad_matches": bad_matches,
		"matchup_details": matchup_details,
		"max_possible_score": pathogens.size() * (PERFECT_MATCH_SCORE + SURVIVAL_BONUS)
	}

func find_best_counter(pathogen: Dictionary, immune_team: Array) -> Dictionary:
	var best_cell = null
	var best_score = -999
	
	for cell in immune_team:
		var score = evaluate_matchup(cell, pathogen).score
		if score > best_score:
			best_score = score
			best_cell = cell
	
	return best_cell

func evaluate_matchup(immune_cell: Dictionary, pathogen: Dictionary) -> Dictionary:
	var score = 0
	var rating = "Neutral"
	var reason = ""
	
	# Check if immune cell is the pathogen's weakness (PERFECT!)
	if pathogen.weakness == immune_cell.name:
		score += PERFECT_MATCH_SCORE
		rating = "Perfect"
		reason = immune_cell.name + " is " + pathogen.name + "'s weakness!"
	
	# Check if immune cell is strong against pathogen type
	elif immune_cell.strong_against == pathogen.type:
		score += GOOD_MATCH_SCORE
		rating = "Good"
		reason = immune_cell.name + " is effective vs " + pathogen.type
	
	# Check if pathogen resists this immune cell
	elif pathogen.resistance == immune_cell.name:
		score += BAD_MATCH_SCORE
		rating = "Bad"
		reason = pathogen.name + " resists " + immune_cell.name
	
	# Neutral matchup
	else:
		score += NEUTRAL_MATCH_SCORE
		rating = "Neutral"
		reason = "Standard matchup"
	
	# Survival bonus - can the cell survive the pathogen's attack?
	if immune_cell.hp > pathogen.attack:
		score += SURVIVAL_BONUS
		reason += " + Survives attack!"
	
	return {
		"immune_cell": immune_cell.name,
		"pathogen": pathogen.name,
		"score": score,
		"rating": rating,
		"reason": reason
	}

func calculate_stars(score: int, perfect_matches: int, total_pathogens: int) -> int:
	# 5 stars: Perfect team (all perfect matches)
	if perfect_matches == total_pathogens:
		return 5
	
	# 4 stars: Excellent (80%+ of max score)
	var max_score = total_pathogens * (PERFECT_MATCH_SCORE + SURVIVAL_BONUS)
	if score >= max_score * 0.8:
		return 4
	
	# 3 stars: Good (60%+)
	if score >= max_score * 0.6:
		return 3
	
	# 2 stars: Okay (40%+)
	if score >= max_score * 0.4:
		return 2
	
	# 1 star: Poor (positive score)
	if score > 0:
		return 1
	
	# 0 stars: Failed
	return 0
