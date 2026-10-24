#!/usr/bin/env python3
"""
사이트용 게임 → '파일 하나로 열리는' 독립 실행본 만들기
====================================================================
사용법:
    python3 tools/make_standalone.py            # → build/standalone/*.html

사이트 버전(web/games/<id>/index.html)과 똑같은 게임에서
  · 뮤됴구 SDK 스크립트 태그만 빼고
  · 로컬 폰트/라이브러리를 원본처럼 인터넷 주소로 되돌려
파일 하나만 있어도 열리게 한다. (진행 코드 옮기기 기능은 그대로 들어 있음)
→ 예전에 게임하던 곳에서 이 파일을 열고 코드를 복사해 사이트로 옮길 때 쓴다.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "standalone"

SDK_TAGS = [
    '<!-- 뮤됴구 SDK -->\n<script src="../mudyogu-sdk.js"></script>\n',
    '    <script src="../mudyogu-sdk.js"></script>\n',
    '<script src="../mudyogu-sdk.js"></script>\n',
]

SWAPS = {
    "hanilnam-life": [(
        '<!-- 오프라인 번들 폰트 (CDN 미사용) -->\n<link rel="stylesheet" href="fonts/fonts.css">',
        '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
        '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Black+Han+Sans&family=Gowun+Batang:wght@400;700&family=IBM+Plex+Sans+KR:wght@400;600;700&display=swap">',
    )],
    "pokequiz": [(
        '<!-- 뮤됴구: 오프라인용 로컬 폰트 / 라이브러리 (원본은 Google Fonts, cdnjs peerjs 1.5.4) -->\n'
        '<link rel="stylesheet" href="fonts/fonts.css">\n<script src="vendor/peerjs.min.js"></script>',
        '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
        '<link href="https://fonts.googleapis.com/css2?family=Black+Han+Sans&family=Gothic+A1:wght@400;500;700;900&family=Space+Mono:wght@400;700&display=swap" rel="stylesheet">\n'
        '<script src="https://cdnjs.cloudflare.com/ajax/libs/peerjs/1.5.4/peerjs.min.js"></script>',
    )],
    "tower-drop": [(
        '<!-- 오프라인 번들 폰트 (CDN 미사용) -->\n<link rel="stylesheet" href="fonts/fonts.css">',
        '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
        '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Black+Han+Sans&display=swap">',
    )],
}

NAMES = {"haniljeon": "한일전", "hanilnam-life": "한(일)남 LIFE", "pokequiz": "포케퀴즈(실루엣 인카운터)", "tower-drop": "타워 크래시"}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for gid, name in NAMES.items():
        src = ROOT / "web" / "games" / gid / "index.html"
        s = src.read_text(encoding="utf-8")
        for tag in SDK_TAGS:
            s = s.replace(tag, "")
        for a, b in SWAPS.get(gid, []):
            if a not in s:
                raise SystemExit(f"❌ {gid}: 바꿀 줄을 못 찾음 — tools/make_standalone.py 를 갱신하세요")
            s = s.replace(a, b)
        if "mudyogu-sdk.js" in s:
            raise SystemExit(f"❌ {gid}: SDK 태그가 남아 있음")
        dst = OUT / f"{name}.html"
        dst.write_text(s, encoding="utf-8")
        print(f"✓ {dst.relative_to(ROOT)}  ({dst.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
