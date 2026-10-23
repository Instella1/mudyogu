# 게임 개발 규약 (Game Spec)

> 뮤됴구에 들어가는 HTML5 게임을 만들 때 지켜야 할 것.
> Flutter 코드를 몰라도 이 문서만 지키면 게임을 추가할 수 있습니다.

---

## 1. 최소 요구사항

```
web/games/<게임id>/
└── index.html      ← 이거 하나로 끝낼 수 있음 (CSS/JS 인라인)
```

추가 파일이 필요하면 같은 폴더에 두세요. **모든 경로는 상대경로.**

```
web/games/<게임id>/
├── index.html
├── style.css
├── game.js
└── assets/          ← 이미지/사운드 (외부 URL 금지)
```

---

## 2. 절대 규칙 3가지

### ① 외부 URL 금지
CDN 폰트, 외부 이미지, 외부 스크립트 **모두 금지**. 오프라인에서 게임이 깨집니다.

```html
<!-- ❌ -->
<link href="https://fonts.googleapis.com/css2?family=..." rel="stylesheet">

<!-- ✅ 폰트가 필요하면 파일로 넣고 @font-face -->
<style>
@font-face {
  font-family: 'MyFont';
  src: url('./fonts/MyFont.woff2') format('woff2');
}
</style>
```

### ② 원본 모양을 바꾸지 말 것 + 비율이 깨지지 않게
앱은 게임에 **남는 화면 전체**를 줍니다(16:9 상자 없음). 화면 크기는 게임마다 다르니,
- 원래 반응형인 게임은 그대로 두고,
- 고정 크기로 만든 게임은 배치를 바꾸지 말고 **화면 전체를 `zoom` 으로 통째로 맞추세요.**
  (예시: `web/games/haniljeon/index.html` 맨 아래 `fitToScreen`)

아래는 새로 만드는 게임에서 캔버스를 비율대로 늘릴 때 쓰는 패턴입니다. 찌그러지면 안 됩니다.

```css
/* 게임 루트: 부모가 준 공간을 정확히 채우기만 */
html, body { margin:0; height:100%; overflow:hidden; }

/* 게임 영역 */
#game {
  height: 100%;
  display: flex;
  flex-direction: column;
}

/* 캔버스: 높이는 flex 가 정하고 폭은 비율로 유도 */
#canvas-wrap {
  flex: 1 1 auto;
  min-height: 0;
  width: auto;
  aspect-ratio: 16 / 9;   /* ← 카탈로그의 aspect 와 일치시킬 것 */
  margin: 0 auto;
  position: relative;
}
#canvas-wrap canvas {
  position: absolute;
  inset: 0;
  width: 100% !important;
  height: 100% !important;
}
```

> ⚠️ `height: 550px` 처럼 **고정 height 를 주면** 세로만 줄어들어 찌그러집니다.

### ③ 하단이 잘리지 않게
`justify-content: center` 는 내용이 넘치면 **위아래를 잘라냅니다.**

```css
/* ❌ 넘치면 하단 버튼이 사라짐 */
body { display:flex; justify-content:center; }

/* ✅ 넘치면 스크롤되게 */
body {
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  overflow-y: auto;
}
```

---

## 3. 뮤됴구 SDK 연동

### 스크립트 추가

```html
<script src="../mudyogu-sdk.js"></script>
```

> 단독 실행 시 404 가 나도 괜찮습니다. 아래처럼 방어하면 됩니다.

### 기본 세팅

```html
<script>
  // SDK 가 없으면(단독 실행) 더미로 대체
  const MUD = window.MudyoguSDK
    ? MudyoguSDK.create()
    : { isEmbedded:false, ready(){}, save(){}, saveCode(){}, requestCode(){},
        onCode(){}, onInit(){}, onControl(){}, score(){}, vibrate(){} };
</script>
```

### 전체 사용 예시

```html
<script>
(function () {
  const MUD = window.MudyoguSDK
    ? MudyoguSDK.create()
    : { isEmbedded:false, ready(){}, save(){}, saveCode(){}, requestCode(){},
        onCode(){}, onInit(){}, onControl(){}, score(){}, vibrate(){} };

  let best = 0;
  let maxLevel = 1;

  // ── 앱이 보낸 상태 복원 ──────────────────────────────
  MUD.onInit(function (payload) {
    if (payload.bestScore) best = payload.bestScore;
    if (payload.state && payload.state.maxLevel) maxLevel = payload.state.maxLevel;
    // payload.savedCode 는 앱이 보관하던 백업 문자열 (아래 6번 참고)
    updateHud();
  });

  // ── 앱이 일시정지/재개를 시킬 때 ─────────────────────
  MUD.onControl(function (msg) {
    if (msg.type === 'pause')  stopLoop();
    if (msg.type === 'resume') startLoop();
  });

  // ── 준비 완료 알림 (한 번만) ─────────────────────────
  MUD.ready();

  // ── 진행 저장 ─────────────────────────────────────────
  function saveProgress(isGameOver) {
    MUD.save({
      score: best,
      state: { maxLevel: maxLevel },
      isGameOver: !!isGameOver
    });
  }

  // 게임오버 시
  function gameOver() {
    score += 10;                       // 이번 판 점수
    if (score > best) best = score;
    saveProgress(true);
  }
})();
</script>
```

---

## 4. 조작 (입력)

