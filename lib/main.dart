import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:scoreease/core/navigation/app_router.dart';
import 'package:scoreease/features/landing/presentation/pages/landing_screen.dart';
import 'package:scoreease/core/utils/di.dart';
import 'package:scoreease/core/utils/theme.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  setPathUrlStrategy();
  setupDependencies();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configuring firebase database settings. Enabling unlimited caching.
  // We will be clearing cache in our own way
  if (!kIsWeb) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      splitScreenMode: true,
      minTextAdapt: false,
      fontSizeResolver: FontSizeResolvers.radius,
      builder: (context, child) {
        return MaterialApp.router(
          routerConfig: router,
          title: "scoreease",
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          darkTheme: appTheme,
        );
      },
      child: const LandingScreen(),
    );
  }

  static void debugPrint(Object? object) {
    if (kDebugMode) {
      print(object);
    }
  }
}
