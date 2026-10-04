import 'package:flutter/material.dart';
import 'admin_colors.dart';

abstract final class AdminTheme {
  static ThemeData get light {
    final cs = ColorScheme(
      brightness: Brightness.light,
      primary: AdminColors.gold,
      onPrimary: Colors.white,
      primaryContainer: AdminColors.beigeDeep,
      onPrimaryContainer: AdminColors.charcoal,
      secondary: AdminColors.brownMedium,
      onSecondary: Colors.white,
      secondaryContainer: AdminColors.beige,
      onSecondaryContainer: AdminColors.charcoal,
      tertiary: AdminColors.goldLight,
      onTertiary: AdminColors.charcoal,
      tertiaryContainer: AdminColors.cream,
      onTertiaryContainer: AdminColors.brownMedium,
      error: AdminColors.error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFCECEC),
      onErrorContainer: AdminColors.error,
      surface: AdminColors.pageBg,
      onSurface: AdminColors.charcoal,
      surfaceContainerHighest: AdminColors.beige,
      surfaceContainerHigh: AdminColors.cream,
      surfaceContainer: AdminColors.cream,
      surfaceContainerLow: AdminColors.ivory,
      surfaceContainerLowest: Colors.white,
      outline: AdminColors.beigeDeep,
      outlineVariant: AdminColors.beige,
      inverseSurface: AdminColors.charcoal,
      onInverseSurface: AdminColors.ivory,
      inversePrimary: AdminColors.goldLight,
      shadow: AdminColors.charcoal,
      scrim: AdminColors.charcoal,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AdminColors.pageBg,

      appBarTheme: AppBarTheme(
        backgroundColor: AdminColors.cardBg,
        foregroundColor: AdminColors.charcoal,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: AdminColors.charcoal,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: AdminColors.charcoal),
      ),

