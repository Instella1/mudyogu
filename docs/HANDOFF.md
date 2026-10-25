# 뮤됴구 (Mudyogu) — 개발 인수인계 문서

> 이 문서 하나만 읽으면 이 앱을 이어서 개발할 수 있게 쓰였습니다.
> 마지막 갱신: 2026-10-23 (Claude 인수 후 개정) · 환경: Flutter 3.35.4 / Dart 3.9.2

---

## 0. 30초 요약

**뮤됴구**는 **"작은 게임들을 한 곳에서"** 즐기는 **설치형 웹앱(PWA)** 입니다.
Flutter 로 만든 앱 껍데기 안에, **HTML5 게임들을 iframe 으로 얹어** 돌립니다.

- 게임은 순수 HTML/CSS/JS. Flutter 코드를 몰라도 **게임만 따로 만들 수 있음**
- 한 번 접속하면 **인터넷 없이** 앱과 게임 전부 실행됨 (Service Worker 사전 캐시)
- 이메일 계정(Supabase 온라인)으로 기록 저장 → 어느 기기에서든 로그인하면 이어짐. 게스트도 플레이 가능
- **1순위 타깃: 크롬북 (1366×768)**, 2순위: 모바일

```
┌──────────────────────────────────────┐
│  Flutter 앱 (껍데기)                  │
│  ├─ 홈: 게임 카드 그리드              │
│  ├─ 설정: 테마 / 계정 / 데이터        │
│  └─ 게임 화면                          │
│       └─ <iframe>  ← HTML5 게임       │
│            postMessage 로 대화         │
└──────────────────────────────────────┘
```

---

## 1. 절대 지켜야 할 것 (READ ME FIRST)

이 네 가지를 어기면 과거에 실제로 났던 버그가 재발합니다.

### ⚠️ 1) iframe 위에 Flutter 버튼을 겹치지 마라

웹에서 `HtmlElementView`(iframe)는 **Flutter 캔버스보다 항상 위 레이어**에 그려집니다.
`Stack` + `Positioned` 로 버튼을 올리면 **화면에는 보이지만 클릭이 절대 안 됩니다.**

```dart
// ❌ 절대 금지 — 전체화면에서 나가기가 안 먹힘
Stack(children: [ gameIframe, Positioned(top: 0, child: Controls()) ])

// ✅ 이렇게 — 위아래로 분리 (겹침 0)
Column(children: [
  SizedBox(height: 44, child: Controls()),   // 전용 바
  Expanded(child: gameIframe),               // 그 아래
])
```
→ 실제로 "전체화면에서 나갈 수 없던 버그"가 이 원인이었습니다. (`lib/screens/game_screen.dart`)

### ⚠️ 2) Sliver 를 일반 위젯으로 감싸지 마라

`SliverGrid` / `SliverList` 는 **`Padding` 같은 박스 위젯 안에 넣으면 조용히 사라집니다.**
(에러도 안 남. 그냥 안 보임.)

```dart
// ❌ 카드가 통째로 안 보임
Padding(padding: ..., child: SliverGrid(...))

// ✅
SliverPadding(padding: ..., sliver: SliverGrid(...))
```

### ⚠️ 3) 게임은 '원본 모양 그대로' — 배치를 바꾸지 말고 통째로 확대/축소

(2026-10-23 개정) 예전엔 게임 화면을 앱에 맞추려고 게임 CSS 를 200줄 가까이 덧씌웠고,
그 결과 **원본 게임과 화면이 달라졌습니다** (버튼 배치, 글씨 크기, 로고 크기, 이모지 삭제).
지금 규칙:

- 게임 원본 HTML 의 기존 줄은 **고치지 않는다. 덧붙이기만** 한다 (SDK 연동, 진행 코드, 폰 터치 버튼).
- 화면 맞춤이 필요한 게임(고정 크기 캔버스, 예: 한일전 1000×550)은 화면 전체를
  CSS `zoom` 으로 **통째로** 줄이거나 키운다 → `web/games/haniljeon/index.html` 맨 아래 `fitToScreen`.
- 원래 반응형인 게임(한(일)남 LIFE)은 원본 CSS 그대로 둔다.
- 앱의 게임 무대(`_GameStage`)는 **남는 공간 전부**를 iframe 에 준다. 16:9 상자·둥근 테두리 없음.
  (catalog 의 `aspect` 값은 지금 무대 크기에 쓰이지 않음)
