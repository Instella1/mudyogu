import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/theme/app_theme.dart';

void main() {
  test('라이트/다크 테마가 정상 생성된다', () {
    final ThemeData light = AppTheme.light();
    final ThemeData dark = AppTheme.dark();
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.textTheme.titleLarge, isNotNull);
  });
}
