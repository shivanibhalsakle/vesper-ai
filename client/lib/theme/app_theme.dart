import 'package:flutter/material.dart';

import 'app_motion.dart';

/// The Vesper palette: white pages, brown actions, beige surfaces. Every
/// colour in the app should come from here (via the theme), so changing the
/// look is a one-file edit.
class AppColors {
  const AppColors._();

  static const white = Color(0xFFFFFFFF);

  /// Buttons, selected states, filled bars, links.
  static const brown = Color(0xFF8B4A38);
  static const brownDark = Color(0xFF4A2218);

  /// Cards and input fields.
  static const beige = Color(0xFFFBF1EC);

  /// Card borders and dividers.
  static const beigeBorder = Color(0xFFE8D5CC);

  /// Slightly stronger outline for controls (inputs, outlined buttons).
  static const outline = Color(0xFFD2B5A8);

  /// Soft pink-beige for chips, the best-day tile and other highlights.
  static const blush = Color(0xFFF6DDD3);

  /// Tracks and empty states, a touch deeper than the card beige.
  static const sand = Color(0xFFF1E3DC);

  static const text = Color(0xFF2B1D18);
  static const textSecondary = Color(0xFF7A655D);

  static const error = Color(0xFFB3261E);
  static const errorContainer = Color(0xFFFCE4E0);

  /// The sun, used for the "what you asked for" marker on forecast bars.
  static const sun = Color(0xFFF2A65A);

  /// The dawn-to-dusk spectrum behind sliders and forecast bars: low is
  /// dawn, high is dusk.
  static const spectrum = <Color>[
    Color(0xFFF6C7B6), // dawn blush
    Color(0xFFF9D99A), // first light
    Color(0xFFF2A65A), // amber
    Color(0xFFE5736B), // coral
    Color(0xFFB04F86), // dusk rose
    Color(0xFF5A4A9E), // twilight
  ];
  static const spectrumStops = <double>[0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

  static const spectrumGradient = LinearGradient(colors: spectrum, stops: spectrumStops);

  /// The spectrum colour at [t] (0 = dawn, 1 = dusk); out-of-range values
  /// are clamped.
  static Color spectrumAt(double t) {
    final x = t.clamp(0.0, 1.0);
    for (var i = 1; i < spectrumStops.length; i++) {
      if (x <= spectrumStops[i]) {
        final span = spectrumStops[i] - spectrumStops[i - 1];
        return Color.lerp(spectrum[i - 1], spectrum[i], (x - spectrumStops[i - 1]) / span)!;
      }
    }
    return spectrum.last;
  }
}

const _bodyFont = 'DMSans';
const _headingFont = 'Fraunces';

/// The brush script used for the wordmark, greetings and big scores. It has
/// a single weight and is hard to read in long text, so keep it to short,
/// large moments.
const scriptFont = 'KaushanScript';

const _radius = 16.0;
const _controlRadius = 14.0;

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.brown,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.brown,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.blush,
    onPrimaryContainer: AppColors.brownDark,
    secondary: AppColors.brown,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.blush,
    onSecondaryContainer: AppColors.brownDark,
    surface: AppColors.white,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.beige,
    surfaceContainer: AppColors.beige,
    surfaceContainerHigh: AppColors.blush,
    surfaceContainerHighest: AppColors.sand,
    outline: AppColors.outline,
    outlineVariant: AppColors.beigeBorder,
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.error,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: _bodyFont,
    brightness: Brightness.light,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.white,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: VesperPageTransitionsBuilder(),
        TargetPlatform.iOS: VesperPageTransitionsBuilder(),
        TargetPlatform.macOS: VesperPageTransitionsBuilder(),
        TargetPlatform.windows: VesperPageTransitionsBuilder(),
        TargetPlatform.linux: VesperPageTransitionsBuilder(),
        TargetPlatform.fuchsia: VesperPageTransitionsBuilder(),
      },
    ),
    textTheme: _textTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontFamily: _headingFont,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.beige,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: const BorderSide(color: AppColors.beigeBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.beigeBorder, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brown,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.sand,
        disabledForegroundColor: AppColors.textSecondary,
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_controlRadius)),
        textStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brown,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: AppColors.brown, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_controlRadius)),
        textStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brown,
        textStyle: const TextStyle(
          fontFamily: _bodyFont,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.beige,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      floatingLabelStyle: const TextStyle(color: AppColors.brown),
      border: _inputBorder(AppColors.outline),
      enabledBorder: _inputBorder(AppColors.beigeBorder),
      disabledBorder: _inputBorder(AppColors.beigeBorder),
      focusedBorder: _inputBorder(AppColors.brown, width: 1.6),
      errorBorder: _inputBorder(AppColors.error),
      focusedErrorBorder: _inputBorder(AppColors.error, width: 1.6),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.beige,
      selectedColor: AppColors.blush,
      disabledColor: AppColors.sand,
      checkmarkColor: AppColors.brown,
      side: const BorderSide(color: AppColors.beigeBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(
        fontFamily: _bodyFont,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.blush : AppColors.white,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.brownDark : AppColors.text,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.outline)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_controlRadius)),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 8,
      activeTrackColor: AppColors.brown,
      inactiveTrackColor: AppColors.beigeBorder,
      thumbColor: AppColors.brown,
      overlayColor: AppColors.brown.withValues(alpha: 0.12),
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      // Flat thumb: the default drop shadow reads as a dark ring on white.
      thumbShape: const RoundSliderThumbShape(elevation: 0, pressedElevation: 0),
      valueIndicatorColor: AppColors.brown,
      valueIndicatorTextStyle: const TextStyle(color: AppColors.white),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(AppColors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.brown : AppColors.outline,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.brown,
      textColor: AppColors.text,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.brown,
      collapsedIconColor: AppColors.brown,
      textColor: AppColors.text,
      collapsedTextColor: AppColors.text,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brown,
      linearTrackColor: AppColors.beigeBorder,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.brownDark,
      contentTextStyle: const TextStyle(fontFamily: _bodyFont, color: AppColors.white),
      actionTextColor: AppColors.blush,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_controlRadius)),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(_controlRadius),
      borderSide: BorderSide(color: color, width: width),
    );

