extends Resource
class_name SkillData
## Static/authored definition of a combat skill — damage/range/effect per
## docs/06_skill_style_system.md. Instances live as .tres files under
## data/skills/. Both players and monsters use the same resource: an
## attacker's skill (equipped, or a monster's fixed attack_skill) is what
## CombatFormulas.skill_damage() reads to compute damage.
##
## No 유파(스킬 계열)/슬롯/등급(S~E) system exists yet — that's a much
## bigger, still-undecided piece of docs/06_skill_style_system.md.
## scaling_multiplier is a flat placeholder standing in for a real grade
## table until that system is designed.

@export var skill_id: String = ""
@export var display_name: String = ""

## Which Stats field this skill's damage scales from — must match one of
## Stats.gd's exported property names (e.g. "strength"). Read dynamically
## via Object.get() so new skills can scale off any stat without new code.
@export var scaling_stat: String = "strength"
@export var scaling_multiplier: float = 1.0

## 사거리 + 효과반경 (docs/03_combat_system.md "스킬 범위 구조", 2026-08-18).
## effect_radius = 0 means single-target — checked as distance to the
## specific enemy, not a point-in-space radius check (see Dungeon.gd).
@export var range: float = 1.5
@export var effect_radius: float = 0.0

@export var stamina_cost: float = 20.0
