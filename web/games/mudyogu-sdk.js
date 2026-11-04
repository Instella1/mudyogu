/*!
 * 뮤됴구 게임 SDK v1
 * ------------------------------------------------------------------
 * HTML5 게임과 뮤됴구 앱(호스트)을 연결합니다.
 *
 * 사용법 (게임 index.html 에서)
 *   <script src="../mudyogu-sdk.js"></script>
 *   <script>
 *     const MUD = MudyoguSDK.create();
 *     MUD.onInit((payload) => { if (payload.state) restore(payload.state); });
 *     MUD.save({ score: 120, state: { level: 3 }, isGameOver: true });
 *   </script>
 *
 * 호스트 규약
 *   - 게임 → 호스트: { mudyogu: <token>, type: 'ready' | 'progress' | ... }
 *   - 호스트 → 게임: { type: 'init' | 'pause' | 'resume' | 'state' }
 * ------------------------------------------------------------------ */
(function (global) {
  'use strict';

  function create(options) {
    var opts = options || {};
    var params = new URLSearchParams(global.location.search);
    var token = params.get('mudToken') || '';
    var embedded = params.get('mudEmbed') === '1';
    var initHandlers = [];
    var controlHandlers = [];
    var codeHandlers = [];
    var authHandlers = [];
    var lastPayload = null;
    var readySent = false;

    function post(message) {
      if (!embedded || !global.parent || global.parent === global) return;
      message.mudyogu = token;
      try {
        global.parent.postMessage(message, '*');
      } catch (err) {
        /* 무시 */
      }
    }

    /** 게임이 준비되었음을 알립니다. */
    function ready() {
      if (readySent) return;
      readySent = true;
      post({ type: 'ready' });
    }

    /**
     * 진행상황 저장 요청.
     * @param {{score?:number, state?:object, playSeconds?:number, isGameOver?:boolean}} payload
     */
    function save(payload) {
      var data = payload || {};
      post({
        type: 'progress',
        score: typeof data.score === 'number' ? data.score : undefined,
        state: data.state,
        playSeconds: typeof data.playSeconds === 'number' ? data.playSeconds : undefined,
        isGameOver: data.isGameOver === true
      });
    }

    /**
     * 게임이 직접 만든 "저장 코드" 를 앱에 보관시킵니다.
     *
     * 다른 기기/브라우저로 옮길 때 쓰는 문자열(예: 한일남 LIFE 의 리포트 코드)을
     * 앱이 계정에 묶어 보관하고, 나중에 같은 코드로 복원할 수 있게 합니다.
     * 문자열이 너무 길면 그대로 저장하되, 앱은 앞/뒤 일부만 표시합니다.
     *
     * @param {{gameId?:string, code:string, label?:string}} payload
     */
    function saveCode(payload) {
      var data = payload || {};
      if (typeof data.code !== 'string' || !data.code) return;
      post({
        type: 'saveCode',
        code: data.code,
        label: typeof data.label === 'string' ? data.label : '',
        // 코드가 매우 길 수 있으므로 앱에서 잘라 보관
        codeLength: data.code.length
      });
    }

    /** 앱이 보관 중인 저장 코드를 달라고 요청합니다. */
    function requestCode() {
      post({ type: 'requestCode' });
    }

    /** 앱에 보관된 최고 기록을 0 으로 (게임 안 '최고 기록 초기화' 용) */
    function resetBest() {
      post({ type: 'resetBest' });
    }

    /**
     * 앱의 온라인 계정(Supabase) 로그인 정보를 요청합니다. 답은 onAuth 로 옵니다.
     *   { signedIn:true, uid, accessToken, expiresAt(ms) }
     *   { signedIn:false, reason:'guest'|'local'|'offline' }  (앱 밖에서 열면 reason:'standalone')
     */
    function requestAuth() {
      if (!embedded) {
        setTimeout(function () { emitAuth({ type: 'auth', signedIn: false, reason: 'standalone' }); }, 0);
        return;
      }
      post({ type: 'requestAuth' });
    }

    function onAuth(handler) {
      if (typeof handler === 'function') authHandlers.push(handler);
    }

    function emitAuth(data) {
      for (var a = 0; a < authHandlers.length; a++) {
        try {
          authHandlers[a](data);
        } catch (err) {
          /* 무시 */
        }
      }
    }

    /** 최고 기록 갱신 등 단순 점수 전송 */
    function score(value) {
      save({ score: value });
    }

    function onInit(handler) {
      if (typeof handler !== 'function') return;
      initHandlers.push(handler);
      if (lastPayload) handler(lastPayload);
    }

    function onControl(handler) {
      if (typeof handler === 'function') controlHandlers.push(handler);
    }

    /** 앱이 보관하던 저장 코드를 넘겨받는 핸들러 */
    function onCode(handler) {
      if (typeof handler === 'function') codeHandlers.push(handler);
    }

    global.addEventListener('message', function (event) {
      var data = event.data;
      if (!data || typeof data !== 'object' || typeof data.type !== 'string') return;

      if (data.type === 'init') {
        lastPayload = data;
        for (var i = 0; i < initHandlers.length; i++) {
          try {
            initHandlers[i](data);
          } catch (err) {
            /* 무시 */
          }
        }
        return;
      }

      if (data.type === 'saveCode') {
        // 앱 → 게임: 보관 중이던 저장 코드 전달
        lastPayload = lastPayload || {};
        lastPayload.savedCode = data.code || '';
        for (var k = 0; k < codeHandlers.length; k++) {
          try {
            codeHandlers[k](data.code || '', data.label || '');
          } catch (err) {
            /* 무시 */
          }
        }
        return;
      }

      if (data.type === 'auth') {
        // 로그인 토큰은 앱(부모 창)이 보낸 것만 받는다
        if (event.source !== global.parent) return;
        emitAuth(data);
        return;
      }

      if (data.type === 'pause' || data.type === 'resume' || data.type === 'state') {
        for (var j = 0; j < controlHandlers.length; j++) {
          try {
            controlHandlers[j](data);
          } catch (err) {
            /* 무시 */
          }
        }
      }
    });

    function vibrate(ms) {
      if (opts.vibrate === false) return;
      if (global.navigator && typeof global.navigator.vibrate === 'function') {
        try {
          global.navigator.vibrate(ms || 12);
        } catch (err) {
          /* 무시 */
        }
      }
    }

    return {
      isEmbedded: embedded,
      token: token,
      ready: ready,
      save: save,
      saveCode: saveCode,
      requestCode: requestCode,
      resetBest: resetBest,
      requestAuth: requestAuth,
      onAuth: onAuth,
      onCode: onCode,
      score: score,
      onInit: onInit,
      onControl: onControl,
      vibrate: vibrate
    };
  }

  global.MudyoguSDK = { create: create };
})(window);