**화면에 방향 버튼을 그리지 마세요.** 플랫폼별로 자연스러운 방식을 씁니다.

```css
/* 터치 패드는 거친 포인터 기기에서만 */
#touch-pad { display: none; }
@media (pointer: coarse) {
  #touch-pad { display: grid; /* ... */ }
}
@media (pointer: fine) {
  /* 키보드 안내 문구 표시 */
  #key-hint { display: block; }
}
```

```js
// 키보드 (PC/크롬북)
window.addEventListener('keydown', e => {
  const k = e.key.toLowerCase();
  if (['arrowup','arrowdown','arrowleft','arrowright','w','a','s','d'].includes(k)) {
    e.preventDefault();
  }
  keys[k] = true;
});
```

---

## 5. 임베드 모드 감지

앱 안에서 실행되면 iframe URL 에 `?mudToken=...&mudEmbed=1` 이 붙습니다.

```js
if (MUD.isEmbedded) {
  document.documentElement.classList.add('mud-embed');
}
```

```css
/* 앱 안에서는 여백을 줄이고 스크롤 없이 한 화면에 */
html.mud-embed body {
  padding: 4px;
  overflow: hidden;
}
```

SDK 를 안 쓸 때는 직접 확인:

```js
const isEmbedded = new URLSearchParams(location.search).get('mudEmbed') === '1';
```

---

## 6. 저장 코드 (다른 기기로 이어하기)

localStorage 는 **그 브라우저에만** 남습니다. 기기를 바꾸면 사라집니다.
그래서 게임이 직접 만든 **문자열 백업**을 앱 계정에 보관시킵니다.

```js
// ── 저장 코드 만들기 ──────────────────────────────
function buildSaveCode() {
  const payload = { v:1, best, maxLevel, at: Date.now() };
  const json = JSON.stringify(payload);
  const bytes = new TextEncoder().encode(json);
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  }
  return 'MYG1|' + btoa(bin);          // 접두사로 게임 구분
}

// ── 코드로 복원 ──────────────────────────────────
function applySaveCode(code) {
  try {
    const raw = String(code || '').trim();
    if (!raw.startsWith('MYG1|')) return false;
    const bin = atob(raw.slice(5));
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    const obj = JSON.parse(new TextDecoder().decode(bytes));
    if (obj.best) best = obj.best;
    if (obj.maxLevel) maxLevel = obj.maxLevel;
    return true;
  } catch (e) { return false; }
}

// ── 앱에 보관시키기 (저장할 때마다) ────────────────
function pushToApp() {
  MUD.saveCode({ code: buildSaveCode(), label: '진행 코드' });
}

// ── 앱이 보관하던 코드 받기 ────────────────────────
MUD.onCode(function (code) {
  if (code) applySaveCode(code);
});

// init 에도 실려 옵니다
MUD.onInit(function (payload) {
  if (payload.savedCode) applySaveCode(payload.savedCode);
});

// 원할 때 달라고 요청
MUD.requestCode();
```

**접두사 규칙**: `<게임약자>1|` 형태로 게임마다 다르게.
- 한일전: `HIJ1|`
- 한(일)남 LIFE: 접두사 없이 base64 (기존 호환)
- 포케퀴즈: `PKQ1|` (포획 목록은 합치고, 티켓/프로필/기록은 새 기기일 때만 가져옴)
- 새 게임: `<ID대문자>1|`

---

## 7. 자체 테스트 체크리스트

게임을 올리기 전에:

- [ ] `index.html` 을 브라우저로 직접 열어도 플레이된다 (단독 실행)
- [ ] 외부 URL 요청이 0건이다 (DevTools Network 탭에서 확인)
- [ ] 크롬북 1366×768 에서 캔버스가 찌그러지지 않는다
- [ ] 모바일 390×844 에서 하단이 잘리지 않는다
- [ ] 화면을 줄여도 세로 스크롤이 생기지 않는다 (또는 자연스럽다)
- [ ] 게임오버 시 콘솔에 에러가 없다
- [ ] 키보드 / 터치 둘 다 동작한다
- [ ] 새로고침해도 localStorage 로 진행이 남아 있다

앱 안에서 확인:

- [ ] 홈 카드가 뜨고 클릭하면 열린다
- [ ] 앱바에 최고점이 표시된다
- [ ] 한 판 끝내면 "기록 저장됨" 토스트가 뜬다
- [ ] 전체화면 진입 → 창모드 → 나가기 모두 동작한다
- [ ] 앱을 껐다 켜도 기록이 남아 있다

---

## 8. 참고할 실제 게임

이미 잘 동작하는 게임 2개가 있습니다. 베낄 부분을 찾아보세요.

| 파일 | 참고할 것 |
|---|---|
| `web/games/haniljeon/index.html` | 캔버스 비율 처리, 스테이지 UI, `HIJ1|` 저장코드 |
| `web/games/hanilnam-life/index.html` | 폰트 로컬 번들, DOM 기반 UI, 긴 스크롤 레이아웃 |

---

## 9. 등록

게임 파일을 다 만들었으면 `docs/HANDOFF.md` 6번 "새 게임 추가" 를 보세요.
가장 빠른 방법:

```bash
python3 tools/add_game.py ~/Downloads/내게임.zip \
    --id mygame --title "내 게임" --tagline "한 줄 소개"
```
