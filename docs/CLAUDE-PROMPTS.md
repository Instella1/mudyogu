# 클로드에게 — 뮤됴구 프로젝트 인수인계 프롬프트

> 아래 **"복사해서 붙여넣기"** 블록을 클로드에게 그대로 주면 됩니다.
> 상황에 맞는 것 하나만 고르세요.

---

## A. 처음 프로젝트를 넘겨받을 때

```
뮤됴구(Mudyogu)라는 Flutter PWA 미니게임 허브 프로젝트야. 앞으로 네가 유지보수와
업데이트를 맡아줘. 작업 전에 반드시 아래 순서로 읽어줘.

1) docs/HANDOFF.md          ← 전체 구조, 규칙, 과거 버그 이력
2) docs/GAME-SPEC.md        ← 게임 ↔ 앱 연동 규약
3) build.sh, tools/patch_web.py   ← 빌드 파이프라인

환경: Flutter 3.35.4 / Dart 3.9.2 (버전 업그레이드 금지)

[절대 규칙 — 어기면 과거 버그가 재발함]
1. iframe 위에 Flutter 위젯을 Stack 으로 겹치지 마. iframe 은 항상 Flutter 위
   레이어라 클릭이 안 먹힌다. Column/Expanded 로 위아래 분리할 것.
2. Sliver(SliverGrid 등)를 Padding 같은 박스 위젯으로 감싸지 마. 조용히 안 보인다.
   SliverPadding 을 쓸 것.
3. 게임 CSS 에서 aspect-ratio 를 쓸 때 height 를 고정하지 마.
   flex:1 1 auto; min-height:0; width:auto; aspect-ratio:W/H 패턴을 쓸 것.
4. 게임 파일에 외부 URL(CDN 폰트, 이미지) 넣지 마. 오프라인이 깨진다.
5. web/service_worker.js 의 VERSION 을 올리지 않고 배포하지 마. 기존 사용자에게
   옛 파일이 남는다.
6. build.sh 를 거치지 않고 flutter build web 만 돌리지 마. tools/patch_web.py 가
   서비스워커 충돌과 canvaskit CDN 문제를 잡아주는데 그게 빠진다.
7. 게임 원본 HTML 의 기존 줄을 고치지 마. 덧붙이기만 하고, 화면 맞춤은 통째 zoom 으로.
   (원본과 달라 보이던 문제의 원인. docs/HANDOFF.md 1-3 참고)

[디자인]
브랜드 컬러 #2FCC8B, 폰트 NanumSquareRound, 클린/파스텔, 한국어만,
사운드 없음, 광고 없음. 1순위 타깃은 크롬북 1366x768, 2순위 모바일.

[작업 습관]
- 코드 고치기 전에 git log 로 왜 그렇게 됐는지 확인해줘.
- flutter analyze 통과 확인 후에 "됐다"고 말해줘.
- 커밋 메시지는 한국어로, fix:/feat: 접두사.
- UI 를 고쳤으면 실제 브라우저(1366x768)에서 클릭해보고 확인해줘.

먼저 HANDOFF.md 를 읽고, 이해한 내용을 10줄 이내로 요약해서 보여줘.
```

---

## B. 특정 기능을 수정할 때

```
뮤됴구 프로젝트야. docs/HANDOFF.md 를 먼저 읽어줘.

[요청]
(여기에 원하는 걸 적으세요. 예: "홈 화면에 게임 검색창을 추가해줘")

[참고]
- 상태는 lib/state/app_state.dart 에 다 모여 있어. 새 상태가 필요하면 여기 추가.
- 설정값은 lib/services/settings_service.dart 에 키를 추가하고
  LocalStore.settings 박스에 저장.
- UI 는 lib/screens/, 조각은 lib/widgets/.
- 색/폰트는 lib/theme/app_theme.dart 만 참고해. 하드코딩 금지.

[확인]
고친 뒤에 flutter analyze 돌리고, 1366x768 로 실제 화면 스크린샷 찍어서 보여줘.
```

---

## C. 새 게임을 추가할 때