- 원본 파일 보관: 게임을 고칠 땐 항상 사용자가 준 원본과 `diff` 해서 '추가만' 있는지 확인.

#### (참고) CSS `aspect-ratio` 는 고정 `height` 와 함께 쓰면 무효

게임 캔버스가 찌그러지던 원인입니다. 세로만 줄어들어 비율이 1.818 → 1.465 로 깨졌습니다.

```css
/* ❌ height 고정 + flex-shrink:1 → 세로만 줄어 찌그러짐 */
#canvas-container { height: 550px; }

/* ✅ 높이는 flex 가 정하고, 폭을 비율로 유도 */
#canvas-container {
  flex: 1 1 auto;
  min-height: 0;
  width: auto;
  aspect-ratio: 1000 / 550;
}
```

### ⚠️ 4) 캐너스킷/폰트를 CDN 에서 받아오면 오프라인 즉사

Flutter 기본값은 `gstatic.com` 에서 wasm 을 받습니다.
`build.sh` 가 `tools/patch_web.py` 로 **로컬 `canvaskit/` 을 쓰도록** 자동 패치합니다.
**이 패치를 건너뛰면 오프라인이 깨집니다.**

---

## 2. 실행 & 빌드

### 개발 미리보기

```bash
cd /home/user/flutter_app

# 문법 검사 먼저 (권장)
flutter analyze

# 빌드 + 로컬 서버 (포트 5060)
./build.sh
python3 -m http.server 5060 --directory build/web --bind 0.0.0.0
```

### `build.sh` 가 하는 일

1. `BUILD_ID` 생성 (UTC 타임스탬프 + git short hash)
2. `flutter build web --release` + `--dart-define` 3종 주입
3. `build/web/version.json` 작성 → **앱이 이걸 폴링해 "새 버전 있음" 배너**를 띄움
4. `tools/patch_web.py` 실행:
   - Flutter 기본 서비스워커(`flutter_service_worker.js`) 등록 **해제**
   - `canvasKitBaseUrl: 'canvaskit/'` 로컬 지정

### HTML 배포용 번들 만들기

```bash
python3 tools/pack_html.py
# → build/web/downloads/mudyogu-html.zip (약 8MB)
```

하는 일:
- `<base href="./">` 상대 경로 (하위 폴더 배포 가능)
- 디버그 심볼(`.symbols`), 미사용 `skwasm*` 제거 → 20MB
- `README-배포방법.txt` 동봉

---

## 3. 폴더 구조

```
flutter_app/
├── build.sh                  ★ 빌드 스크립트 (여기부터 보세요)
├── pubspec.yaml              의존성 (버전 고정 — 함부로 올리지 마세요)
│
├── lib/                      Flutter 앱 (Dart)
│   ├── main.dart             진입점. Hive 초기화 → runApp
│   ├── state/
│   │   └── app_state.dart    ★ 전역 상태 (Provider). 여기 API 가 다 있음
│   ├── models/
│   │   ├── account.dart      Account, GameProgress, ProgressEvent
│   │   └── game_info.dart    GameInfo, GameCatalog (카탈로그 파싱)
│   ├── screens/
│   │   ├── welcome_screen.dart   첫 화면 (시작 / 게스트 / 로그인)
│   │   ├── auth_screen.dart      회원가입 / 로그인 / 복구
│   │   ├── home_screen.dart      게임 카드 그리드
│   │   ├── game_screen.dart      ★ 게임 플레이 (iframe + 컨트롤)
│   │   └── settings_screen.dart  테마 / 계정 / 데이터 관리
│   ├── services/
│   │   ├── local_store.dart      Hive 박스 관리
│   │   ├── auth_service.dart     로컬 이메일 계정 (해시 + salt)
│   │   ├── progress_service.dart ★ 진행 저장 + 게스트 병합 + 저장코드
│   │   ├── settings_service.dart 테마 / 마지막 게임
│   │   ├── catalog_service.dart  게임 목록 로더
│   │   ├── pwa_service*.dart     서비스워커 / 설치 / 버전 폴링
│   │   └── build_info.dart       --dart-define 값
│   ├── widgets/
│   │   ├── game_host*.dart       ★ iframe 브리지 (웹/스텁 분기)
│   │   ├── game_card.dart        홈 카드 1개
│   │   ├── update_banner.dart    새 버전 배너
│   │   └── common.dart           공용 UI 조각
│   └── theme/
│       └── app_theme.dart        색/타이포 (브랜드 #2FCC8B)
│
├── assets/
│   ├── games/catalog.json    ★ 게임 목록 (여기에 추가하면 홈에 뜸)
│   └── fonts/                NanumSquareRound
│
├── web/                      빌드 시 build/web 으로 그대로 복사됨
│   ├── index.html
│   ├── manifest.json         PWA 메타데이터
│   ├── service_worker.js     ★ 오프라인 캐시 (사전 캐시 목록 관리)
│   ├── icons/
│   └── games/                ★★ 게임들이 사는 곳
│       ├── mudyogu-sdk.js    게임↔앱 연동 SDK
│       ├── mudyogu.css       공통 스타일
│       ├── haniljeon/        한일전
│       ├── hanilnam-life/    한(일)남 LIFE
│       ├── pokequiz/         포케퀴즈 (실루엣 인카운터) — 폰트/peerjs 로컬, 포켓몬 그림만 외부
│       └── tower-drop/       타워 크래시 — 캔버스로 전부 그림(이미지 0장), 폰트만 로컬
│
└── tools/
    ├── add_game.py           게임 자동 설치 (복사 + SDK 주입 + 카탈로그 등록)
    ├── pack_html.py          HTML 배포 번들 생성
    ├── patch_web.py          ★ 부트스트랩 패치 (오프라인)
    ├── bundle_fonts.py       웹폰트 로컬 번들
    └── verify_games.py       게임 무결성 검사
```

