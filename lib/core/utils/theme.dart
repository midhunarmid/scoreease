import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/* Light theme default */
AppColors appColors = AppColorsLight();
ThemeData appTheme = getLightTheme();

/* Dark theme default */
// AppColors appColors = AppColorsDark();
// ThemeData appTheme = getDarkTheme();

ThemeData getLightTheme() {
  return ThemeData(
    scaffoldBackgroundColor: const Color(0xFFF0FDF4),
    applyElevationOverlayColor: false,
    dividerColor: const Color(0xFFE5E7EB),
    brightness: Brightness.light,
    primaryColor: const Color(0xFF10B981),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF10B981),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: TextTheme(
      titleSmall: GoogleFonts.oswald(
        textStyle: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: appColors.textColor),
      ),
      headlineLarge: GoogleFonts.oswald(
          textStyle: TextStyle(
              fontSize: 22.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.bold)),
      headlineMedium: GoogleFonts.oswald(
          textStyle: TextStyle(
              fontSize: 20.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.bold)),
      headlineSmall: GoogleFonts.oswald(
          textStyle: TextStyle(
              fontSize: 18.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.bold)),
      labelLarge: GoogleFonts.urbanist(
          textStyle: TextStyle(
              fontSize: 16.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.bold)),
      labelMedium: GoogleFonts.urbanist(
          textStyle: TextStyle(
              fontSize: 14.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.w500)),
      labelSmall: GoogleFonts.urbanist(
          textStyle: TextStyle(
              fontSize: 12.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.w400)),
    ),
  );
}

ThemeData getDarkTheme() {
  return ThemeData(
    scaffoldBackgroundColor: const Color(0xFF111827),
    applyElevationOverlayColor: true,
    dividerColor: const Color(0xFF374151),
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF10B981),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111827),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: TextTheme(
      titleSmall: GoogleFonts.oswald(
        textStyle: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: appColors.textColor),
      ),
      headlineLarge: GoogleFonts.oswald(
          textStyle: TextStyle(
              fontSize: 22.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.bold)),
      headlineMedium: GoogleFonts.oswald(
          textStyle: TextStyle(
              fontSize: 20.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.bold)),
      headlineSmall: GoogleFonts.oswald(
          textStyle: TextStyle(
              fontSize: 18.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.bold)),
      labelLarge: GoogleFonts.urbanist(
          textStyle: TextStyle(
              fontSize: 16.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.bold)),
      labelMedium: GoogleFonts.urbanist(
          textStyle: TextStyle(
              fontSize: 14.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.w500)),
      labelSmall: GoogleFonts.urbanist(
          textStyle: TextStyle(
              fontSize: 12.sp,
              color: appColors.textColor,
              fontWeight: FontWeight.w400)),
    ),
  );
}

abstract class AppColors {
  final Color screenBg;
  final Color appBarBg;
  final Color progressCircleBg;
  final Color pleasantButtonBg;
  final Color pleasantButtonBgHover;
  final Color buttonTextColor;
  final Color negativeButtonBg;
  final Color negativeButtonBgHover;
  final Color buttonTextColorHover;
  final Color textColor;
  final Color linkTextColor;

  final Color tileBgColor;
  final Color tileBgColorHover;
  final Color tileTextColor;
  final Color tileTextColorHover;

  final InputBorder textInputEnabledBorder;
  final InputBorder textInputFocusedBorder;
  final Color textInputFillColor;
  final TextStyle textInputStyle;
  final TextStyle textInputLabelStyle;
  final TextStyle pleasantButtonTextStyle;
  final TextStyle appBarTextStyle;
  final Color listDividerColor;
  final IconThemeData appBarIconTheme;
  final double appBarElevation;
  final Color primaryColor;
  final Color disableBgColor;
  final Color sideMenuHighlight;
  final Color sideMenuNormal;
  final Color sideMenuDisable;
  final Color sideMenuBg;
  final Color inputBgFill;
  final List<Color> rainbowColors;