```
뮤됴구에 새 HTML5 게임을 추가하려고 해. docs/HANDOFF.md 와
docs/GAME-SPEC.md 를 먼저 읽어줘.

[게임 정보]
- id: (영문 소문자, 예: space-shooter)
- 제목: (예: 우주 슈터)
- 한 줄 소개: (예: 운석을 피해 최고 점수를 노려라)
- 장르: (예: 슈팅 / 퍼즐 / 육성)
- 화면 비율: 16/9  (세로 게임이면 9/16)
- 점수 라벨: (예: 최고 점수 / 최종 오버랩)

[요구사항]
1. web/games/<id>/index.html 단일 파일로 만들어줘 (외부 URL 금지, 순수 HTML/CSS/JS)
2. mudyogu-sdk.js 를 붙이고 규약대로 연동해줘:
   - MUD.ready()
   - MUD.onInit() 으로 state / bestScore 복원
   - MUD.save({ score, state, isGameOver }) 로 저장
3. iframe 안(mudEmbed=1)일 때와 단독 실행일 때 둘 다 자연스럽게 동작해야 해
4. 화면 비율이 절대 찌그러지면 안 돼 (HANDOFF.md 의 3번 규칙)
5. 크롬북 1366x768 과 모바일 390x844 에서 모두 확인
6. 조작: PC 는 키보드(←↑→↓ 또는 WASD), 모바일은 터치.
   화면에 방향 버튼을 그리지 말고 @media (pointer:coarse) 로 터치 패드 표시

[등록]
tools/add_game.py 를 쓰거나 직접:
- assets/games/catalog.json 에 항목 추가
- web/service_worker.js PRECACHE_SHELL 에 경로 추가
- lib/widgets/game_card.dart _icons 에 아이콘 매핑
- service_worker.js VERSION 증가

만든 뒤에 스크린샷 보여주고, 실제로 클릭해서 플레이되는지 확인해줘.
```

---

## D. 버그를 고칠 때

```
뮤됴구 프로젝트 버그 리포트야. docs/HANDOFF.md 7번(과거 버그 이력)을 먼저 봐줘.
비슷한 사례가 이미 있을 수 있어.

[증상]
(예: 게임 화면에서 나가기 버튼을 눌러도 반응이 없다)

[재현 방법]
(예: 게임 열기 → 전체화면 아이콘 클릭 → 우상단 X 클릭)

[기대 동작]
(예: 앱 홈으로 돌아와야 한다)

[요청]
1. 먼저 증상을 재현해서 원인을 확인해줘. 추측으로 고치지 마.
2. 원인을 한 문단으로 설명해줘.
3. 고친 뒤 같은 방법으로 재현해서 해결됐는지 보여줘.
4. 왜 그렇게 됐는지 커밋 메시지에 남겨줘.
```

---

## E. 배포할 때

```
뮤됴구 새 버전 배포해줘.

1. web/service_worker.js 의 VERSION 을 한 단계 올려줘 (예: v9 → v10)
2. 바뀐 내용을 한국어 커밋 메시지(fix:/feat:)로 커밋하고 GitHub main 에 push
3. GitHub Actions(빌드 & 배포)가 성공했는지 확인해줘
   - 실패하면 로그를 보고 고쳐서 다시 push
4. 배포 주소에서 version.json 이 새 buildId 로 바뀌었는지 확인
5. 바뀐 내용을 한국어로 요약해줘

VERSION 을 안 올리면 기존 사용자 브라우저에 옛 파일이 남으니 꼭 확인해줘.
```

---

## 붙여넣기 전 체크리스트

- [ ] 이 저장소(또는 zip)를 클로드에게 넘겼는가
- [ ] `docs/HANDOFF.md`, `docs/GAME-SPEC.md` 가 포함돼 있는가
- [ ] `web/games/` 폴더가 통째로 들어 있는가 (게임 2종 + SDK)
- [ ] `assets/games/catalog.json` 이 있는가
- [ ] 작업 후 결과물을 어떻게 돌려받을지 정했는가 (git push / zip)
