# 뮤됴구 (Mudyogu)

작은 게임들을 한 곳에서. **설치형 웹앱(PWA) 미니게임 허브.**

- Flutter 앱 껍데기 안에 **HTML5 게임을 iframe 으로** 얹어 돌립니다
- 한 번 접속하면 **인터넷 없이** 앱과 게임 전부 실행됩니다
- 이메일 로컬 계정으로 기록 저장, 게스트 플레이 가능
- 1순위 타깃: **크롬북 (1366×768)** / 2순위: 모바일

현재 수록 게임: **한일전**, **한(일)남 LIFE** (2종)

---

## 빠른 시작

```bash
flutter analyze                  # 문법 검사
./build.sh                       # 웹 빌드 (+ 오프라인 자동 패치)
python3 -m http.server 5060 --directory build/web
# → http://localhost:5060
```

배포용 zip:

```bash
python3 tools/pack_html.py
# → build/web/downloads/mudyogu-html.zip
```

---

## 문서

| 문서 | 내용 |
|---|---|
| [docs/HANDOFF.md](docs/HANDOFF.md) | **전체 구조 · 규칙 · 과거 버그 이력** (여기부터) |
| [docs/GAME-SPEC.md](docs/GAME-SPEC.md) | 게임 ↔ 앱 연동 규약 (게임 만들 때) |
| [docs/CLAUDE-PROMPTS.md](docs/CLAUDE-PROMPTS.md) | AI 에게 작업 맡길 때 쓰는 프롬프트 |

---

## 구조 한눈에

```
lib/          Flutter 앱 (Dart) — 껍데기, 홈, 설정, 계정
web/games/    HTML5 게임들 — 여기만 고쳐도 게임 개발 가능
assets/       게임 카탈로그(catalog.json), 폰트
tools/        빌드/패키징/게임설치 스크립트
```

---

## 꼭 지킬 것

1. **iframe 위에 Flutter 위젯을 Stack 으로 겹치지 마세요** — 클릭이 안 먹힙니다
2. **Sliver 를 Padding 으로 감싸지 마세요** — 조용히 안 보입니다
3. **게임 CSS 에서 aspect-ratio + 고정 height 조합 금지** — 찌그러집니다
4. **게임에 외부 URL 금지** — 오프라인이 깨집니다
5. **배포 전 service_worker.js 의 VERSION 증가** — 안 하면 옛 파일이 남습니다
6. **build.sh 를 거치세요** — patch_web.py 가 오프라인 문제를 잡아줍니다

자세한 이유는 [docs/HANDOFF.md](docs/HANDOFF.md) 1번에 있습니다.

---

## 환경

Flutter 3.35.4 / Dart 3.9.2 — **버전 업그레이드 금지** (검증된 조합)
