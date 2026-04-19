import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFFF9F9FB);
  static const Color surface = Color(0xFFF9F9FB);
  static const Color surfaceBase = Color(0xFFF9F9FB);
  static const Color surfaceMuted = Color(0xFFF2F4F6);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFEBEEF2);
  static const Color surfaceContainerHigh = Color(0xFFE4E9EE);
  static const Color surfaceContainerHighest = Color(0xFFDDE3E9);
  static const Color panel = Color(0xFFF2F2F4);

  static const Color title = Color(0xFF2D3338);
  static const Color onSurface = Color(0xFF2D3338);
  static const Color bodyText = Color(0xFF3C444B);
  static const Color subtleText = Color(0xFF596065);
  static const Color onSurfaceVariant = Color(0xFF596065);
  static const Color outline = Color(0xFF757C81);
  static const Color outlineSoft = Color(0xFFACB3B8);
  static const Color outlineVariant = Color(0xFFACB3B8);

  static const Color accent = Color(0xFF426464);
  static const Color accentStrong = Color(0xFF365858);
  static const Color accentContainer = Color(0xFFC5EAE9);
  static const Color accentForeground = Color(0xFFDAFFFE);
  static const Color secondaryContainer = Color(0xFFE0E3E2);
  static const Color tertiaryContainer = Color(0xFFD9F9DF);
  static const Color error = Color(0xFF9F403D);

  static const Color darkBackground = Color(0xFF0F1113);
  static const Color darkSurface = Color(0xFF15181B);
  static const Color darkPanel = Color(0xFF1A1C1E);
  static const Color darkText = Color(0xFFE4EAEE);
  static const Color darkSubtleText = Color(0xFF9BA4AB);
}

abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadii {
  static const double sm = 2;
  static const double card = 4;
  static const double container = 8;
  static const double floating = 12;
  static const double pill = 999;
}

abstract final class AppTheme {
  static ThemeData light() {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: AppColors.accentForeground,
      secondary: AppColors.surfaceContainerHigh,
      onSecondary: AppColors.onSurface,
      surface: AppColors.surfaceBase,
      onSurface: AppColors.onSurface,
      error: AppColors.error,
    );

    final TextTheme textTheme = _textTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surfaceContainerLowest,
      dividerColor: AppColors.outlineVariant.withValues(alpha: 0.2),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentForeground,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.floating),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          textStyle: textTheme.labelLarge,
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.28),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.floating),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondaryContainer,
        side: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.12),
        ),
        labelStyle: textTheme.labelMedium ?? const TextStyle(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.surfaceContainerLowest;
            }

            return AppColors.surfaceContainerHigh;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accent;
            }

            return AppColors.subtleText;
          }),
          textStyle: WidgetStateProperty.all(textTheme.labelLarge),
          side: WidgetStateProperty.all(
            BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.16)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.floating),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        hintStyle: textTheme.bodySmall?.copyWith(color: AppColors.subtleText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.container),
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.container),
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.container),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const ColorScheme colorScheme = ColorScheme.dark(
      primary: AppColors.accentContainer,
      onPrimary: AppColors.darkBackground,
      secondary: AppColors.darkPanel,
      onSecondary: AppColors.darkText,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      error: AppColors.error,
    );

    final TextTheme textTheme = _textTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkSurface,
      dividerColor: Colors.white.withValues(alpha: 0.08),
      textTheme: textTheme,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.white.withValues(alpha: 0.03),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final TextTheme base = ThemeData(brightness: brightness).textTheme;
    final Color bodyColor = brightness == Brightness.dark
        ? AppColors.darkText
        : AppColors.onSurface;
    final Color secondaryColor = brightness == Brightness.dark
        ? AppColors.darkSubtleText
        : AppColors.onSurfaceVariant;

    TextStyle headline(
      TextStyle? style, {
      required double size,
      required FontWeight weight,
      double height = 1.05,
      double letterSpacing = -0.9,
    }) {
      return (style ?? const TextStyle()).copyWith(
        fontFamily: 'Manrope',
        fontFamilyFallback: const ['Inter', 'Segoe UI', 'Roboto'],
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: bodyColor,
      );
    }

    TextStyle body(
      TextStyle? style, {
      required double size,
      required FontWeight weight,
      double height = 1.45,
      double letterSpacing = 0,
      Color? color,
    }) {
      return (style ?? const TextStyle()).copyWith(
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Segoe UI', 'Roboto', 'Arial'],
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? bodyColor,
      );
    }

    return base.copyWith(
      displayLarge: headline(
        base.displayLarge,
        size: 52,
        weight: FontWeight.w800,
      ),
      displayMedium: headline(
        base.displayMedium,
        size: 34,
        weight: FontWeight.w800,
      ),
      displaySmall: headline(
        base.displaySmall,
        size: 28,
        weight: FontWeight.w700,
      ),
      headlineSmall: headline(
        base.headlineSmall,
        size: 18,
        weight: FontWeight.w700,
      ),
      titleLarge: headline(base.titleLarge, size: 20, weight: FontWeight.w700),
      titleMedium: body(base.titleMedium, size: 14, weight: FontWeight.w600),
      titleSmall: body(base.titleSmall, size: 12, weight: FontWeight.w600),
      bodyLarge: body(base.bodyLarge, size: 14, weight: FontWeight.w400),
      bodyMedium: body(
        base.bodyMedium,
        size: 13,
        weight: FontWeight.w400,
        color: secondaryColor,
      ),
      bodySmall: body(
        base.bodySmall,
        size: 11,
        weight: FontWeight.w500,
        color: secondaryColor,
      ),
      labelLarge: body(
        base.labelLarge,
        size: 11,
        weight: FontWeight.w700,
        height: 1.1,
        letterSpacing: 1.2,
        color: bodyColor,
      ),
      labelMedium: body(
        base.labelMedium,
        size: 10,
        weight: FontWeight.w700,
        height: 1.1,
        letterSpacing: 1.0,
        color: secondaryColor,
      ),
      labelSmall: body(
        base.labelSmall,
        size: 9,
        weight: FontWeight.w700,
        height: 1.1,
        letterSpacing: 1.4,
        color: secondaryColor,
      ),
    );
  }
}
