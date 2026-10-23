#!/usr/bin/env python3
"""
Google Fonts 오프라인 번들러
====================================================================
CSS 를 받아 woff2 파일을 전부 내려받고, CSS 안의 URL 을 로컬 경로로 치환합니다.
오프라인(PWA) 환경에서 웹폰트가 깨지지 않도록 하기 위함입니다.

사용법:
    python3 tools/bundle_fonts.py <출력폴더> "<구글폰트 CSS URL>"
"""
from __future__ import annotations

import re
import sys
import urllib.request
from pathlib import Path

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


def fetch(url: str, binary: bool = False):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    return data if binary else data.decode("utf-8")


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: bundle_fonts.py <outdir> <css_url>")
        return 1

    out = Path(sys.argv[1]).resolve()
    css_url = sys.argv[2]
    out.mkdir(parents=True, exist_ok=True)

    css = fetch(css_url)
    urls = re.findall(r"url\((https://fonts\.gstatic\.com/[^)]+)\)", css)
    unique = sorted(set(urls))
    print(f"폰트 파일 {len(urls)}개 참조 / 고유 {len(unique)}개")

    mapping: dict[str, str] = {}
    for idx, url in enumerate(unique):
        name = re.sub(r"[^A-Za-z0-9._-]", "", url.split("/")[-1])
        if not name.endswith(".woff2"):
            name = f"font-{idx}.woff2"
        target = out / name
        if not target.exists():
            target.write_bytes(fetch(url, binary=True))
        mapping[url] = name

    for original, local in mapping.items():
        css = css.replace(original, local)

    (out / "fonts.css").write_text(css, encoding="utf-8")
    total = sum(p.stat().st_size for p in out.glob("*.woff2"))
    print(f"✅ {out}/fonts.css  ({len(mapping)}개 파일, {total / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
