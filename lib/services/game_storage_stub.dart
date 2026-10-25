/// 게임 저장소(브라우저 localStorage) 접근 — 웹이 아닌 플랫폼용 빈 구현.
class GameStorage {
  const GameStorage();

  Map<String, String> readAll() => const <String, String>{};

  void replaceAll(Map<String, String> data) {}

  /// 브라우저 탭이 숨겨질 때(다른 앱으로 전환·창 닫기 직전) 호출
  void onHidden(void Function() callback) {}
}
