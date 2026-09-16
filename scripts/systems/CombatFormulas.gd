extends RefCounted
class_name CombatFormulas
## Isolated combat calculation formulas expected to be retuned via
## playtesting — keep exact numbers here, not scattered through gameplay
## code. See docs/03_combat_system.md "턴 순서" for the design reasoning.

const StatsScript := preload("res://scripts/data/Stats.gd")
const SkillDataScript := preload("res://scripts/data/SkillData.gd")

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


## 스킬 데미지 = scaling_stat 값 × scaling_multiplier(등급 체계 확정 전까지의
## 임시 대체치 — docs/06_skill_style_system.md, 유파/등급 시스템은 아직 설계
## 전). scaling_stat은 Stats.gd 필드 이름과 정확히 일치해야 함(Object.get()
## 으로 동적으로 읽어서, 어떤 스탯을 쓰는 스킬이든 코드 추가 없이 지원됨).
static func skill_damage(attacker_stats: StatsScript, skill: SkillDataScript) -> int:
	var stat_value: int = attacker_stats.get(skill.scaling_stat)
	return max(1, roundi(stat_value * skill.scaling_multiplier))

## TODO: balance placeholders — see docs/03_combat_system.md "전투 중 이동과
## 스테미나" (2026-08-18). Elevation surcharge on movement isn't implemented
## yet since no dungeon geometry has elevation to test against.
const MOVE_STAMINA_COST_PER_UNIT := 5.0
## Throwing an item costs the same as a basic attack, conceptually — see
## docs/10_inventory_system.md "전투 중 투척". Skills carry their own
## stamina_cost individually now (see skill_damage()); this is only for
## items, which aren't SkillData.
const THROW_STAMINA_COST := 20.0

static func movement_stamina_cost(distance: float) -> float:
	return distance * MOVE_STAMINA_COST_PER_UNIT

## How far `stamina` can still move this turn, at the current cost rate.
static func max_move_distance(stamina: float) -> float:
	return stamina / MOVE_STAMINA_COST_PER_UNIT
