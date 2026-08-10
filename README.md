# Untitled Tactics RPG (가제)

2D 탑뷰, 칸(그리드) 기반 턴제 전술 전투 + NPC/단체 관계 시스템 + 마을-던전 순환 구조 RPG.
Godot 4 (GDScript) 기반 1인 개발 프로젝트.

기획/결정 문서는 [`docs/`](docs/00_game_overview.md) 를 참고하세요.

## 폴더 구조
- `scenes/` — Godot 씬 (main, town, dungeon, combat, ui)
- `scripts/` — GDScript (core: 전역 관리자, systems: 관계 시스템 등, entities: NPC/유닛)
- `data/` — 게임 데이터 리소스 (npcs, factions, dialogues)
- `assets/` — 스프라이트, 타일셋, 오디오
- `docs/` — 기획/기술 결정 문서
