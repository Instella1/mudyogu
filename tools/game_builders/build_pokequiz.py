"""원본 포케퀴즈 + 뮤됴구 연동만 덧붙여 web/games/pokequiz/index.html 생성"""
import sys
ORIG, OUT = sys.argv[1:3]
MODE = sys.argv[3] if len(sys.argv) > 3 else 'site'   # site | standalone
s = open(ORIG, encoding='utf-8').read()

# 1) 외부 리소스 → 로컬 (오프라인). 이 4줄만 바뀌고 나머지 원본 줄은 그대로.
ext = '''<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Black+Han+Sans&family=Gothic+A1:wght@400;500;700;900&family=Space+Mono:wght@400;700&display=swap" rel="stylesheet">
<script src="https://cdnjs.cloudflare.com/ajax/libs/peerjs/1.5.4/peerjs.min.js"></script>'''
loc = '''<!-- 뮤됴구: 오프라인용 로컬 폰트 / 라이브러리 (원본은 Google Fonts, cdnjs peerjs 1.5.4) -->
<link rel="stylesheet" href="fonts/fonts.css">
<script src="vendor/peerjs.min.js"></script>'''
assert s.count(ext) == 1
if MODE == 'site':
    s = s.replace(ext, loc)

TAIL = r'''
<!-- ===================== 뮤됴구 연동 (원본 줄은 그대로, 아래만 추가) ===================== -->
<script src="../mudyogu-sdk.js"></script>
<script>
(function () {
  var MUD = window.MudyoguSDK ? window.MudyoguSDK.create() : null;
  if (MUD) {
    window.MUD = MUD;
    if (MUD.isEmbedded) document.documentElement.classList.add('mud-embed');
  }

  /* ── 진행 코드 (다른 기기로 이어하기) ─────────────────────────────
     포획 목록 + 티켓 + 프로필 + 배틀 기록을 문자열로 만들어 앱 계정에 보관한다. */
  var CODE_PREFIX = 'PKQ1|';
  function b64e(str) {
    var bytes = new TextEncoder().encode(str), bin = '';
    for (var i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    return btoa(bin);
  }
  function b64d(b) {
    var bin = atob(b), bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return new TextDecoder().decode(bytes);
  }
  function buildCode() {
    return CODE_PREFIX + b64e(JSON.stringify({
      v: 1, caught: Array.from(caught), tickets: tickets, profile: profile,
      records: records.slice(-200), at: Date.now()
    }));
  }
  // 가져오기 = 아무것도 버리지 않고 합치기
  //  · 포획 도감: 합집합
  //  · 프로필(내 고유 코드 · 닉네임): 가져온 것으로 (옮겨 온 곳의 '나'를 그대로 이어감)
  //  · 대전 기록: 합치기 (같은 기록은 한 번만), 최근 200개
  //  · 티켓: 장수/보상 단계는 큰 쪽, 지급 표시는 하나라도 받았으면 받은 것으로
  function sameRec(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
  function applyCode(code) {
    try {
      var raw = String(code || '').replace(/\s+/g, '');
      if (raw.indexOf(CODE_PREFIX) !== 0) return false;
      var o = JSON.parse(b64d(raw.slice(CODE_PREFIX.length)));
      if (!o || typeof o !== 'object') return false;
      var changed = false;
      // 이 기기(사이트)에서 아직 한 번도 안 했으면 → 티켓은 가져온 그대로 (기본 환영 티켓과 섞지 않음)
      var fresh = caught.size === 0 && records.length === 0;

      var before = caught.size;
      if (Array.isArray(o.caught)) o.caught.forEach(function (id) { if (typeof id === 'number') caught.add(id); });
      if (caught.size !== before) { origSaveCaught(); changed = true; }

      if (o.profile && o.profile.code && (o.profile.code !== profile.code || (o.profile.nick || '') !== (profile.nick || ''))) {
        profile = Object.assign({}, profile, o.profile); origSaveProfile(); changed = true;
      }

      if (Array.isArray(o.records) && o.records.length) {
        var merged = o.records.slice();
        records.forEach(function (r) { if (!merged.some(function (m) { return sameRec(m, r); })) merged.push(r); });
        merged = merged.slice(-200);
        if (!sameRec(merged, records)) { records = merged; origSaveRecords(); changed = true; }
      }

      if (o.tickets && typeof o.tickets.n === 'number') {
        var t = fresh ? {} : Object.assign({}, tickets);
        Object.keys(o.tickets).forEach(function (k) {
          var a = t[k], b = o.tickets[k];
          if (typeof b === 'number') t[k] = Math.max(typeof a === 'number' ? a : 0, b);
          else if (b && !a) t[k] = b;
        });
        if (!sameRec(t, tickets)) { tickets = t; origSaveTickets(); changed = true; }
      }

      try { updateHomeFoot(); checkTicketRewards(); updateTicketBtn(); } catch (e) {}
      return changed;
    } catch (e) { return false; }
  }

  /* ── 앱에 기록 저장 ─────────────────────────────────────────────
     점수 = 포획 수. 새로 잡았을 때만 '기록 저장됨' 알림(isGameOver). */
  var ready = false, lastSynced = -1, pushTimer = null, pendingCode = null;
  function pushCodeSoon() {
    if (!MUD || !ready) return;
    clearTimeout(pushTimer);
    pushTimer = setTimeout(function () {
      if (caught.size === 0 && records.length === 0) return;
      try { MUD.saveCode({ code: buildCode(), label: '진행 코드' }); } catch (e) {}
    }, 1200);
  }
  function sync(force) {
    if (!MUD || !ready) return;
    var n = caught.size;
    var wins = records.filter(function (r) { return r && r.result === 'win'; }).length;
    try {
      MUD.save({
        score: n,
        state: { version: 1, caught: n, tickets: tickets.n, battles: records.length, wins: wins, nick: profile.nick || '' },
        isGameOver: !!force || (lastSynced >= 0 && n > lastSynced)
      });
    } catch (e) {}
    lastSynced = n;
    pushCodeSoon();
  }

  // 원본 저장 함수를 감싼다 (원본 코드는 그대로 호출됨)
  var origSaveCaught = saveCaught, origSaveTickets = saveTickets,
      origSaveRecords = saveRecords, origSaveProfile = saveProfile;
  saveCaught = async function () { var r = await origSaveCaught.apply(this, arguments); sync(); return r; };
  saveTickets = function () { var r = origSaveTickets.apply(this, arguments); pushCodeSoon(); return r; };
  saveRecords = function () { var r = origSaveRecords.apply(this, arguments); sync(); return r; };
  saveProfile = function () { var r = origSaveProfile.apply(this, arguments); pushCodeSoon(); return r; };

  function tryApplyPending() {
    if (!ready || !pendingCode) return;
    var c = pendingCode; pendingCode = null;
    if (applyCode(c)) sync();
  }
  if (MUD) {
    MUD.onInit(function (p) { if (p && p.savedCode) { pendingCode = p.savedCode; tryApplyPending(); } });
    MUD.onCode(function (c) { if (c) { pendingCode = c; tryApplyPending(); } });
  }

  // 원본의 초기화(load*)가 끝날 때까지 기다린다 (홈 하단에 '포획 N' 이 뜨면 완료)
  var tries = 0;
  (function waitInit() {
    var foot = document.getElementById('homeFoot');
    if ((foot && foot.textContent.indexOf('포획') >= 0) || ++tries > 100) {
      ready = true;
      sync();
      tryApplyPending();
      if (MUD) { try { MUD.requestCode(); } catch (e) {} try { MUD.ready(); } catch (e) {} }
      return;
    }
    setTimeout(waitInit, 100);
  })();

  window.mudyoguBuildCode = buildCode;
  window.mudyoguApplyCode = applyCode;

  /* ── 기록저장실 화면 맨 아래에 '진행 코드 옮기기' 칸 덧붙이기 (원본 화면은 그대로) ── */
  var TA = 'width:100%;min-height:60px;margin:8px 0;padding:10px 12px;border-radius:12px;resize:vertical;' +
           'border:1.5px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);color:var(--ink);' +
           'font-family:var(--mono);font-size:11px;line-height:1.45;word-break:break-all';
  function injectTransfer() {
    var view = document.getElementById('recview');
    if (!view || view.querySelector('#mudPk')) return;
    var box = document.createElement('div');
    box.id = 'mudPk';
    box.innerHTML =
      '<div class="bt-label" style="margin-top:16px">📦 진행 코드 옮기기</div>' +
      '<div class="prof-card">' +
        '<div class="bt-sub">포획 도감 · 티켓 · 대전 기록을 코드 하나로 옮겨요. 옮길 곳(다른 기기 · 뮤됴구 사이트)의 기록저장실에 붙여넣으세요. 포획 기록은 합쳐져요.</div>' +
        '<textarea id="mudPkOut" readonly style="' + TA + '"></textarea>' +
        '<button class="bt-act" id="mudPkCopy">코드 복사</button>' +
        '<textarea id="mudPkIn" placeholder="옮겨온 코드를 붙여넣기" style="' + TA + ';margin-top:14px"></textarea>' +
        '<button class="bt-act" id="mudPkApply">불러오기</button>' +
        '<div class="bt-sub" id="mudPkMsg" style="margin-top:8px"></div>' +
      '</div>';
    view.appendChild(box);
    var out = box.querySelector('#mudPkOut'), msg = box.querySelector('#mudPkMsg');
    out.value = buildCode();
    box.querySelector('#mudPkCopy').addEventListener('click', function () {
      out.value = buildCode(); pushCodeSoon();
      navigator.clipboard.writeText(out.value).then(function () { msg.textContent = '복사했어요.'; })
        .catch(function () { out.select(); msg.textContent = '자동 복사가 안 돼요. 선택해 둔 코드를 직접 복사해 주세요.'; });
    });
    box.querySelector('#mudPkApply').addEventListener('click', function () {
      var v = box.querySelector('#mudPkIn').value.replace(/\s+/g, '');
      if (!v) { msg.textContent = '코드를 붙여넣어 주세요.'; return; }
      var before = caught.size;
      if (applyCode(v)) {
        sync(true);
        var done = '불러왔어요! 포획 ' + before + ' → ' + caught.size + '마리 · 대전 기록 ' + records.length + '개 · 티켓 ' + tickets.n + '장 · 고유 코드 ' + profile.code;
        try { renderRecords(); } catch (e) {}          // 전적/고유 코드 화면을 새 기록으로 다시 그림
        var m2 = document.getElementById('mudPkMsg'); if (m2) m2.textContent = done;
        return;
      } else {
        msg.textContent = '코드를 읽지 못했거나, 이미 같은 기록이라 바뀐 게 없어요. 처음부터 끝까지 빠짐없이 붙여넣었는지 확인해 주세요.';
      }
    });
  }
  var origRenderRecords = renderRecords;
  renderRecords = function () { var r = origRenderRecords.apply(this, arguments); try { injectTransfer(); } catch (e) {} return r; };
})();

/* ===================== 뮤됴구: 화면 맞춤 (앱 안에서만) =====================
   원본 모양은 그대로 두고 페이지 전체를 '약간' 축소해서 홈 화면이 창 높이에
   딱 맞게 한다. 다른 화면도 같은 비율, 더 긴 화면은 스크롤.
   · 키우지 않음(최대 1배) · 최소 0.6배 · 폰 세로(폭 700 미만)는 축소 안 함
   · 브라우저 확대 배율은 빼고 계산 → Ctrl + 로 확대하면 그만큼 커지고 아래로 스크롤 */
(function fitToScreen() {
  if (new URLSearchParams(location.search).get('mudEmbed') !== '1') return;
  var root = document.documentElement, homeH = 0;
  function onHome() { var h = document.getElementById('home'); return !!(h && h.classList.contains('on')); }
  function measureHome() {
    var app = document.getElementById('app'); if (!app) return 0;
    var prev = app.style.minHeight; app.style.minHeight = '0px';
    var h = app.offsetHeight; app.style.minHeight = prev;
    return h;
  }
  // 브라우저 확대(Ctrl +/-) 배율. 이걸 모르면 확대할수록 게임이 스스로 줄어들어
  // 150% 까지는 크기가 그대로이다가 폭 700 밑으로 가는 순간 갑자기 커졌다.
  // 크롬은 outerWidth 가 확대와 무관하므로 outer/inner 비율 = 확대 배율 (마우스/터치패드 기기만)
  function browserZoom() {
    try {
      if (!window.matchMedia('(pointer: fine)').matches) return 1;
      var t = window.top, r = t.outerWidth / t.innerWidth;
      if (!(r > 0) || Math.abs(r - 1) < 0.1) return 1;
      return Math.min(3, Math.max(0.3, r));
    } catch (e) { return 1; }
  }
  function fit() {
    var bz = browserZoom();
    if (window.innerWidth * bz < 700) { root.style.zoom = ''; return; }
    if (onHome() || !homeH) { root.style.zoom = '1'; homeH = measureHome() || window.innerHeight; }
    var z = Math.min(1, Math.max(0.6, (window.innerHeight * bz - 2) / homeH));
    root.style.zoom = String(Math.floor(z * 1000) / 1000);
  }
  var queued = false;
  function schedule() { if (queued) return; queued = true; requestAnimationFrame(function () { queued = false; fit(); }); }
  var home = document.getElementById('home');
  if (home) new MutationObserver(schedule).observe(home, { attributes: true, attributeFilter: ['class'] });
  window.addEventListener('resize', schedule);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(schedule);
  window.addEventListener('load', schedule);
  window.mudyoguFit = fit;
  schedule();
})();
</script>
</body>'''
if MODE == 'standalone':
    TAIL = TAIL.replace('<script src="../mudyogu-sdk.js"></script>\n', '')
assert s.count('</body>') == 1
s = s.replace('</body>', TAIL.lstrip('\n'))
open(OUT, 'w', encoding='utf-8').write(s)
print('ok')