---

## 4. 데이터 구조

### 저장소 (Hive — 브라우저 IndexedDB)

| 박스 이름 | 내용 |
|---|---|
| `accounts` | 이메일 → 계정 캐시(비번 해시, salt) — 인터넷 없을 때 로그인용 |
| `session` | `{ email, isGuest, cloud }` 현재 세션 (`cloud` = Supabase 토큰) |
| `settings` | 테마, 마지막 게임, **`saveCode::<계정>::<게임id>` 미러** (계정별!) |
| `progress_guest` | 게스트 진행상황 |
| `progress_u_<email>` | 계정별 진행상황 (이메일에서 특수문자 → `_`) |
| `vault` | 계정별 **게임 localStorage 보관함** (계정 전환 시 바꿔 끼움) |

### 온라인 계정 (Supabase — 타워 크래시 랭킹과 같은 프로젝트)

- 계정: Supabase Auth (이메일/비밀번호). 비밀번호 재설정은 메일 링크 → `web/index.html` 이 새 비밀번호 입력창을 띄움
- 기록: 테이블 `mud_saves` (계정당 한 줄, RLS 로 내 줄만) → `docs/supabase-accounts.sql`
- 기록 묶음 = `{ ls: 게임 localStorage 전체('flutter.' 로 시작하지 않는 키), progress: 진행상황 }`
- 흐름 (`lib/services/sync_service.dart`)
  - 계정 바꿀 때: 지금 기록 → 그 계정 보관함 + 온라인 → 새 계정 기록(온라인/보관함 중 새 것)으로 교체
  - 기록이 바뀌면 4초 모아 온라인에 올림, 탭이 숨겨질 때도 올림. 앱을 켤 때 다른 기기의 새 기록을 받아옴
  - 예전 '이 기기에만' 계정: 로그인하면 같은 이메일/비밀번호로 온라인 계정을 자동 생성 + 기록 업로드
  - 처음 한 번(`vaultV1`): 계정 구분 없던 시절의 게임 기록은 이 기기에서 가장 먼저 만든 계정 것으로 정리
- ⚠️ 게임 기록을 localStorage 말고 다른 곳(IndexedDB 등)에 쓰는 게임을 추가하면 계정 분리가 안 된다 → localStorage 를 쓸 것

### `GameProgress` (`lib/models/account.dart`)

```dart
{
  gameId: 'haniljeon',
  bestScore: 120,          // 최고점 (카드에 표시)
  playCount: 7,
  playSeconds: 340,
  updatedAt: '2026-10-23T...',
  state: {...},            // 게임이 자유롭게 쓰는 JSON (앱은 해석 안 함)
  saveCode: 'HIJ1|eyJ2Ijo...',  // 게임이 만든 백업 문자열
  saveCodeAt: '...'
}
```

### `catalog.json` — 게임 추가는 여기

`assets/games/catalog.json`:

