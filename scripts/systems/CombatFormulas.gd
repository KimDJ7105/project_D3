extends RefCounted
class_name CombatFormulas
## Isolated combat calculation formulas expected to be retuned via
## playtesting — keep exact numbers here, not scattered through gameplay
## code. See docs/03_combat_system.md "턴 순서" for the design reasoning.

const StatsScript := preload("res://scripts/data/Stats.gd")

## TODO: balance table, tune via playtesting. Stepped bonus to speed derived
## from the 기량(skill) stat. Brackets are placeholder values.
const SKILL_SPEED_BRACKETS := [
	{"max": 10, "bonus": 1},
	{"max": 20, "bonus": 2},
	{"max": 30, "bonus": 3},
]

static func skill_speed_bonus(skill: int) -> int:
	for bracket in SKILL_SPEED_BRACKETS:
		if skill <= bracket.max:
			return bracket.bonus
	return SKILL_SPEED_BRACKETS[-1].bonus

## 실질 속도 = 기본 속도 스탯 + 기량 구간별 보너스 + 장비 보정
static func effective_speed(stats: StatsScript, equipment_modifier: int = 0) -> int:
	return stats.speed + skill_speed_bonus(stats.skill) + equipment_modifier


## TODO: pure placeholder — no skill/technique data exists yet (damage/
## range/effects per docs/06_skill_style_system.md). This only validates
## that the combat loop itself (attack -> damage -> death) works; replace
## with real skill-based damage once that system is designed.
static func basic_attack_damage(attacker_stats: StatsScript) -> int:
	return max(1, attacker_stats.strength)
