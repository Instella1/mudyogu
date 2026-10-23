"""원본 한일전 + 뮤됴구 연동만 덧붙여 web/games/haniljeon/index.html 생성"""
import sys
ORIG, CUR, OUT = sys.argv[1:4]
MODE = sys.argv[4] if len(sys.argv) > 4 else 'site'   # site | standalone
o = open(ORIG, encoding='utf-8').read().split('\n')
c = open(CUR, encoding='utf-8').read().split('\n')
L = lambda a, b: c[a-1:b]          # 현재 파일 1-based 구간

savecode_modal = L(307, 339)
touch_pad_html = [s[4:] if s.startswith('    ') else s for s in L(356, 362)]
sdk_js = L(559, 801)

# ── 진행 코드 불러오기: 덮어쓰기 → '합치기' (아무것도 잃지 않게) ──
_js = '\n'.join(sdk_js)
_old_start = _js.index("                if (typeof obj.maxStage === 'number') {")
_old_end = _js.index("                try { renderStageMenu(); } catch (e) {}")
_new = """                // 합치기: 최고 스테이지는 큰 쪽, 클리어는 모두, 별점은 스테이지별 최고, 업적은 하나라도 달성했으면 달성
                if (typeof obj.maxStage === 'number') {
                    maxUnlockedStage = Math.max(maxUnlockedStage || 1, Math.max(1, Math.min(15, obj.maxStage)));
                    localStorage.setItem('haniljeon_max_stage', maxUnlockedStage);
                }
                if (Array.isArray(obj.cleared)) {
                    obj.cleared.forEach(function (n) { if (!clearedStages.includes(n)) clearedStages.push(n); });
                    clearedStages.sort(function (a, b) { return a - b; });
                    localStorage.setItem('haniljeon_cleared_stages', JSON.stringify(clearedStages));
                }
                if (obj.stars && typeof obj.stars === 'object') {
                    Object.keys(obj.stars).forEach(function (k) {
                        const v = Number(obj.stars[k]) || 0;
                        if (v > (Number(stageStars[k]) || 0)) stageStars[k] = v;
                    });
                    localStorage.setItem('haniljeon_stage_stars', JSON.stringify(stageStars));
                }
                if (obj.ach && typeof obj.ach === 'object') {
                    Object.keys(obj.ach).forEach(function (k) { if (obj.ach[k] && !achievements[k]) achievements[k] = obj.ach[k]; });
                    localStorage.setItem('haniljeon_achievements', JSON.stringify(achievements));
                }
                if (obj.keys && typeof obj.keys === 'object') {
                    userKeys = Object.assign(userKeys, obj.keys);
                }
"""
_js = _js[:_old_start] + _new + _js[_old_end:]
sdk_js = _js.split('\n')

HEAD_ADD = '''    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
    <meta name="theme-color" content="#222222">
    <script src="../mudyogu-sdk.js"></script>'''

CSS_ADD = '''
        /* ===================== 뮤됴구 추가 =====================
           원본 모양은 그대로 두고, 화면 크기에 맞춰 '통째로' 확대/축소만 한다.
           (배치를 바꾸지 않는다 — 아래 fitToScreen 스크립트가 zoom 을 계산)   */
        html { background-color: #222; }
        #menu-screen.active, #game-screen.active { display: flow-root; margin: 0 auto; }

        /* 터치 버튼: 폰/태블릿(손가락 입력)에서만, 게임 화면일 때만 보임 */
        #touch-pad { display: none; }
        @media (pointer: coarse) {
            #touch-pad.show {
                display: grid; grid-template-columns: repeat(3, 1fr);
                grid-template-areas: ". up ." "left atk right" ". down .";
                gap: 8px; width: min(86vw, 300px); margin: 10px auto 6px;
                touch-action: none; user-select: none; -webkit-user-select: none;
            }
            #touch-pad button {
                aspect-ratio: 1 / 1; border-radius: 16px; color: #fff;
                background: rgba(255,255,255,.10); border: 1.5px solid rgba(255,255,255,.22);
                font-size: 20px; font-weight: bold; display: flex; align-items: center; justify-content: center;
                -webkit-tap-highlight-color: transparent; transition: background .08s, transform .08s;
            }
            #touch-pad button.active { background: #e74c3c; border-color: #ff8a7a; transform: scale(.94); }
            #touch-pad .pad-up { grid-area: up; }
            #touch-pad .pad-down { grid-area: down; }
            #touch-pad .pad-left { grid-area: left; }
            #touch-pad .pad-right { grid-area: right; }
            #touch-pad .pad-atk { grid-area: atk; background: rgba(231,76,60,.34); border-color: rgba(255,140,120,.6); font-size: 13px; }
        }
        /* 폰을 가로로 눕혔을 때: 게임 옆 빈 공간에 떠 있게 */
        @media (pointer: coarse) and (orientation: landscape) {
            #touch-pad.show { position: fixed; right: 10px; bottom: 10px; margin: 0; width: min(26vw, 190px); gap: 6px; z-index: 50; opacity: .9; }
        }'''

MENU_BTN = '''            <button onclick="openSaveCode()" style="background: #2980b9;">💾 진행 코드</button>'''