```json
{
  "schemaVersion": 1,
  "updatedAt": "2025-01-04T00:00:00Z",
  "games": [
    {
      "id": "haniljeon",                        // 고유 id (폴더명과 맞추세요)
      "title": "한일전",
      "tagline": "15개 스테이지 보스를 격파하라",
      "entry": "games/haniljeon/index.html",    // web/ 기준 상대경로
      "accent": "#FFC9B7",                      // 카드 강조색
      "tags": ["액션", "보스전", "아케이드"],
      "version": "1.0.0",
      "supportsState": true,
      "bestScoreLabel": "최고 점수",             // 앱바 🏆 옆 라벨
      "builtIn": false,
      "aspect": "16/9"                          // 게임 화면 비율 (중요!)
    }
  ]
}
```

- `aspect` — 앱이 이 비율로 무대를 만들고 **레터박스** 처리합니다. 틀리면 여백이 생깁니다.
- 필드를 추가하면 `GameInfo.fromJson` 도 같이 고쳐야 합니다.

---

## 5. 게임 ↔ 앱 연동 (가장 중요)

게임은 **앱이 없어도 단독 실행**되어야 하고, 앱 안에서는 **기록이 저장**되어야 합니다.
이걸 담당하는 게 `web/games/mudyogu-sdk.js` 입니다.

### 게임 쪽에서 쓰는 법

```html
<script src="../mudyogu-sdk.js"></script>
<script>
  const MUD = MudyoguSDK.create();     // iframe 안이면 isEmbedded = true

  MUD.ready();                          // 준비 완료 알림

  // 앱이 보낸 상태 복원
  MUD.onInit((payload) => {
    // payload.state      : 앱에 저장돼 있던 state
    // payload.bestScore  : 최고 기록
    // payload.savedCode  : 앱이 보관하던 저장 코드 (문자열)
    if (payload.state) restore(payload.state);
    if (payload.savedCode) applySaveCode(payload.savedCode);
  });

  // 진행 저장 (점수 / 상태 / 게임오버)
  MUD.save({ score: 120, state: { level: 3 }, isGameOver: true });

  // 저장 코드 보관 요청 (다른 기기 이어하기용)
  MUD.saveCode({ code: 'HIJ1|...', label: '진행 코드' });

  // 앱이 보관 중인 코드 달라고 하기
  MUD.requestCode();
  MUD.onCode((code) => applySaveCode(code));
</script>
```

### postMessage 규약

```
게임 → 앱     { mudyogu: <token>, type: 'ready' | 'progress' | 'saveCode' | 'requestCode' | 'resetBest', ... }
              (resetBest: 앱의 최고 기록만 0 으로 — MUD.resetBest(), 타워 크래시 설정에서 씀)
앱 → 게임     { type: 'init' | 'pause' | 'resume' | 'state' | 'saveCode' }
```

- `token` 은 iframe URL 의 `?mudToken=...` 에서 옵니다. **이게 맞아야 앱이 메시지를 받습니다.**
- `?mudEmbed=1` 이 붙어 있으면 임베드 모드 → 게임이 `html.mud-embed` 클래스를 붙입니다.

### 앱 쪽 구현

`lib/widgets/game_host_web.dart`
- iframe 생성 (`ui_web.platformViewRegistry`)
- `_sendToGame()` / 이벤트 수신 → `onEvent` 콜백
- `savedCode` 를 `init` 과 `saveCode` 로 **두 번 밀어줌** (게임 로딩 타이밍 차이 대응)

`lib/screens/game_screen.dart` → `_onGameEvent()`
- `type == 'saveCode'` → `state.storeGameCode()`
- `type == 'requestCode'` → 보관된 코드를 게임에 전송
- 나머지 → `ProgressEvent.tryParse()` → `state.applyProgress()`

> **포케퀴즈 예외**: 포켓몬 공식 일러스트(1025장)는 저작권·용량(수백 MB) 때문에 우리 사이트에
> 다시 올리지 않고 원본처럼 `raw.githubusercontent.com/PokeAPI/sprites` 에서 불러온다.
> 오프라인에서는 그림만 안 보이고 퀴즈(종족값)는 동작. 온라인 대전(peerjs)은 원래 인터넷 필요.

### 게임 파일이 지켜야 할 3가지

1. **모든 경로가 상대경로** — 하위 폴더 배포에서도 동작해야 함
2. **외부 URL 금지** — 웹폰트/이미지도 로컬에 넣기 (`tools/bundle_fonts.py` 참고)
3. **단독 실행 지원** — iframe 이 아니어도 그냥 플레이 가능해야 함

