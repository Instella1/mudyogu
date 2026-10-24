# 뮤됴구 (Mudyogu) — Claude Code 작업 안내

Flutter PWA 미니게임 허브. HTML 게임 4개를 iframe 으로 얹어 돌린다 (3개는 사용자가 직접 만든 것, 타워 크래시는 사용자 아이디어로 Claude 가 제작).
사이트: https://instella1.github.io/mudyogu/ · 사용자는 한국어로 대화, 크롬북(1순위)·폰 사용.

## 작업 전에 반드시 읽을 것
1. `docs/HANDOFF.md` — 구조 · 절대 규칙 · 과거 버그 표 (여기가 기준)
2. `docs/GAME-SPEC.md` — 게임 규약 · 진행 코드 접두사
3. `tools/game_builders/README.md` — 원본 → 사이트 버전 빌더

## 절대 규칙 (어기면 과거 버그 재발)
- Flutter 3.35.4 / Dart 3.9.2 고정. 업그레이드 금지
- iframe 위에 Flutter 위젯을 Stack 으로 겹치지 말 것 (클릭 안 먹음 → Column 분리)
- Sliver 를 Padding 으로 감싸지 말 것 (SliverPadding)
- iframe 에 `scrolling="no"` 넣지 말 것 (LIFE 아래가 잘림). 스크롤 막기는 게임 CSS 로
- **게임 원본 줄은 고치지 말 것. 덧붙이기만.** 원본은 `originals/` 에 있음 — 고친 뒤 `diff` 로 '추가만' 확인
  (타워 크래시는 Claude 가 만든 게임이라 원본 파일이 없고 `web/games/tower-drop/index.html` 을 직접 고친다)
- 화면 맞춤은 배치를 바꾸지 말고 통째로 CSS `zoom` (한일전 `fitToScreen`, LIFE/포케퀴즈는 첫 화면이 창 높이에 맞게)
- 게임에 외부 URL 금지 (폰트·라이브러리는 로컬). 예외: 포케퀴즈 포켓몬 그림(PokeAPI sprites, 저작권·용량)
- 배포마다 `web/service_worker.js` 의 `VERSION` 을 올릴 것 (현재 `mudyogu-v23`)
- `flutter build web` 만 돌리지 말고 `./build.sh` (patch_web.py 포함)

## 게임 4개
| id | 제목 | 진행 코드 | 코드 넣는 곳 |
|---|---|---|---|
| `haniljeon` | 한일전 | `HIJ1\|` | 메뉴 💾 진행 코드 → 코드로 불러오기 |
| `hanilnam-life` | 한(일)남 LIFE | `MUDX1\|hanilnam-life\|` (전체), 리포트 코드(base64) | 첫 화면 ▶ 전체 기록 옮기기 |
| `pokequiz` | 포케퀴즈 | `PKQ1\|` | 🏅 기록저장실 → 진행 코드 옮기기 |
| `tower-drop` | 타워 크래시 | `MUDX1\|tower-drop\|` | 첫 화면 💾 진행 코드 → 불러와서 합치기 |

진행 코드 가져오기는 **덮어쓰지 않고 합치기**. 독립 실행본(파일 하나로 여는 버전)은 `tools/make_standalone.py`.

## 배포
`main` 에 push → GitHub Actions(`.github/workflows/deploy.yml`)가 `flutter analyze` → 외부 URL 검사 →
`./build.sh` → GitHub Pages 배포. push 후 Actions 가 통과했는지 꼭 확인 (`gh run list`).
작업 환경에 Flutter 가 없으면 Dart 검사는 Actions 가 대신한다. 게임 HTML 은 Playwright 로 직접 띄워 확인.

## 커밋
한국어, `fix:` / `feat:` 접두사, 왜 고쳤는지 본문에 적기.

## 사용자와 정한 약속
- **작업이 끝나면 묻지 말고 바로 배포한다** (main 에 push). 배포 후 Actions 통과를 확인하고 결과만 짧게 보고.
- 사용자가 지시를 하면 군말 없이 바로 대답하고 실행한다. 이미 한 작업을 처음 듣는 것처럼 되묻지 말 것 —
  모르면 먼저 `git log` 와 이 파일을 확인.
- 2026-10-23 젠스파크 → 일반 Claude 대화 → Claude Code 로 이전 완료. 이후 작업은 이 저장소가 기준.
