extends Resource
class_name Stats
## Core 7 stats (see docs/03_combat_system.md, confirmed 2026-08-13).
## Default values (10 each) are placeholders — no balancing has happened yet.

@export var vitality: int = 10      # 체력
@export var strength: int = 10      # 힘
@export var skill: int = 10         # 기량
@export var intelligence: int = 10  # 지능
@export var faith: int = 10         # 신앙
@export var mystery: int = 10       # 신비
@export var speed: int = 10         # 속도 (기본치 — 전투용 실질 속도는 CombatFormulas.effective_speed 참고)
