/*!
 * 뮤됴구 서비스워커
 * ------------------------------------------------------------------
 * 전략
 *  - 앱 셸 + 게임 + 폰트 + canvaskit: 사전 캐시(precache) → 완전 오프라인
 *  - 셸 자산: stale-while-revalidate (다음 실행에서 갱신 반영)
 *  - 게임 파일: cache-first (오프라인 완전 보장)
 *  - version.json: network-only (캐시 금지 — 업데이트 감지용)
 *
 * 주의: 모든 경로는 '상대 경로' 입니다. 하위 폴더 배포
 *       (예: https://example.com/mudyogu/) 에서도 그대로 동작합니다.
 * ------------------------------------------------------------------ */

const VERSION = 'mudyogu-v8';
const SHELL_CACHE = `${VERSION}-shell`;
const GAME_CACHE = `${VERSION}-games`;

/** 오프라인에서도 반드시 열려야 하는 핵심 자산 */
const PRECACHE_SHELL = [
  './',
  'index.html',
  'manifest.json',
  'flutter_bootstrap.js',
  'main.dart.js',
  'flutter.js',
  'version.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-512.png',
  'assets/FontManifest.json',
  'assets/AssetManifest.json',
  'assets/AssetManifest.bin',
  'assets/assets/games/catalog.json',
  'games/mudyogu-sdk.js',
  'games/mudyogu.css',
  // 한(일)남 LIFE (오프라인 폰트 포함)
  'games/hanilnam-life/index.html',
  'games/hanilnam-life/fonts/fonts.css',
  // 한일전
  'games/haniljeon/index.html',
];

/** 용량이 큰 폰트 / 그래픽 엔진 (실패해도 설치는 계속) */
const PRECACHE_FONTS = [
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/assets/fonts/NanumSquareRound-Regular.ttf',
  'assets/assets/fonts/NanumSquareRound-Bold.ttf',
  'games/hanilnam-life/fonts/BlackHanSans-Regular.woff2',
  'games/hanilnam-life/fonts/GowunBatang-Regular.woff2',
  'games/hanilnam-life/fonts/GowunBatang-Bold.woff2',
  'games/hanilnam-life/fonts/IBMPlexSansKR-Regular.woff2',
  'games/hanilnam-life/fonts/IBMPlexSansKR-SemiBold.woff2',
  'games/hanilnam-life/fonts/IBMPlexSansKR-Bold.woff2',
  'assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const shell = await caches.open(SHELL_CACHE);
      await Promise.all(
        PRECACHE_SHELL.map((url) =>
          shell.add(new Request(url, { cache: 'reload' })).catch(() => null)
        )
      );

      // 폰트/그래픽 엔진도 셸 캐시에 함께 넣습니다.
      await Promise.all(
        PRECACHE_FONTS.map((url) =>
          shell.add(new Request(url, { cache: 'reload' })).catch(() => null)
        )
      );

      const games = await caches.open(GAME_CACHE);
      await Promise.all(
        PRECACHE_SHELL.filter((u) => u.startsWith('games/')).map((url) =>
          games.add(new Request(url, { cache: 'reload' })).catch(() => null)
        )
      );
    })()
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((key) => !key.startsWith(VERSION))
          .map((key) => caches.delete(key))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
  if (event.data === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.keys().then((keys) => Promise.all(keys.map((k) => caches.delete(k))))
    );
  }
});

self.addEventListener('fetch', (event) => {
  const request = event.request;

  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // 다른 도메인은 건드리지 않음
  if (url.origin !== self.location.origin) return;

  // 업데이트 감지용 파일은 항상 네트워크
  if (url.pathname.endsWith('version.json')) {
    event.respondWith(
      fetch(request, { cache: 'no-store' }).catch(
        () =>
          new Response('{"buildId":""}', {
            headers: { 'Content-Type': 'application/json' },
          })
      )
    );
    return;
  }

  // 게임 파일: cache-first (오프라인 완전 지원)
  // ⚠️ '/games/' 로 판별하면 assets/assets/games/catalog.json 같은 앱 자산까지
  //    게임으로 오인하므로, 경로에 '/games/' 가 '두 번' 나오는 경우만 게임입니다.
  const path = url.pathname;
  const isGameFile =
    path.includes('/games/') && !path.includes('/assets/assets/');

  if (isGameFile) {
    event.respondWith(cacheFirst(request, GAME_CACHE));
    return;
  }

  // 앱 문서: network-first → 실패 시 캐시 (오프라인 실행)
  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request, SHELL_CACHE));
    return;
  }

  // 나머지 셸 자산: stale-while-revalidate
  event.respondWith(staleWhileRevalidate(request, SHELL_CACHE));
});

async function cacheFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request, { ignoreSearch: true });
  if (cached) return cached;
  try {
    const response = await fetch(request);
    if (response && response.status === 200) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (err) {
    return new Response('오프라인 상태예요.', { status: 503 });
  }
}

async function networkFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  try {
    const response = await fetch(request);
    if (response && response.status === 200) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (err) {
    const cached =
      (await cache.match(request, { ignoreSearch: true })) ||
      (await cache.match('index.html')) ||
      (await cache.match('./'));
    return (
      cached ||
      new Response('<h1>오프라인</h1><p>앱을 한 번 이상 실행해 주세요.</p>', {
        status: 200,
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      })
    );
  }
}

async function staleWhileRevalidate(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request, { ignoreSearch: true });

  const network = fetch(request)
    .then((response) => {
      if (response && response.status === 200) {
        cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => null);

  return cached || (await network) || new Response('', { status: 504 });
}
