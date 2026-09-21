import 'package:flutter/widgets.dart';
import 'package:touristmar_web/main.dart' show TouristMarApp;

import 'platform/mobile_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await installMobilePlatform();
  runApp(const TouristMarApp());
}
