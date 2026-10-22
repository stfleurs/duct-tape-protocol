extends Node

func calculate_repair_score(
	base_score: int,
	elapsed_repair_sec: float,
	target_duration_sec: float,
	was_escalated: bool,
	wrong_tool_attempts: int
) -> Dictionary:
	var safe_target: float = maxf(0.5, target_duration_sec)
	var speed_ratio: float = clampf(safe_target / maxf(0.4, elapsed_repair_sec), 0.5, 1.75)
	var speed_bonus: int = 0
	var callout: String = "GOOD!"

	if elapsed_repair_sec <= safe_target * 0.85:
		speed_bonus = int(round(base_score * 0.4))
		callout = "GREAT!"
	elif elapsed_repair_sec <= safe_target * 1.25:
		speed_bonus = int(round(base_score * 0.15))
		callout = "GREAT!"
	else:
		callout = "PATCHED!"

	var tool_efficiency_bonus: int = 40 if wrong_tool_attempts == 0 else maxi(0, 20 - wrong_tool_attempts * 10)
	var escalation_penalty: int = 25 if was_escalated else 0
	var total_points: int = maxi(50, base_score + speed_bonus + tool_efficiency_bonus - escalation_penalty)

	return {
		"points": total_points,
		"speed_bonus": speed_bonus,
		"tool_efficiency_bonus": tool_efficiency_bonus,
		"speed_ratio": speed_ratio,
		"callout": callout
	}

func calculate_shift_results(
	survived: bool,
	remaining_health: float,
	max_health: float,
	repair_score: int,
	repairs_completed: int,
	level_data: LevelData = null
) -> Dictionary:
	var two_star_pct: float = 45.0
	var three_star_pct: float = 75.0
	var three_star_min_score: int = 900
	var base_scrap: int = 75
	var scrap_per_star: int = 15

	if level_data != null:
		two_star_pct = level_data.two_star_health_threshold
		three_star_pct = level_data.three_star_health_threshold
		three_star_min_score = level_data.three_star_min_score
		base_scrap = level_data.base_scrap_reward
		scrap_per_star = level_data.scrap_per_star

	var health_pct: float = clampf((remaining_health / maxf(1.0, max_health)) * 100.0, 0.0, 100.0)
	var survival_bonus: int = int(round(health_pct * 5.0)) if survived else 0
	var total_score: int = maxi(0, repair_score + survival_bonus)

	var stars: int = 0
	if survived:
		stars = 1
		if health_pct >= two_star_pct:
			stars = 2
		if health_pct >= three_star_pct and total_score >= three_star_min_score:
			stars = 3

	var scrap_earned: int = 0
	if survived:
		scrap_earned = base_scrap + (stars * scrap_per_star)
	else:
		# Consolation scrap so failed attempts still feel rewarding for effort
		scrap_earned = maxi(10, mini(35, repairs_completed * 5))

	return {
		"survived": survived,
		"health_percent": health_pct,
		"repair_score": repair_score,
		"survival_bonus": survival_bonus,
		"total_score": total_score,
		"stars": stars,
		"scrap_earned": scrap_earned,
		"repairs_completed": repairs_completed
	}
