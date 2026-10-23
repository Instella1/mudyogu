/// 빌드 정보 (`--dart-define` 로 주입).
///
/// 빌드 스크립트가 BUILD_ID / APP_VERSION / BUILT_AT 을 넘겨줍니다.
/// BUILD_ID 가 바뀌면 "새 버전 있음" 배너가 뜹니다.
class BuildInfo {
  const BuildInfo._();

  static const String buildId = String.fromEnvironment(
    'BUILD_ID',
    defaultValue: '',
  );

  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const String builtAt = String.fromEnvironment(
    'BUILT_AT',
    defaultValue: '',
  );
}
