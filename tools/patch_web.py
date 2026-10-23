#!/usr/bin/env python3
"""
웹 배포본 공통 패치 (build/web 와 HTML 번들 양쪽에서 사용).

왜 필요한가
-----------
Flutter 는 빌드할 때 flutter_bootstrap.js 를 이렇게 만듭니다.

    _flutter.loader.load({ serviceWorkerSettings: { serviceWorkerVersion: "..." } });

이 설정은 flutter_service_worker.js 를 등록하는데, 뮤됴구는 자체
service_worker.js 를 쓰기 때문에 같은 스코프에 서비스워커가 2개 등록되어
캐시가 엉키고 오프라인이 깨집니다. 그래서 부트스트랩 꼬리를 교체합니다.

또한 canvaskit 는 기본값이 CDN(gstatic.com) 이라 오프라인이 깨지므로
canvasKitBaseUrl 을 번들 안의 canvaskit/ 로 지정합니다.

사용법:
    python3 tools/patch_web.py <web_root> [--relative-base]
"""
import re
import sys
from pathlib import Path

BOOTSTRAP_TAIL_TMPL = """if (!window._flutter) {
  window._flutter = {};
}
_flutter.buildConfig = @@BUILD_CONFIG@@;

// 서비스워커는 main.dart 의 PwaService 가 service_worker.js 로 직접 등록합니다.
// (Flutter 기본 flutter_service_worker.js 와 이중 등록되는 것을 막습니다)
// canvasKitBaseUrl → 번들에 동봉된 canvaskit/ 사용 (CDN 미사용 = 오프라인 OK).
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/'
  }
});
"""


def patch_bootstrap(root: Path) -> bool:
    p = root / "flutter_bootstrap.js"
    if not p.exists():
        print(f"  ! flutter_bootstrap.js 없음: {root}")
        return False

    js = p.read_text(encoding="utf-8")
    idx = js.rfind("if (!window._flutter)")
    if idx < 0:
        print("  ! 부트스트랩 꼬리를 찾지 못했습니다")
        return False

    m = re.search(
        r"(?:window\.)?_flutter\.buildConfig\s*=\s*(\{.*?\});\s*\n", js[idx:], re.S
    )
    if not m:
        print("  ! buildConfig 를 찾지 못했습니다")
        return False

    tail = BOOTSTRAP_TAIL_TMPL.replace("@@BUILD_CONFIG@@", m.group(1))
    p.write_text(js[:idx] + tail, encoding="utf-8")
    print("  · flutter_bootstrap.js: SW 로더 제거 + 로컬 canvaskit")
    return True


def patch_base_href(root: Path) -> bool:
    p = root / "index.html"
    if not p.exists():
        return False
    html = p.read_text(encoding="utf-8")
    before = html
    html = html.replace('href="$FLUTTER_BASE_HREF"', 'href="./"')
    html = html.replace('<base href="/">', '<base href="./">')
    html = html.replace('<base href="/" />', '<base href="./" />')
    if html == before:
        print("  · index.html: base href 이미 상대경로")
        return True
    p.write_text(html, encoding="utf-8")
    print("  · index.html: base href → ./")
    return True


def main() -> int:
    if len(sys.argv) < 2:
        print("사용법: python3 tools/patch_web.py <web_root> [--relative-base]")
        return 1

    root = Path(sys.argv[1])
    if not root.is_dir():
        print(f"! 폴더가 없습니다: {root}")
        return 1

    print(f"▶ 웹 패치: {root}")
    ok = patch_bootstrap(root)
    if "--relative-base" in sys.argv:
        patch_base_href(root)
    print("✅ 패치 완료" if ok else "⚠️ 일부 실패")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