  AppColors(
      {required this.screenBg,
      required this.appBarBg,
      required this.progressCircleBg,
      required this.pleasantButtonBg,
      required this.negativeButtonBg,
      required this.buttonTextColor,
      required this.buttonTextColorHover,
      required this.pleasantButtonBgHover,
      required this.negativeButtonBgHover,
      required this.textColor,
      required this.textInputEnabledBorder,
      required this.textInputFocusedBorder,
      required this.textInputFillColor,
      required this.textInputStyle,
      required this.textInputLabelStyle,
      required this.pleasantButtonTextStyle,
      required this.appBarTextStyle,
      required this.listDividerColor,
      required this.appBarIconTheme,
      required this.appBarElevation,
      required this.primaryColor,
      required this.disableBgColor,
      required this.sideMenuHighlight,
      required this.sideMenuNormal,
      required this.sideMenuDisable,
      required this.sideMenuBg,
      required this.inputBgFill,
      required this.rainbowColors,
      required this.linkTextColor,
      required this.tileBgColor,
      required this.tileBgColorHover,
      required this.tileTextColor,
      required this.tileTextColorHover});
}

class AppColorsLight extends AppColors {
  AppColorsLight()
      : super(
          screenBg: const Color(0xFFF0FDF4),
          appBarBg: const Color(0xFF10B981),
          progressCircleBg: const Color(0xFFF59E0B),
          pleasantButtonBg: const Color(0xFF10B981),
          pleasantButtonBgHover: const Color(0xFF059669),
          negativeButtonBg: const Color(0xFFEF4444),
          negativeButtonBgHover: const Color(0xFFDC2626),
          buttonTextColor: Colors.white,
          buttonTextColorHover: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF111827),
          textInputEnabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: Color(0xFFD1FAE5),
            ),
          ),
          textInputFocusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: Color(0xFF10B981),
            ),
          ),
          textInputFillColor: Colors.white,
          textInputStyle: const TextStyle(color: Color(0xFF111827)),
          textInputLabelStyle: const TextStyle(color: Color(0xFF4B5563)),
          pleasantButtonTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          appBarTextStyle: GoogleFonts.oswald(
              textStyle: const TextStyle(color: Colors.white)),
          listDividerColor: const Color(0xFFD1FAE5),
          appBarIconTheme: const IconThemeData(
            color: Colors.white,
          ),
          appBarElevation: 0,
          primaryColor: const Color(0xFF10B981),
          disableBgColor: Colors.black26,
          sideMenuHighlight: const Color(0xFF111827),
          sideMenuNormal: Colors.black45,
          sideMenuDisable: Colors.black12,
          sideMenuBg: Colors.white,
          inputBgFill: const Color(0xFFE5E7EB),
          rainbowColors: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.indigo,
            Colors.purple,
          ],
          linkTextColor: const Color(0xFFF59E0B),
          tileBgColor: Colors.white,
          tileBgColorHover: const Color(0xFFD1FAE5),
          tileTextColor: const Color(0xFF111827),
          tileTextColorHover: const Color(0xFF059669),
        );
}

class AppColorsDark extends AppColors {
  AppColorsDark()
      : super(
          screenBg: const Color(0xFF111827),
          appBarBg: const Color(0xFF111827),
          progressCircleBg: const Color(0xFF10B981),
          pleasantButtonBg: const Color(0xFF10B981),
          pleasantButtonBgHover: const Color(0xFF34D399),
          negativeButtonBg: const Color(0xFFEF4444),
          negativeButtonBgHover: const Color(0xFFF87171),
          buttonTextColor: Colors.white,
          buttonTextColorHover: const Color(0xFFF3F4F6),
          textColor: const Color(0xFFF3F4F6),
          textInputEnabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: Color(0xFF374151),
            ),
          ),
          textInputFocusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: Color(0xFF10B981),
            ),
          ),
          textInputFillColor: const Color(0xFF1F2937),
          textInputStyle: const TextStyle(color: Color(0xFFF3F4F6)),
          textInputLabelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          pleasantButtonTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          appBarTextStyle: GoogleFonts.oswald(
              textStyle: const TextStyle(color: Colors.white)),
          listDividerColor: const Color(0xFF374151),
          appBarIconTheme: const IconThemeData(
            color: Colors.white,
          ),
          appBarElevation: 0,
          primaryColor: const Color(0xFF10B981),
          disableBgColor: Colors.white24,
          sideMenuHighlight: Colors.white,
          sideMenuNormal: Colors.white54,
          sideMenuDisable: Colors.white24,
          sideMenuBg: const Color(0xFF111827),
          inputBgFill: const Color(0xFF374151),
          rainbowColors: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.indigo,
            Colors.purple,
          ],
          linkTextColor: const Color(0xFFF59E0B),
          tileBgColor: const Color(0xFF1F2937),
          tileBgColorHover: const Color(0xFF374151),
          tileTextColor: const Color(0xFFF3F4F6),
          tileTextColorHover: const Color(0xFF10B981),
        );
}
