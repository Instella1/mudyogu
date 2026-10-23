import 'package:flutter/material.dart';

/// 뮤됴구 브랜드 팔레트
/// - 밝은 녹색을 주 색상으로, 파스텔 보조색을 사용합니다.
class AppColors {
  const AppColors._();

  // 브랜드
  static const Color brand = Color(0xFF2FCC8B); // 밝은 녹색
  static const Color brandDeep = Color(0xFF16A26E);
  static const Color brandSoft = Color(0xFFDCF8EA);

  // 파스텔 보조색
  static const Color lavender = Color(0xFFCBBDFF);
  static const Color peach = Color(0xFFFFC9B7);
  static const Color sky = Color(0xFFAFDCFF);
  static const Color lemon = Color(0xFFFFEDB0);
  static const Color blush = Color(0xFFFFC6DB);

  // 라이트
  static const Color lightBg = Color(0xFFF6FAF8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightLine = Color(0xFFE4EDE8);
  static const Color lightText = Color(0xFF14211B);
  static const Color lightMuted = Color(0xFF6B7C74);

  // 다크
  static const Color darkBg = Color(0xFF0E1311);
  static const Color darkSurface = Color(0xFF171F1B);
  static const Color darkLine = Color(0xFF27332D);
  static const Color darkText = Color(0xFFEAF3EE);
  static const Color darkMuted = Color(0xFF93A69D);

  static const List<Color> pastelCycle = <Color>[
    brandSoft,
    lavender,
    peach,
    sky,
    lemon,
    blush,
  ];
}

class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'NanumSquareRound';

  static ThemeData light() => _build(
    brightness: Brightness.light,
    bg: AppColors.lightBg,
    surface: AppColors.lightSurface,
    line: AppColors.lightLine,
    text: AppColors.lightText,
    muted: AppColors.lightMuted,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    bg: AppColors.darkBg,
    surface: AppColors.darkSurface,
    line: AppColors.darkLine,
    text: AppColors.darkText,
    muted: AppColors.darkMuted,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color line,
    required Color text,
    required Color muted,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
      primary: isDark ? const Color(0xFF5FE3AE) : AppColors.brand,
      surface: surface,
    );

    final TextTheme base = ThemeData(brightness: brightness).textTheme;
    final TextTheme textTheme = base
        .apply(fontFamily: fontFamily, bodyColor: text, displayColor: text)
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            color: text,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: text,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: text,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontFamily: fontFamily,
            height: 1.55,
            color: text,
          ),
          bodySmall: base.bodySmall?.copyWith(
            fontFamily: fontFamily,
            height: 1.5,
            color: muted,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: line,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: text, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: line, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E2823) : const Color(0xFFF1F6F3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: muted, fontFamily: fontFamily),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE8788A)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: const Color(0xFF07301F),
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFF5FE3AE) : AppColors.brandDeep,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF25322C) : const Color(0xFF1E2B25),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? const Color(0xFF6C7C74) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.brand;
          return isDark ? const Color(0xFF2C3833) : const Color(0xFFDDE6E1);
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
    );
  }
}
