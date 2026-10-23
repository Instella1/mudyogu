#!/usr/bin/env python3
"""
인수인계 패키지 생성기.

다른 사람(또는 AI)에게 프로젝트를 넘길 때 필요한 것만 모아 zip 으로 만듭니다.
소스 전체 + 문서 + 게임 파일 + 도구. 빌드 산출물(build/)은 제외합니다.

사용법:
    python3 tools/make_handoff.py
    → build/web/downloads/mudyogu-handoff.zip
"""
from __future__ import annotations

import os
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build/web/downloads/mudyogu-handoff.zip"
TOP = "mudyogu"  # zip 안 최상위 폴더명

# 프로젝트 루트에서 그대로 가져갈 것
INCLUDE_FILES = [
    "README.md",
    "build.sh",
    "pubspec.yaml",
    "pubspec.lock",
    "analysis_options.yaml",
    ".metadata",
]

INCLUDE_DIRS = ["lib", "web", "assets", "tools", "docs", "test"]

# 제외 패턴
SKIP_DIR_NAMES = {
    ".git", ".dart_tool", "build", "node_modules", "__pycache__",
    ".idea", ".vscode", "downloads",
}
SKIP_SUFFIX = {".iml", ".log", ".pyc"}

# zip 안에 새로 써 넣을 파일 (원본에는 없음)
GITIGNORE = """\
# Flutter / Dart
.dart_tool/
.packages
build/
.flutter-plugins
.flutter-plugins-dependencies
*.iml

# 웹 빌드 산출물 (build.sh 가 만듦)
build/web/

# 도구
__pycache__/
*.pyc

# 에디터 / OS
.idea/
.vscode/
.DS_Store
*.log
"""

# 풀자마자 뭘 해야 하는지 알려주는 파일
START_HERE = """\
뮤됴구 (Mudyogu) — 인수인계 패키지
=====================================

이 폴더는 Flutter PWA 미니게임 허브 "뮤됴구"의 전체 소스입니다.
AI(클로드 등)에게 이 폴더를 통째로 주고 아래 순서대로 읽게 하세요.

읽는 순서
---------
1. HANDOFF.md          ← 여기부터. 구조 / 절대규칙 / 과거 버그 이력
2. docs/GAME-SPEC.md   ← 게임 만들 때 지킬 규약
3. docs/CLAUDE-PROMPTS.md ← AI 에게 시킬 때 그대로 붙여넣는 프롬프트 모음

바로 실행해 보기
---------------
    flutter pub get
    flutter analyze
    ./build.sh
    python3 -m http.server 5060 --directory build/web
    # → http://localhost:5060

배포용 zip 만들기
----------------
    python3 tools/pack_html.py
    # → build/web/downloads/mudyogu-html.zip

환경
----
Flutter 3.35.4 / Dart 3.9.2  ← 버전 업그레이드 금지 (검증된 조합)

절대 규칙 4가지 (어기면 과거 버그 재발)
--------------------------------------
1. iframe 위에 Flutter 위젯을 Stack 으로 겹치지 말 것 (클릭 안 먹힘)
2. Sliver 를 Padding 같은 박스 위젯으로 감싸지 말 것 (조용히 안 보임)
3. 게임 CSS 에서 aspect-ratio + 고정 height 조합 금지 (찌그러짐)
4. 게임에 외부 URL 금지 / build.sh 를 건너뛰지 말 것 (오프라인 깨짐)
"""


def iter_files(base: Path):
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_NAMES]
        for name in filenames:
            if Path(name).suffix in SKIP_SUFFIX:
                continue
            yield Path(dirpath) / name


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        OUT.unlink()

    count = 0
    total = 0

    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        def add(path: Path, arcname: str):
            nonlocal count, total
            z.write(path, arcname)
            count += 1
            total += path.stat().st_size

        for name in INCLUDE_FILES:
            p = ROOT / name
            if p.exists():
                add(p, f"{TOP}/{name}")

        for d in INCLUDE_DIRS:
            base = ROOT / d
            if not base.is_dir():
                continue
            for f in iter_files(base):
                add(f, f"{TOP}/{f.relative_to(ROOT)}")

        # HANDOFF.md 는 zip 최상위에도 복사 (풀자마자 눈에 띄게)
        handoff = ROOT / "docs/HANDOFF.md"
        if handoff.exists():
            z.write(handoff, f"{TOP}/HANDOFF.md")

        # 원본에 없는 파일은 문자열로 직접 써 넣는다
        z.writestr(f"{TOP}/.gitignore", GITIGNORE)
        z.writestr(f"{TOP}/START-HERE.txt", START_HERE)

    size = OUT.stat().st_size
    print(f"▶ 인수인계 패키지: {OUT}")
    print(f"  파일 {count}개 / 원본 {total/1024/1024:.1f}MB / zip {size/1024/1024:.1f}MB")

    # 빠짐없이 들어갔는지 요약
    print("\n  포함된 주요 항목:")
    for d in INCLUDE_DIRS:
        base = ROOT / d
        if base.is_dir():
            n = sum(1 for _ in iter_files(base))
            print(f"    {d}/  ({n} files)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
