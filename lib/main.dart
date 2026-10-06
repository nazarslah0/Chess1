import 'package:flutter/material.dart';

import 'app.dart';
import 'app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppSettings.instance.load();

  runApp(const ChessAnalyzerApp());
}