/// Fraunces (a warm serif) for display and headline sizes, DM Sans for
/// everything that is read in small print.
TextTheme _textTheme(TextTheme base) {
  TextStyle? heading(TextStyle? style, FontWeight weight) =>
      style?.copyWith(fontFamily: _headingFont, fontWeight: weight, color: AppColors.text);
  TextStyle? body(TextStyle? style, FontWeight weight) =>
      style?.copyWith(fontFamily: _bodyFont, fontWeight: weight);

  TextStyle? script(TextStyle? style) => style?.copyWith(
        fontFamily: scriptFont,
        fontWeight: FontWeight.w400,
        color: AppColors.brown,
      );

  return base.copyWith(
    // Display sizes are the big, short moments (scores, wordmark): script.
    displayLarge: script(base.displayLarge),
    displayMedium: script(base.displayMedium),
    displaySmall: script(base.displaySmall),
    headlineLarge: heading(base.headlineLarge, FontWeight.w600),
    headlineMedium: heading(base.headlineMedium, FontWeight.w600),
    headlineSmall: heading(base.headlineSmall, FontWeight.w600),
    titleLarge: heading(base.titleLarge, FontWeight.w600),
    titleMedium: body(base.titleMedium, FontWeight.w600),
    titleSmall: body(base.titleSmall, FontWeight.w600),
    labelLarge: body(base.labelLarge, FontWeight.w600),
    labelMedium: body(base.labelMedium, FontWeight.w500),
    labelSmall: body(base.labelSmall, FontWeight.w500),
    bodyLarge: body(base.bodyLarge, FontWeight.w400),
    bodyMedium: body(base.bodyMedium, FontWeight.w400),
    bodySmall: body(base.bodySmall, FontWeight.w400)?.copyWith(color: AppColors.textSecondary),
  );
}
