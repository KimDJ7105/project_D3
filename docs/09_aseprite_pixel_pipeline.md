---
title: Aseprite 픽셀아트 파이프라인
status: 진행 중
last_updated: 2026-08-10
---

# Aseprite 픽셀아트 파이프라인

Claude Code의 `pixel-plugin`(Aseprite MCP)을 통해 Aseprite를 명령어/자연어로 조작하기 위한 참고 문서.
설치 및 헬스체크 상태는 프로젝트 메모리에 별도 기록되어 있음(이 문서는 "어떻게 쓰는지"에 집중).

## 아트 파이프라인 결정 (2026-08-10)

- 베이스 스프라이트(캐릭터, 몬스터, 타일 등)는 **픽셀아트**로 제작.
- 네임드 NPC는 대화창용 **페인팅 버스트 초상화**를 별도 스타일 트랙으로 제작(AI 보조).
- 비주얼 지향점은 2.5D(HD-2D) — 관련 내용은 [[00_game_overview]], [[04_tech_stack]] 참고.
- 도구: Aseprite(Steam 버전) + `pixel-plugin`(Aseprite MCP) 조합으로 Claude Code에서 직접 스프라이트를 생성/편집.

## 명령어 목록

| 명령어 | 용도 | 예시 |
|---|---|---|
| `/pixel-setup [경로]` | 최초 1회 설정 (Aseprite 경로 등록 + 헬스체크) | `/pixel-setup` |
| `/pixel-new [크기] [팔레트]` | 새 스프라이트 생성 | `/pixel-new 32x32 gameboy` |
| `/pixel-palette set <이름>` | 프리셋 팔레트 적용 | `/pixel-palette set nes` |
| `/pixel-palette set custom <색상목록>` | 커스텀 팔레트 적용 | `/pixel-palette set custom #000000,#ffffff,#ff0000` |
| `/pixel-palette optimize <숫자>` | 현재 이미지의 색상 수를 줄여 팔레트 자동 생성 | `/pixel-palette optimize 16` |
| `/pixel-export png <파일> [scale=N]` | PNG로 내보내기 (scale로 확대) | `/pixel-export png sprite.png scale=4` |
| `/pixel-export gif <파일> [fps=N]` | 애니메이션 GIF로 내보내기 | `/pixel-export gif walk.gif fps=12` |
| `/pixel-export sheet <파일> [layout=...]` | 스프라이트시트로 내보내기 (horizontal/vertical/grid/packed) | `/pixel-export sheet sheet.png layout=grid` |
| `/pixel-export json <파일> [format=...]` | 게임 엔진용 메타데이터 내보내기 (unity 등, Godot은 직접 TileSet/AnimatedSprite 임포트로 대체 가능) | `/pixel-export json sprite.json format=unity` |
| `/pixel-help [주제]` | 도움말 (인자 없으면 전체 개요, `palettes`/`export`/`animation`/`shortcuts` 지정 가능) | `/pixel-help shortcuts` |

### 자연어로도 가능한 것들
명령어 외에 아래와 같은 자연어 요청도 지원(내부적으로 같은 MCP 도구를 호출):
- 그리기: "빨간 원을 중앙에 그려줘", "캐릭터 실루엣을 그려줘"
- 애니메이션: "4프레임 걷기 애니메이션 추가해줘", "idle 프레임 2장 만들어줘"
- 보정: "디더링 적용해줘", "16색으로 팔레트 최적화해줘", "왼쪽 위에서 오는 부드러운 음영 넣어줘"

### 흔한 작업 순서 예시
1. `/pixel-new 64x64 nes` — 캔버스 생성
2. "캐릭터를 그려줘" → "4프레임 걷기 사이클 추가해줘"
3. `/pixel-export sheet spritesheet.png layout=horizontal` — 스프라이트시트로 저장

## 팔레트(Palette)란?

팔레트는 스프라이트를 그릴 때 사용하는 **제한된 색상 집합**이다. 픽셀아트에서는 전체 이미지에 쓸 수 있는 색을 미리 정해두고 그 안에서만 색을 고르는 방식이 일반적인데, 이렇게 하면:

- **일관성**: 여러 스프라이트(캐릭터, 타일, 이펙트)가 같은 톤을 공유해 화면이 통일감 있게 보임.
- **레트로 무드**: 옛날 콘솔/컴퓨터는 하드웨어 한계로 색상 수가 정해져 있었고, 그 결과물이 특정 "느낌"(예: 게임보이의 초록빛 4색)으로 각인됨. 프리셋 팔레트를 쓰면 그 느낌을 그대로 재현 가능.
- **작업 속도**: 색을 무한정 고르는 대신 정해진 팔레트 안에서 고르므로 의사결정이 빨라지고, 명암/그림자 표현도 팔레트 안의 정해진 단계(램프)로 처리하기 쉬움.

`/pixel-palette set <이름>`으로 지정. 커스텀 색상 목록(`#hex,#hex,...`)도 가능.

### 프리셋 팔레트 목록

| 이름 | 색상 수 | 느낌 |
|---|---|---|
| `nes` | 54 | 패미컴(NES) 특유의 채도 높은 원색 위주 |
| `gameboy` | 4 | 오리지널 게임보이의 초록 단색조 (레트로 느낌 강함) |
| `gameboy-gray`(그레이) | 4 | 게임보이 포켓의 흑백 그레이스케일 |
| `c64` | 16 | 코모도어64, 다소 탁하고 채도 낮은 복고 색감 |
| `cga` | 4 | 초기 IBM PC, 강렬한 시안/마젠타 조합이 특징적 |
| `snes` | 256 | 슈퍼패미컴, 훨씬 넓은 색 범위로 그라데이션/음영 표현이 자유로움 |
| `pico8` | 16 | 팬텀시 콘솔 PICO-8 전용 팔레트, 현대 인디 픽셀아트에서 인기 |
| `sweetie16` | 16 | 현대적으로 다듬어진 16색 팔레트, 균형 잡힌 채도 |
| `db16` | 16 | DawnBringer 16색, 인디 픽셀아트에서 가장 널리 쓰이는 범용 팔레트 중 하나 |
| `db32` | 32 | DawnBringer 32색, db16보다 표현 범위 넓음 |

**선택 기준 가이드**: 색 수가 적을수록(gameboy, cga 등) 레트로 느낌은 강하지만 음영/그라데이션 표현이 제한적이고, 색 수가 많을수록(snes, db32) 자연스러운 명암 표현이 쉬워짐. 이 프로젝트는 던전 밖(밝고 인간적)과 던전 안(차갑고 비정한) 톤 대비가 핵심([[00_game_overview]])이므로, 지역별로 팔레트를 다르게 가져가는 것도 고려해볼 만함(예: 마을은 따뜻한 톤, 던전은 채도 낮은 톤) — 아직 미정.

## 관련 문서
- [[00_game_overview]]
- [[04_tech_stack]]