---

## 6. 자주 하는 작업

### 새 게임 추가

```bash
# 가장 쉬운 방법 (복사 + SDK 주입 + 카탈로그 등록 자동)
python3 tools/add_game.py ~/Downloads/새게임.zip \
    --id newgame --title "새 게임" --tagline "한 줄 소개" --accent "#A8E6CF"
```

수동으로 한다면:
1. `web/games/<id>/` 에 게임 파일 복사
2. `index.html` 에 SDK 스크립트 추가
3. `assets/games/catalog.json` 에 항목 추가
4. `web/service_worker.js` 의 `PRECACHE_SHELL` 에 **게임 파일 경로 추가** (오프라인용)
5. `lib/widgets/game_card.dart` 의 `_icons` 에 아이콘 지정 (없으면 기본 아이콘)

### 기록 옮기기 (진행 코드)

세 게임 모두 '진행 코드' 한 줄로 기록 전체를 옮길 수 있다. 앱 계정에도 자동 보관된다.

가져오기는 **아무것도 버리지 않고 합치기**가 원칙이다.

| 게임 | 화면 위치 | 형식 | 가져올 때 (합치기 규칙) |
|---|---|---|---|
| 한일전 | 메뉴 `💾 진행 코드` | `HIJ1|...` | 최고 스테이지 큰 쪽 · 클리어 합집합 · 별점 스테이지별 최고 · 업적 합집합 |
| 한(일)남 LIFE | 첫 화면 `전체 기록 옮기기` | `MUDX1|hanilnam-life|...` | 슬롯: 가져온 칸 우선, 빈 칸은 유지(둘 다 있으면 확인창) · MY TEAM 합집합(id) 최대 20 · 라인업 가져온 것 |
| 포케퀴즈 | `🏅 기록저장실` 맨 아래 | `PKQ1|...` | 도감 합집합 · 고유 코드/닉네임 가져온 것 · 대전 기록 합치기 · 티켓 큰 쪽(사이트 처음이면 가져온 그대로) |
| 타워 크래시 | 첫 화면 `💾 진행 코드` | `MUDX1|tower-drop|...` | 최고 층·너트·통계 큰 쪽 · 캐릭터/업적 합집합 · 착용 캐릭터는 지금 것 |

네 게임 모두 켤 때/기록이 바뀔 때 앱 계정에 코드를 보관 → 새 기기에서 로그인하면 자동 복원.

**독립 실행본** (예전에 하던 곳에서 열어 코드를 뽑는 용도):
`python3 tools/make_standalone.py` → `build/standalone/*.html`
사이트 버전에서 SDK 태그만 빼고 폰트/라이브러리를 인터넷 주소로 되돌린 '파일 하나' 버전.

### 게임 삭제

1. `web/games/<id>/` 폴더 삭제
2. `catalog.json` 에서 항목 제거
3. `service_worker.js` `PRECACHE_SHELL` 에서 경로 제거
4. `game_card.dart` `_icons` 매핑 제거
5. `service_worker.js` 의 `VERSION` 올리기 (`mudyogu-v7` → `v8`)
   → **안 올리면 기존 사용자 브라우저에 옛 게임이 남습니다.**

### 새 버전 배포 (GitHub 자동 배포)

1. `web/service_worker.js` 의 `VERSION` **반드시 증가** (현재 `mudyogu-v28`)
2. GitHub `main` 브랜치에 올린다(push)
3. 끝. `.github/workflows/deploy.yml` 이 자동으로
   `flutter analyze` → 외부 URL 검사 → `./build.sh` → 상대경로 패치 → GitHub Pages 배포
4. 설치된 앱은 `version.json` 이 바뀐 걸 보고 "새 버전 있음" 배너를 띄운다

> 젠스파크 미리보기 주소(`*.sandbox.novita.ai`)는 임시 개발 서버였다. 정식 주소는 GitHub Pages.
> 주소가 바뀌면 브라우저 저장소(기록)도 새로 시작하므로, 옮길 때는 진행 코드/리포트 코드로 이전.

### 계정/저장 관련 디버깅

브라우저 DevTools 콘솔에 `[progress]`, `[settings]`, `[PWA]`, `[boot]` 접두사 로그를 붙여뒀습니다.
IndexedDB → `localstore` 데이터베이스에서 `progress_*` 박스를 직접 볼 수 있습니다.

