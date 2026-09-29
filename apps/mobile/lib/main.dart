import 'package:flutter/widgets.dart';
import 'package:touristmar_web/main.dart' show TouristMarApp;
import 'package:touristmar_web/services/experiencias_launcher.dart';

import 'ar/unity_experiencias_launcher.dart';
import 'platform/mobile_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await installMobilePlatform();
  ExperienciasLauncher.current = await UnityExperienciasLauncher.crear();
  runApp(const TouristMarApp());
}
