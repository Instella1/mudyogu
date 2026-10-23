# 원본 게임 파일 (사용자가 직접 만든 버전)

배포되지 않는 보관용입니다. `web/games/*/index.html` 을 고칠 때 이 파일과 `diff` 해서
**원본 줄이 바뀌지 않고 '추가'만 있는지** 확인하세요.

```bash
diff originals/haniljeon.html web/games/haniljeon/index.html | grep '^<'      # 아무것도 안 나와야 정상
diff originals/hanilnam-life.html web/games/hanilnam-life/index.html | grep '^<'
# (LIFE 는 구글 폰트 링크 3줄 → 로컬 fonts/fonts.css 로 바뀐 것, 코드 복사 시 앱 보관 2줄만 예외)
```
