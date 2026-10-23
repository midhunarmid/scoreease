import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Extra colours the Material scheme has no slot for.
class ScoreColors extends ThemeExtension<ScoreColors> {
  final Color gold;
  final Color silver;
  final Color bronze;
  final Color positive;
  final Color negative;

  const ScoreColors({
    required this.gold,
    required this.silver,
    required this.bronze,
    required this.positive,
    required this.negative,
  });

  static const light = ScoreColors(
    gold: Color(0xFFD99A00),
    silver: Color(0xFF8A94A6),
    bronze: Color(0xFFB0683A),
    positive: Color(0xFF0E9F6E),
    negative: Color(0xFFDC2626),
  );

  static const dark = ScoreColors(
    gold: Color(0xFFFACC15),
    silver: Color(0xFFCBD5E1),
    bronze: Color(0xFFE59866),
    positive: Color(0xFF34D399),
    negative: Color(0xFFF87171),
  );

  Color? forRank(int rank) => switch (rank) { 1 => gold, 2 => silver, 3 => bronze, _ => null };

  @override
  ScoreColors copyWith({Color? gold, Color? silver, Color? bronze, Color? positive, Color? negative}) => ScoreColors(
        gold: gold ?? this.gold,
        silver: silver ?? this.silver,
        bronze: bronze ?? this.bronze,
        positive: positive ?? this.positive,
        negative: negative ?? this.negative,
      );

  @override
  ScoreColors lerp(ScoreColors? other, double t) {
    if (other == null) return this;
    return ScoreColors(
      gold: Color.lerp(gold, other.gold, t)!,
      silver: Color.lerp(silver, other.silver, t)!,
      bronze: Color.lerp(bronze, other.bronze, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  ScoreColors get scoreColors => Theme.of(this).extension<ScoreColors>() ?? ScoreColors.light;
}

/// Set to false in tests, which have no network to fetch fonts.
bool useGoogleFonts = true;

TextStyle _display({TextStyle? textStyle, double? fontSize, FontWeight? fontWeight, double? height, Color? color, List<FontFeature>? fontFeatures}) =>
    useGoogleFonts
        ? GoogleFonts.spaceGrotesk(
            textStyle: textStyle, fontSize: fontSize, fontWeight: fontWeight, height: height, color: color, fontFeatures: fontFeatures)
        : (textStyle ?? const TextStyle())
            .copyWith(fontSize: fontSize, fontWeight: fontWeight, height: height, color: color, fontFeatures: fontFeatures);

/// Big numbers with fixed-width digits so scores don't jiggle.
TextStyle scoreStyle(BuildContext context, double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
    _display(
      fontSize: size,
      fontWeight: weight,
      height: 1.0,
      color: color ?? context.colors.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: brandSeed, brightness: brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  final textTheme = (useGoogleFonts ? GoogleFonts.interTextTheme(base.textTheme) : base.textTheme).copyWith(
    displayLarge: _display(textStyle: base.textTheme.displayLarge, fontWeight: FontWeight.w700),
    displayMedium: _display(textStyle: base.textTheme.displayMedium, fontWeight: FontWeight.w700),
    displaySmall: _display(textStyle: base.textTheme.displaySmall, fontWeight: FontWeight.w700),
    headlineLarge: _display(textStyle: base.textTheme.headlineLarge, fontWeight: FontWeight.w700),
    headlineMedium: _display(textStyle: base.textTheme.headlineMedium, fontWeight: FontWeight.w700),
    headlineSmall: _display(textStyle: base.textTheme.headlineSmall, fontWeight: FontWeight.w600),
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [brightness == Brightness.dark ? ScoreColors.dark : ScoreColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: Radii.mdAll, side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide(color: scheme.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll)),
    ),
    chipTheme: ChipThemeData(shape: const RoundedRectangleBorder(borderRadius: Radii.smAll), side: BorderSide(color: scheme.outlineVariant)),
    dialogTheme: const DialogThemeData(shape: RoundedRectangleBorder(borderRadius: Radii.lgAll)),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
    ),
    listTileTheme: const ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: Radii.mdAll)),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
