#!/usr/bin/env bash
# 뮤됴구 웹 빌드 스크립트
#   - 빌드마다 고유 buildId 생성 → version.json 으로 배포
#   - 앱이 version.json 을 폴링해 "새 버전 있음" 배너를 띄웁니다.
set -euo pipefail

cd "$(dirname "$0")"

APP_VERSION="$(grep -E '^version:' pubspec.yaml | sed 's/version: *//' | cut -d'+' -f1)"
BUILD_ID="${BUILD_ID:-$(date -u +%Y%m%d%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "▶ 뮤됴구 빌드"
echo "  version : $APP_VERSION"
echo "  buildId : $BUILD_ID"

flutter build web --release \
  --dart-define=BUILD_ID="$BUILD_ID" \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=BUILT_AT="$BUILT_AT"

cat > build/web/version.json <<EOF
{
  "buildId": "$BUILD_ID",
  "version": "$APP_VERSION",
  "builtAt": "$BUILT_AT"
}
EOF

# ── 배포본 패치 ───────────────────────────────────────────────
#  · Flutter 기본 서비스워커(flutter_service_worker.js) 등록 해제
#    → 커스텀 service_worker.js 와 이중 등록되어 캐시가 엉키는 것을 방지
#  · canvaskit 를 CDN 대신 로컬 canvaskit/ 에서 로드 → 오프라인 동작
python3 tools/patch_web.py build/web

echo "▶ 완료: build/web/version.json"
cat build/web/version.json