---

## 7. 지금까지 고친 유명한 버그들 (다시 만들지 마세요)

| 증상 | 원인 | 해결 |
|---|---|---|
| `HiveError: Box not found` | `runApp()` 이 `store.init()` 보다 먼저 실행되어 첫 프레임에서 박스를 읽음 | `main()` 을 async 로 바꾸고 **`await store.init()` 후 runApp** |
| 저장 코드가 사라짐 | 진행 박스가 웹에서 간헐적으로 안 열림 | `settings` 박스에 **미러 저장**(`saveCode::<id>`) + `_put()` 3회 재시도 |
| 테마가 한 번 깜빡임 | 위와 같은 이유 | 위와 동일 |
| **전체화면에서 나갈 수 없음** | iframe 이 Flutter 위 레이어라 버튼 클릭을 먹음 | `Stack` → **`Column` + 44px 컨트롤 바** |
| 게임 캔버스가 찌그러짐 | `height:550px` + `flex-shrink:1` → 세로만 축소 | `flex:1 1 auto; min-height:0; aspect-ratio:1000/550` |
| 게임 하단 버튼이 잘림 | `justify-content:center` 가 넘칠 때 위아래를 자름 | `flex-start` + `margin-block:auto`, `@media (max-height:700px)` 보정 |
| 게임 카드가 안 보임 | `SliverGrid` 를 `Padding` 으로 감쌈 | **`SliverPadding`** 사용 |
| **게임 화면이 원본과 다름** | 게임 CSS 를 덧씌워 배치/글씨/이모지가 바뀜 + 앱이 16:9 상자에 또 넣음 | 원본으로 되돌리고 '추가만', 화면은 통째 `zoom`, 무대는 꽉 채움 |
| **전체화면 누르면 게임이 처음부터 다시 로딩** | 창 모드/전체화면이 서로 다른 Scaffold 를 돌려줘 GameHost(iframe)가 새로 만들어짐 | Scaffold 하나 + 무대 `Expanded` 에 `ValueKey('game-stage')` → 트리 모양 유지 |
| **Ctrl + 로 확대하면 게임 크기가 이상** (150%까진 그대로, 200%에서 갑자기 커짐) | LIFE/포케퀴즈 화면 맞춤이 확대된 만큼 스스로 줄어듦 + 폭 700 기준에서 툭 바뀜 | `browserZoom()` (top.outerWidth/innerWidth) 로 확대 배율을 빼고 계산 |
| **앱 화면에서 확대가 안 됨** (Ctrl+휠·터치패드 두 손가락) | Flutter 가 Ctrl+휠을 받아 preventDefault | `web/index.html` 에서 window 캡처 단계로 먼저 받아 Flutter 로 안 넘김 |
| **두 손가락 부분 확대(핀치)가 안 되거나, 하면 화면이 하얗게 깨짐** | ① Flutter 가 viewport 메타를 `user-scalable=no` 로 덮어씀 + body `touch-action:none` ② Flutter 가 앱 크기를 `visualViewport` 로 재서 확대하면 보이는 부분 크기로 쪼그라듦 | `web/index.html`: 메타 되돌리기(MutationObserver) + `touch-action: pinch-zoom` + 확대 중엔 `VisualViewport.width/height` 를 확대 전 크기로 |
| LIFE: 엔딩에서 부상 상태 오버롤 / 마지막 주 부상 | 원본 로직 | 맨 아래 `lifeFixes` 에서 `dayStart`·`rEnd` 감싸기 (12/24~ 부상 금지, 엔딩 때 부상 해제) |
| LIFE: '친구와 시간' 멤버가 탭 오갈 때마다 바뀜 | `rChoice()` 가 그릴 때마다 `ctxNow()` 로 무작위 재선택 | 하루 동안 고정 (`T.mudFr`) |
| **새 계정에 원래 계정 게임 기록이 그대로 보임 / 다른 기기에서 로그인 안 됨** | 계정이 이 기기에만 저장 + 게임은 localStorage 하나를 모든 계정이 같이 씀 + 저장 코드 미러도 공용 | Supabase 온라인 계정 + 계정별 localStorage 보관함(vault) + 계정별 미러 |
| LIFE: MY TEAM 무한 복사 | 엔딩 화면이 뜨자마자 자동 등록 → 저장 안 하고 12/29 로 돌아가 반복 | 엔딩 뒤 슬롯 저장 때만 등록 + `runId` 로 같은 1학년은 한 번만 |
| **LIFE 아래가 잘림 (스크롤 안 됨)** | iframe 에 `scrolling="no"` | 속성 제거. 스크롤 막기는 게임 CSS 에서 |
| 한일전: 12 를 깨면 13·14 가 같이 열림 | 원본 `renderStageMenu` 의 `(i === 14 && maxUnlockedStage >= 13)` | 빌더 TAIL_JS `lockStage14` 가 메뉴를 그린 뒤 14 버튼을 다시 잠금 (13 클리어·최고 14 이상·14 클리어 기록이면 열림) |
| 한일전 기록이 15스테이지에서만 저장됨 | 동기화 호출이 Stage 15 클리어에만 있었음 | `goToMenu` 를 감싸 진행이 바뀌면 항상 저장 |
| **오프라인에서 앱이 멈춤** | ① 서비스워커 2개 동시 등록 ② 캐너스킷을 CDN 에서 받음 ③ `assets/` 미캐시 | `patch_web.py` 로 SW 통합 + 로컬 canvaskit + 사전 캐시 확장 |

