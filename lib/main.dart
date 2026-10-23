import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'design/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await setupDependencies();
  // Lay out text with the real fonts from the first frame; otherwise chips
  // and buttons measured with a fallback font clip their labels. Offline on
  // first run we carry on with system fonts.
  buildTheme(Brightness.light);
  GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w500);
  GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600);
  GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700);
  await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 3), onTimeout: () => const []).catchError((_) => const []);
  runApp(const ScoreEaseApp());
}
