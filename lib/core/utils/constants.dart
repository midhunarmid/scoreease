import 'package:logger/logger.dart';

const double maxScreenWidth = 640;
const String appBaseUrl = "https://scoreease.armid.in";

Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