---

## 8. 디자인 규칙

- **브랜드 컬러**: `#2FCC8B` (민트 그린). `AppColors.brand`
- **폰트**: NanumSquareRound (400 / 700)
- **스타일**: 클린/파스텔. 카드 `borderRadius` 16~20, 은은한 그림자
- **테마**: 시스템 / 라이트 / 다크 3모드 (`AppThemeMode`)
- **언어**: **한국어만**
- **사운드 없음**, **광고/수익화 없음**

---

## 9. 미구현 / 남은 일

사용자가 "이따가" 라고 보류한 것들:

- **소셜 로그인** — sandbox 에 Firebase 자격증명 없음. `AuthService` 를 교체하면 됨
- **APK 빌드** — PWA 우선이므로 보류. `flutter build apk --release` 로 가능하나
  `GameHost` 가 스텁이라 **웹뷰 구현이 필요** (`lib/widgets/game_host_stub.dart`)
- **게임 수** — 현재 4개(한일전, 한(일)남 LIFE, 포케퀴즈, 타워 크래시). 원래 목표 6~10개
- **저장 데이터 확장** — 재화 / 업적 / 연속출석 / 리더보드

---

## 10. 손에 익혀야 할 명령어

```bash
cd /home/user/flutter_app

flutter analyze                 # 문법/린트 (항상 이걸 먼저)
flutter test                    # 단위 테스트
./build.sh                      # 웹 빌드 (+ 자동 패치)
python3 tools/pack_html.py      # 배포용 zip
python3 tools/verify_games.py   # 게임 파일 무결성
node --check web/service_worker.js   # SW 문법 검사
```

---

## 11. 저장소

- GitHub 저장소 (main 에 push → 자동 배포). 예전 Genspark remote 는 더 이상 쓰지 않음
- 커밋 메시지는 한국어로, `fix:` / `feat:` 접두사 사용
- 작업 단위로 자주 커밋 (빌드는 `build/` 라 gitignore 됨)

---

문의할 것이 있으면 이 저장소의 `git log` 를 보세요.
커밋 메시지에 **왜** 그렇게 고쳤는지 적어두었습니다.

---

## 12. 타워 크래시 (tower-drop) 메모

사용자 아이디어("무한의 계단 반대 버전, 2버튼 좌/우 타격, 건물 붕괴 + 무적 피버")로 Claude 가 만든 게임.
파일 하나(`web/games/tower-drop/index.html`) + 폰트 1개. 그림은 전부 캔버스 코드로 그림(외부 이미지 없음). 사운드 없음(디자인 규칙).

- **판정** (`hit()`): 누른 쪽으로 옮김 → 지금 층 철골이 그쪽이면 쾅 → 지금 층 파괴 → 새로 올라온 층 철골이 내 쪽이면 쾅
- **층 생성** (`makeFloor()`): 바로 위층과 **반대쪽** 철골은 만들지 않음(피할 수 없는 배치 금지)
- **게이지**: 한 번 부술 때 `REFILL`(0.065), 초당 감소 = `REFILL × needRate(층)` (1.5회/초 → 최대 6.6회/초)
- **특수 층**: 금고(너트) · 시계(게이지 +0.32) · 강철(2타, ZONE 2부터). TNT 는 너무 어렵다는 의견으로 2026-10-24 삭제
- **1000층마다**(`FEVER_FLOORS`) `startFever()`: (처음엔 100층마다였으나 피버가 끝없이 이어져서 2026-10-24 변경) 보이는 탑 전체가 파편으로 터지고 새 건물이 아래서 솟음 → 6초 무적, 한 번에 2층, 철골도 부숨.
  끝날 때 아래 4층 철골을 충격파로 정리(끝나자마자 억울한 죽음 방지)