TAIL_JS = '''
    <script>
        /* ===================== 뮤됴구: 기록 자동 동기화 =====================
           스테이지를 깨거나 포기하고 메뉴로 돌아올 때마다, 진행이 바뀌었으면
           앱에 기록(점수/상태)과 진행 코드를 보낸다. (모든 스테이지 공통) */
        (function () {
            function snapshotKey() {
                try { return JSON.stringify([clearedStages, stageStars, maxUnlockedStage, achievements]); }
                catch (e) { return ''; }
            }
            let lastKey = snapshotKey();
            function syncIfChanged() {
                const key = snapshotKey();
                if (key && key !== lastKey) {
                    lastKey = key;
                    try { mudyoguSyncProgress(true); } catch (e) {}
                    try { pushSaveCode(true); } catch (e) {}
                }
            }
            const originalGoToMenu = goToMenu;
            goToMenu = function () {
                const r = originalGoToMenu.apply(this, arguments);
                syncIfChanged();
                return r;
            };
            // '진행 코드 → 불러오기'로 다른 곳의 기록을 옮겨 왔을 때도 바로 앱에 저장
            // 켤 때 이미 있는 기록도 앱 계정에 한 번 보관 (다른 기기에서 자동 복원되게)
            setTimeout(function () {
                try { if (clearedStages.length || maxUnlockedStage > 1) pushSaveCode(true); } catch (e) {}
            }, 1500);
            const originalImport = importSaveCode;
            importSaveCode = function () {
                const r = originalImport.apply(this, arguments);
                syncIfChanged();
                return r;
            };
        })();

        /* ===================== 뮤됴구: 화면 맞춤 =====================
           원본은 1000x550 캔버스 기준으로 만들어져 있다. 배치는 건드리지 않고
           현재 화면(메뉴/게임)을 통째로 zoom 해서 창 안에 최대한 크게 넣는다. */
        (function fitToScreen() {
            const DESIGN_W = 1008;                       // 캔버스 1000 + 테두리 4x2
            const embedded = new URLSearchParams(location.search).get('mudEmbed') === '1';
            const MAX_ZOOM = embedded ? 1.5 : 1;         // 앱 안에서는 큰 화면이면 키운다
            const menu = document.getElementById('menu-screen');
            const game = document.getElementById('game-screen');
            const pad = document.getElementById('touch-pad');
            const coarse = window.matchMedia('(pointer: coarse)');

            function fit() {
                const scr = game.classList.contains('active') ? game
                          : menu.classList.contains('active') ? menu : null;
                if (pad) pad.classList.toggle('show', scr === game);
                if (!scr) return;

                // 폰 가로: 터치 버튼이 오른쪽에 떠 있으므로 그만큼 비워 두고 왼쪽에 맞춘다
                document.body.style.paddingRight = '';
                if (pad && scr === game && coarse.matches) {
                    const ps0 = getComputedStyle(pad);
                    if (ps0.display !== 'none' && ps0.position === 'fixed') {
                        document.body.style.paddingRight = (pad.getBoundingClientRect().width + 20) + 'px';
                    }
                }

                scr.style.zoom = '1';
                scr.style.width = DESIGN_W + 'px';
                const bs = getComputedStyle(document.body);
                const padX = parseFloat(bs.paddingLeft) + parseFloat(bs.paddingRight);
                const padY = parseFloat(bs.paddingTop) + parseFloat(bs.paddingBottom);

                let reserve = 0;                         // 폰 세로: 터치 버튼 자리 확보
                if (pad && scr === game && coarse.matches) {
                    const ps = getComputedStyle(pad);
                    if (ps.display !== 'none' && ps.position !== 'fixed') {
                        reserve = pad.getBoundingClientRect().height
                                + parseFloat(ps.marginTop) + parseFloat(ps.marginBottom);
                    }
                }

                const h = scr.offsetHeight || 1;
                let z = Math.min((window.innerWidth - padX) / DESIGN_W,
                                 (window.innerHeight - padY - reserve) / h,
                                 MAX_ZOOM);
                z = Math.max(z, 0.2);
                scr.style.zoom = String(Math.floor(z * 1000) / 1000);
            }

            let queued = false;
            function schedule() {
                if (queued) return;
                queued = true;
                requestAnimationFrame(function () { queued = false; fit(); });
            }
            const mo = new MutationObserver(schedule);
            mo.observe(menu, { attributes: true, attributeFilter: ['class'] });
            mo.observe(game, { attributes: true, attributeFilter: ['class'] });
            window.addEventListener('resize', schedule);
            window.addEventListener('orientationchange', schedule);
            window.mudyoguFit = fit;
            fit();
        })();
    </script>'''

if MODE == 'standalone':
    HEAD_ADD = HEAD_ADD.replace('\n    <script src="../mudyogu-sdk.js"></script>', '')
out = []
for i, line in enumerate(o, start=1):
    if i == 5 and line.strip().startswith('<title>'):
        out.append(HEAD_ADD)
    if line.strip() == '</style>' and i < 60:
        out.append(CSS_ADD)
    if 'onclick="openAchievements()"' in line and 'menu' not in line:
        out.append(line); out.append(MENU_BTN); continue
    out.append(line)
    if i == 88:                       # 업적 모달 끝 </div>
        out.append(''); out.extend(savecode_modal)
    if i == 105:                      # #game-screen 끝 </div>
        out.append(''); out.extend(touch_pad_html)
    if i == 298:                      # goToMenu() 정의 끝
        out.append(''); out.extend(sdk_js)

# </body> 직전에 TAIL_JS
idx = max(k for k, s in enumerate(out) if s.strip() == '</body>')
out[idx:idx] = TAIL_JS.split('\n')
open(OUT, 'w', encoding='utf-8').write('\n'.join(out))
print('ok', len(out), 'lines')
