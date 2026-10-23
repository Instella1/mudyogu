# 게임 빌더 (원본 → 사이트 버전)

원본 줄은 그대로 두고 뮤됴구 기능만 덧붙여 `web/games/<id>/index.html` 을 다시 만든다.

```bash
python3 tools/game_builders/build_haniljeon.py originals/haniljeon.html tools/game_builders/haniljeon_genspark_parts.html web/games/haniljeon/index.html site
python3 tools/game_builders/build_pokequiz.py  originals/pokemon_quiz.html web/games/pokequiz/index.html site
```

- `haniljeon_genspark_parts.html`: 진행 코드 창 · 터치 버튼 · SDK 연동 코드 조각을 가져오는 원천 (줄 번호로 잘라 씀 — 고치지 말 것)
- 한(일)남 LIFE 는 빌더 없이 `web/games/hanilnam-life/index.html` 을 직접 고친다 (원본 줄은 그대로, 맨 아래 스크립트만 추가)
- 독립 실행본은 `python3 tools/make_standalone.py`