- **구역 테마 7개**(`ZONES`)는 그대로 100층마다(`ZONE_FLOORS`) 바뀌고 7개 뒤엔 다시 처음부터 (ZONE 번호는 계속 증가)
- **저장**: localStorage `towerdrop.v1` · 진행 코드 `MUDX1|tower-drop|` + base64(JSON {v, at, keys:{towerdrop.v1: …}})
- **캐릭터 9종**(겉모습만, 너트로 구매). 사용자 추가안 3종: TKD마스터(발차기, 10,000) · 창기(뽀글머리·안경, 커터칼, 30,000) · 꽉(배치기, 100,000).
  공격 방식(`tool`)이 `kick`/`belly` 면 팔 대신 다리/몸통이 움직임 (`drawChar` 의 `atk`) · **업적 15개**(너트 보상)
- **설정**(⚙️, 타이틀·일시정지): 좌/우 키를 쪽마다 2개까지 바꿈(기본 ←A / →D), 진동 켜기/끄기.
  기기별 설정이라 localStorage `towerdrop.settings` 에 따로 저장(진행 코드에 안 들어감). P·Esc·Space·Enter 는 못 씀
- **첫 접속 선물**: 너트 100,000개 한 번 (`seen.gift100k` — 합칠 때 합집합·너트는 큰 쪽이라 두 기기여도 두 번 안 받음)
- **부활**: 300층 이상에서 죽으면 8초 안에 부활 선택. 한 판 2번, 300 → 500 너트. 부활하면 아래 5층 철골 치우고 게이지 가득,
  첫 타격 전까진 게이지가 안 줄어듦. 부활 안 할 때만 `endRun()` (기록·통계는 판이 진짜 끝날 때 한 번)
- **최고 기록 초기화**(설정, 3초 안에 두 번): `best=0`, `bestEpoch=지금` + `MUD.resetBest()` 로 앱 쪽 최고 기록도 0.
  합칠 때 `bestEpoch` 가 더 나중인 쪽의 최고 기록이 이김(옛 기록·옛 코드가 초기화를 되살리지 않게)
- **전체 랭킹**(🌏, 타이틀·결과 화면): Supabase 프로젝트 `nvpvdkxovknhqglfbhmv` (사용자 계정). 표/함수 SQL 은 `docs/supabase-ranking.sql`.
  - 게임엔 anon 키만 있음(웹 공개용). 표는 읽기만 허용, 쓰기는 `tower_submit()` 함수로만 → id + 비밀값(sha256 비교)이 맞아야 내 줄을 고침, 서버가 큰 기록만 남김
  - 내 신분증 `data.rank {id, secret, name}` 은 진행 코드에 같이 들어가 다른 기기에서도 같은 줄. 닉네임 정하기 전엔 안 올라감
  - 판이 끝날 때 자동 등록 + 결과 화면에 '전체 N위'. 탭: 최고 층 / 누적 층(stats.floors). TOP 100 + 100위 밖이면 내 줄 따로
  - **시즌**: 랭킹엔 게임 최고 기록이 아니라 `data.rank.best/total`(이번 시즌 기록)을 올림. `RANK_SEASON`(지금 2)이 바뀌면 0 부터.
    랭킹 초기화 = RANK_SEASON +1 배포 + SQL 함수 시즌 숫자 변경 + `delete from tower_ranking` (방법은 sql 파일 끝)
  - 게임 안 '최고 기록 초기화'와 랭킹은 따로 (랭킹은 시즌 안에서 서버 greatest)
  - 이 작업 환경(클라우드)에선 supabase 주소가 막혀 있어 Playwright 가짜 서버(page.route)로 확인함
- 판이 끝나도 `isGameOver:false` 로 보냄: 앱의 '기록 저장됨' 알림이 결과 화면과 겹쳐서 (점수·상태·시간 저장은 그대로)
- 테스트용으로 `window.__towerDrop` 에 상태를 열어 둠 (Playwright 봇이 안전한 쪽을 골라 100층·피버까지 자동 확인 가능)

