# 원시인록 여행기 (primal-journey)

뮤됴구 허브와 별개인 단일 HTML 오프라인 Canvas 액션 게임. 사이트(`web/`)에는 아직 올리지 않았다.

- `primal-journey.html` — 최신 원본. **새로 만들지 말고 이 파일을 이어서 수정**
- `HANDOFF.md` — 확정 설정·금지 회귀 (작업 전 필독)
- `./run-tests.sh` — 회귀 검사 6종 (184개). 수정 후 반드시 실행
- `tests/preview-*.cjs` — 정지 미리보기 사본 생성 (결과물은 gitignore, 원본 아님)
- 실제 브라우저 확인은 Playwright 로 띄워서 (`window.primalJourney` 개발 훅)
