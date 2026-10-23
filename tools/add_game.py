#!/usr/bin/env python3
"""
뮤됴구 게임 설치 도구
====================================================================
사용법:
    python3 tools/add_game.py <게임폴더 또는 ZIP> [--id ID] [--title 제목]
                               [--tagline "한 줄 소개"] [--accent "#색상"]

예시:
    python3 tools/add_game.py ~/Downloads/my-game.zip --title "우주 슈터"
    python3 tools/add_game.py ~/Downloads/puzzle/ --id puzzle --title "퍼즐"

동작:
    1) 게임 파일을 web/games/<id>/ 로 복사 (node_modules 등 제외)
    2) index.html 에 뮤됴구 SDK 를 자동 주입 (아직 없으면)
    3) assets/games/catalog.json 에 항목 추가
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAMES_WEB = ROOT / "web" / "games"
CATALOG = ROOT / "assets" / "games" / "catalog.json"

SKIP_DIRS = {
    "node_modules",
    ".git",
    ".github",
    "__MACOSX",
    ".vscode",
    ".idea",
    "dist-src",
    ".cache",
}
SKIP_FILES = {".DS_Store", "Thumbs.db", "package-lock.json", "yarn.lock"}

ACCENTS = ["#FFAF8F", "#C4B5FD", "#7FD8FF", "#FFE0A3", "#FFC0D4", "#A8E6CF"]


def slugify(text: str) -> str:
    """
    제목을 URL-안전한 ASCII 폴더 id 로 변환.
    한글 제목은 ASCII 로 남지 않으므로 game / game-2 형태로 대체됩니다.
    (URL 인코딩 이슈를 피하기 위함)
    """
    slug = re.sub(r"[^a-z0-9]+", "-", text.strip().lower()).strip("-")
    if not slug:
        return ""
    return slug[:40]


def scan_index(html: str) -> dict:
    """HTML 에서 제목/설명 추출"""
    title = ""
    desc = ""
    m = re.search(r"<title[^>]*>(.*?)</title>", html, re.I | re.S)
    if m:
        title = re.sub(r"\s+", " ", m.group(1)).strip()
    m = re.search(
        r'<meta[^>]+name=["\']description["\'][^>]+content=["\'](.*?)["\']',
        html,
        re.I | re.S,
    )
    if m:
        desc = re.sub(r"\s+", " ", m.group(1)).strip()
    return {"title": title, "description": desc}


def inject_sdk(html: str) -> tuple[str, bool]:
    """
    뮤됴구 SDK 를 index.html 에 자동 주입.
    이미 SDK 가 있으면 그대로 둡니다.
    """
    if "mudyogu-sdk.js" in html:
        return html, False

    snippet = (
        '  <!-- 뮤됴구 SDK (자동 주입) -->\n'
        '  <script src="../mudyogu-sdk.js"></script>\n'
        "  <script>\n"
        "    (function () {\n"
        "      var MUD = window.MudyoguSDK ? MudyoguSDK.create() : null;\n"
        "      if (!MUD) return;\n"
        "      // 앱이 저장된 진행상황을 넘겨줍니다\n"
        "      MUD.onInit(function (payload) {\n"
        "        if (typeof window.mudyoguRestore === 'function') {\n"
        "          try { window.mudyoguRestore(payload); } catch (e) {}\n"
        "        }\n"
        "      });\n"
        "      window.MUD = MUD;\n"
        "      MUD.ready();\n"
        "      // 편의 함수: window.mudyoguSave({ score: 10, state: {...} })\n"
        "      window.mudyoguSave = function (payload) { MUD.save(payload); };\n"
        "    })();\n"
        "  </script>\n"
    )

    if "</body>" in html.lower():
        idx = html.lower().rfind("</body>")
        return html[:idx] + snippet + html[idx:], True
    return html + "\n" + snippet, True


def gather(source: Path, workdir: Path) -> Path:
    """ZIP 이면 풀고, 실제 게임 루트( index.html 이 있는 폴더 )를 찾습니다."""
    if source.suffix.lower() == ".zip":
        with zipfile.ZipFile(source) as zf:
            zf.extractall(workdir)
        base = workdir
    elif source.is_dir():
        base = source
    else:
        raise SystemExit(f"❌ 폴더나 ZIP 파일이 필요합니다: {source}")

    # index.html 이 있는 디렉터리 탐색 (얕은 곳 우선)
    candidates = sorted(
        base.rglob("index.html"),
        key=lambda p: len(p.parts),
    )
    if not candidates:
        raise SystemExit("❌ index.html 을 찾지 못했습니다.")

    root = candidates[0].parent

    # ZIP 안에 한 겹 더 들어있는 경우(__MACOSX 등) 정리
    while root.name in SKIP_DIRS and root.parent != base:
        root = root.parent
    return root


def copy_tree(src: Path, dst: Path) -> int:
    """게임 파일 복사 (불필요한 파일 제외)"""
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True, exist_ok=True)

    count = 0
    for item in src.rglob("*"):
        if any(part in SKIP_DIRS for part in item.relative_to(src).parts):
            continue
        if item.name in SKIP_FILES:
            continue
        if item.is_dir():
            continue
        target = dst / item.relative_to(src)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item, target)
        count += 1
    return count


def update_catalog(entry: dict) -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    games = [g for g in data.get("games", []) if g.get("id") != entry["id"]]
    games.append(entry)
    data["games"] = games
    data["updatedAt"] = entry.get("_now", data.get("updatedAt", ""))
    data.pop("_now", None)
    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="뮤됴구 게임 설치 도구")
    ap.add_argument("source", help="게임 폴더 또는 ZIP 경로")
    ap.add_argument("--id", help="게임 ID (폴더명). 생략 시 제목에서 자동 생성")
    ap.add_argument("--title", help="앱에 표시할 제목")
    ap.add_argument("--tagline", default="", help="한 줄 소개")
    ap.add_argument("--accent", help="카드 강조색 (#RRGGBB)")
    ap.add_argument("--no-inject", action="store_true", help="SDK 자동 주입 생략")
    args = ap.parse_args()

    source = Path(args.source).expanduser().resolve()
    if not source.exists():
        print(f"❌ 경로 없음: {source}")
        return 1

    GAMES_WEB.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        game_root = gather(source, Path(tmp))

        index_path = game_root / "index.html"
        html = index_path.read_text(encoding="utf-8", errors="ignore")
        meta = scan_index(html)

        title = args.title or meta["title"] or game_root.name
        game_id = args.id or slugify(title)
        if not game_id:
            # 한글 제목 → game, game-2, game-3 ...
            base = GAMES_WEB
            n = 1
            game_id = "game"
            while (base / game_id).exists():
                n += 1
                game_id = f"game-{n}"
        tagline = args.tagline or meta["description"] or "새로 추가된 게임"

        if not args.no_inject:
            new_html, injected = inject_sdk(html)
            if injected:
                index_path.write_text(new_html, encoding="utf-8")

        dst = GAMES_WEB / game_id
        copied = copy_tree(game_root, dst)

        existing = json.loads(CATALOG.read_text(encoding="utf-8")).get("games", [])
        accent = args.accent or ACCENTS[len(existing) % len(ACCENTS)]

        entry = {
            "id": game_id,
            "title": title,
            "tagline": tagline[:60],
            "entry": f"games/{game_id}/index.html",
            "accent": accent,
            "tags": ["내 게임"],
            "version": "1.0.0",
            "supportsState": True,
            "bestScoreLabel": "최고 점수",
            "builtIn": False,
            "_now": "",
        }
        update_catalog(entry)

    print("─" * 56)
    print(f"✅ 설치 완료: {title}")
    print(f"   id      : {game_id}")
    print(f"   파일 수 : {copied}개  →  web/games/{game_id}/")
    print(f"   카탈로그: assets/games/catalog.json")
    print("─" * 56)
    print("👉 다음 단계:  ./build.sh  (또는  flutter run -d chrome)")
    print()
    print("💡 저장 연동이 필요하면 게임 코드에서 아래를 호출하세요:")
    print("     window.mudyoguSave({ score: 100, state: {...}, isGameOver: true })")
    print("     window.mudyoguRestore = (payload) => { /* payload.state 복원 */ };")
    return 0


if __name__ == "__main__":
    sys.exit(main())