      cardTheme: CardThemeData(
        color: AdminColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AdminColors.divider),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.gold,
          foregroundColor: Colors.white,
          minimumSize: const Size(120, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.gold,
          side: const BorderSide(color: AdminColors.gold),
          minimumSize: const Size(120, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.gold,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.beigeDeep),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.beigeDeep),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AdminColors.error, width: 1.5),
        ),
        labelStyle:
            const TextStyle(color: AdminColors.brownLight, fontSize: 13),
        hintStyle:
            const TextStyle(color: AdminColors.brownLight, fontSize: 13),
        prefixIconColor: AdminColors.brownLight,
        suffixIconColor: AdminColors.brownLight,
        isDense: true,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AdminColors.cream,
        selectedColor: AdminColors.beigeDeep,
        labelStyle: const TextStyle(
          color: AdminColors.brownMedium,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AdminColors.beigeDeep),
        ),
        side: const BorderSide(color: AdminColors.beigeDeep),
        checkmarkColor: AdminColors.gold,
      ),

      dividerTheme: const DividerThemeData(
        color: AdminColors.divider,
        thickness: 1,
        space: 1,
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor:
            WidgetStateProperty.all(AdminColors.surfaceVariant),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AdminColors.cream;
          }
          return Colors.white;
        }),
        headingTextStyle: const TextStyle(
          color: AdminColors.brownMedium,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        dataTextStyle: const TextStyle(
          color: AdminColors.charcoal,
          fontSize: 13,
        ),
        columnSpacing: 24,
        horizontalMargin: 20,
        dividerThickness: 1,
        headingRowHeight: 44,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        decoration: BoxDecoration(
          border: Border.all(color: AdminColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        iconColor: AdminColors.brownMedium,
        titleTextStyle: TextStyle(
          color: AdminColors.charcoal,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: AdminColors.brownLight,
          fontSize: 12,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          color: AdminColors.charcoal,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: AdminColors.brownMedium,
          fontSize: 14,
        ),
        elevation: 4,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AdminColors.charcoal,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      textTheme: _textTheme(AdminColors.charcoal, AdminColors.brownMedium,
          AdminColors.brownLight),
    );
  }

  // ── DARK THEME ────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final cs = ColorScheme(
      brightness: Brightness.dark,
      primary: AdminColors.goldLight,
      onPrimary: AdminColors.charcoal,
      primaryContainer: AdminColors.goldDark,
      onPrimaryContainer: Colors.white,
      secondary: AdminColors.goldLight,
      onSecondary: AdminColors.charcoal,
      secondaryContainer: AdminColors.darkSurfaceVariant,
      onSecondaryContainer: AdminColors.darkTextPrimary,
      tertiary: AdminColors.gold,
      onTertiary: Colors.white,
      tertiaryContainer: AdminColors.darkSurfaceVariant,
      onTertiaryContainer: AdminColors.darkTextPrimary,
      error: const Color(0xFFE57373),
      onError: Colors.black,
      errorContainer: const Color(0xFF5C2A2A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: AdminColors.darkCardBg,
      onSurface: AdminColors.darkTextPrimary,
      surfaceContainerHighest: AdminColors.darkSurfaceVariant,
      surfaceContainerHigh: AdminColors.darkSurfaceVariant,
      surfaceContainer: AdminColors.darkCardBg,
      surfaceContainerLow: AdminColors.darkPageBg,
      surfaceContainerLowest: AdminColors.darkPageBg,
      outline: AdminColors.darkDivider,
      outlineVariant: AdminColors.darkDivider,
      inverseSurface: AdminColors.ivory,
      onInverseSurface: AdminColors.charcoal,
      inversePrimary: AdminColors.gold,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AdminColors.darkPageBg,

      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.darkCardBg,
        foregroundColor: AdminColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AdminColors.darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: AdminColors.darkTextPrimary),
      ),

      cardTheme: CardThemeData(
        color: AdminColors.darkCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AdminColors.darkDivider),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.gold,
          foregroundColor: Colors.white,
          minimumSize: const Size(120, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.goldLight,
          side: const BorderSide(color: AdminColors.goldDark),
          minimumSize: const Size(120, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.goldLight,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          minimumSize: const Size(64, 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.darkSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.goldLight, width: 1.5),
        ),
        labelStyle:
            const TextStyle(color: AdminColors.darkTextMuted, fontSize: 13),
        hintStyle:
            const TextStyle(color: AdminColors.darkTextMuted, fontSize: 13),
        prefixIconColor: AdminColors.darkTextMuted,
        suffixIconColor: AdminColors.darkTextMuted,
        isDense: true,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AdminColors.darkSurfaceVariant,
        selectedColor: AdminColors.goldDark,
        labelStyle: const TextStyle(
            color: AdminColors.darkTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AdminColors.darkDivider),
        ),
        side: const BorderSide(color: AdminColors.darkDivider),
        checkmarkColor: AdminColors.goldLight,
      ),

      dividerTheme: const DividerThemeData(
        color: AdminColors.darkDivider,
        thickness: 1,
        space: 1,
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor:
            WidgetStateProperty.all(AdminColors.darkSurfaceVariant),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AdminColors.darkSurfaceVariant;
          }
          return AdminColors.darkCardBg;
        }),
        headingTextStyle: const TextStyle(
            color: AdminColors.darkTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
        dataTextStyle: const TextStyle(
            color: AdminColors.darkTextPrimary, fontSize: 13),
        columnSpacing: 24,
        horizontalMargin: 20,
        dividerThickness: 1,
        headingRowHeight: 44,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 60,
        decoration: BoxDecoration(
          border: Border.all(color: AdminColors.darkDivider),
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        iconColor: AdminColors.darkTextSecondary,
        titleTextStyle: TextStyle(
            color: AdminColors.darkTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500),
        subtitleTextStyle:
            TextStyle(color: AdminColors.darkTextMuted, fontSize: 12),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.darkCardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
            color: AdminColors.darkTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600),
        contentTextStyle: const TextStyle(
            color: AdminColors.darkTextSecondary, fontSize: 14),
        elevation: 4,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AdminColors.darkSurfaceVariant,
        contentTextStyle: const TextStyle(
            color: AdminColors.darkTextPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      textTheme: _textTheme(AdminColors.darkTextPrimary,
          AdminColors.darkTextSecondary, AdminColors.darkTextMuted),
    );
  }

  // ── Shared text theme builder ─────────────────────────────────────────────
  static TextTheme _textTheme(Color primary, Color secondary, Color muted) {
    return TextTheme(
      displayLarge:
          TextStyle(color: primary, fontSize: 32, fontWeight: FontWeight.w700),
      headlineLarge:
          TextStyle(color: primary, fontSize: 22, fontWeight: FontWeight.w700),
      headlineMedium:
          TextStyle(color: primary, fontSize: 20, fontWeight: FontWeight.w600),
      headlineSmall:
          TextStyle(color: primary, fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge:
          TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium:
          TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.w600),
      titleSmall:
          TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600),
      bodyLarge:
          TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.w400),
      bodyMedium:
          TextStyle(color: secondary, fontSize: 13, fontWeight: FontWeight.w400),
      bodySmall:
          TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(
          color: primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3),
      labelMedium:
          TextStyle(color: secondary, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(
          color: muted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3),
    );
  }
}
