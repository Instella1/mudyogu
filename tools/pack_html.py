#!/usr/bin/env python3
"""
뮤됴구 HTML 번들 패키저.

build/web 를 그대로 압축하면 하위 폴더 배포 시 깨지는 부분이 있어
아래를 조정한 "그냥 열어도 되는" HTML 배포본을 만듭니다.

  1) index.html 의 <base href="/"> → "./"   (상대 경로)
  2) 서비스워커 등록 경로를 상대 경로로 (service_worker.js)
  3) flutter_bootstrap.js 의 index.html 서비스워커 로더 비활성화
     (커스텀 service_worker.js 와 충돌)
  4) 디버그용 .symbols 파일과 미사용 canvaskit/chromium(구 렌더러) 제거
  5) downloads/ 제외
"""
import os
import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path("/home/user/flutter_app")
SRC = ROOT / "build/web"
STAGE = Path("/tmp/htmlbundle/mudyogu")
OUT_ZIP = ROOT / "build/web/downloads/mudyogu-html.zip"


def log(msg):
    print(msg, flush=True)


def stage_copy():
    if STAGE.parent.exists():
        shutil.rmtree(STAGE.parent)
    STAGE.mkdir(parents=True)

    # ⚠️ canvaskit/chromium/ 은 크롬 계열 브라우저가 사용하므로 반드시 포함합니다.
    skip_dirs = {"downloads"}
    # .symbols: 디버그 심볼, skwasm*: 이 앱은 canvaskit 렌더러만 사용 (약 10MB 절감)
    skip_suffix = {".symbols"}
    skip_prefix = {"skwasm"}
    skip_files = {"flutter_service_worker.js"}

    for dirpath, dirnames, filenames in os.walk(SRC):
        rel = Path(dirpath).relative_to(SRC)
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        target = STAGE / rel
        target.mkdir(parents=True, exist_ok=True)
        for name in filenames:
            if Path(name).suffix in skip_suffix:
                continue
            if name in skip_files:
                continue
            if any(name.startswith(pfx) for pfx in skip_prefix):
                continue
            shutil.copy2(Path(dirpath) / name, target / name)

    log(f"▶ 스테이징 완료: {STAGE}")


def patch_index():
    p = STAGE / "index.html"
    html = p.read_text(encoding="utf-8")
    before = html
    html = html.replace('<base href="/" />', '<base href="./" />')
    html = re.sub(r'<base href="/">', '<base href="./">', html)
    if html == before:
        raise SystemExit("!! base href 를 찾지 못했습니다")
    p.write_text(html, encoding="utf-8")
    log("▶ index.html: base href → ./")


def patch_bootstrap():
    """부트스트랩/캐너스킷 패치는 공용 스크립트(tools/patch_web.py)에 위임."""
    import subprocess

    here = Path(__file__).resolve().parent
    subprocess.run(
        ["python3", str(here / "patch_web.py"), str(STAGE)],
        check=True,
    )


def patch_service_worker():
    p = STAGE / "service_worker.js"
    js = p.read_text(encoding="utf-8")
    m = re.search(r"const VERSION = '([^']+)'", js)
    log(f"▶ service_worker.js 준비 ({m.group(1) if m else '?'}, {len(js)} bytes)")


def write_readme():
    (STAGE / "README-배포방법.txt").write_text(
        """뮤됴구 (Mudyogu) — HTML 웹 버전
=====================================

이 폴더를 웹 서버에 그대로 올리면 앱이 실행됩니다.
Flutter 설치나 빌드 과정 없이, 정적 파일만 있으면 됩니다.


■ 1. 가장 빠른 방법 (내 컴퓨터에서 보기)
   이 폴더에서 터미널을 열고:

       python3 -m http.server 8000

   브라우저에서 http://localhost:8000 접속.


■ 2. 웹 서버에 올리기
   폴더 "안의 내용물"을 웹 루트(또는 하위 폴더)에 그대로 업로드하세요.

   · 루트에 올리는 경우   https://내도메인.com/
   · 하위 폴더에 올리는 경우 https://내도메인.com/mudyogu/

   두 경우 모두 동작합니다. (상대 경로로 만들어져 있음)


■ 3. 주의 사항
   · index.html 을 파일로 직접 더블클릭(file://)하면 동작하지 않습니다.
     반드시 http:// 또는 https:// 로 열어야 합니다.
     (브라우저 보안 정책상 모듈/서비스워커 로딩이 막힙니다)

   · 설치형(PWA)으로 쓰려면 HTTPS 가 필요합니다.
     (localhost 는 예외적으로 허용)


■ 4. 앱 설치
   · 크롬/엣지: 주소창 오른쪽 "설치" 아이콘 또는 메뉴 → 앱 설치
   · 안드로이드 크롬: 메뉴 → 홈 화면에 추가
   · iOS 사파리: 공유 → 홈 화면에 추가

   한 번 설치하면 인터넷 없이도 실행됩니다.
   (게임 2종 + 폰트까지 모두 캐시에 저장됨)


■ 5. 폴더 구성
   index.html            진입점
   main.dart.js          앱 본체 (Flutter → JS 변환 결과)
   flutter_bootstrap.js  실행 로더
   canvaskit/            그래픽 엔진 (wasm)
   assets/               폰트/아이콘/게임 카탈로그
   games/                게임 2종
     haniljeon/          한일전
     hanilnam-life/      한(일)남 LIFE (폰트 포함, 오프라인 지원)
   icons/, manifest.json PWA 설치 정보
   service_worker.js     오프라인 캐시


■ 6. 업데이트하는 방법
   새로 빌드한 폴더 내용으로 통째로 교체하면 됩니다.
   기존 사용자는 앱 실행 시 "새 버전이 있어요" 배너를 보게 됩니다.
   (service_worker.js 의 VERSION 값이 바뀌면 캐시가 자동 갱신됩니다)


빌드: 2026-10-23
""",
        encoding="utf-8",
    )
    log("▶ README-배포방법.txt 생성")


def make_zip():
    OUT_ZIP.parent.mkdir(parents=True, exist_ok=True)
    if OUT_ZIP.exists():
        OUT_ZIP.unlink()
    with zipfile.ZipFile(OUT_ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for dirpath, _, filenames in os.walk(STAGE):
            for name in filenames:
                full = Path(dirpath) / name
                z.write(full, full.relative_to(STAGE.parent))
    log(f"▶ zip 생성: {OUT_ZIP} ({OUT_ZIP.stat().st_size/1024/1024:.1f} MB)")


def report():
    total = sum(f.stat().st_size for f in STAGE.rglob("*") if f.is_file())
    log(f"▶ 번들 용량: {total/1024/1024:.1f} MB, 파일 {sum(1 for f in STAGE.rglob('*') if f.is_file())}개")


if __name__ == "__main__":
    stage_copy()
    patch_index()
    patch_bootstrap()
    patch_service_worker()
    write_readme()
    report()
    make_zip()
    log("✅ 완료")
