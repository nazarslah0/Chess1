import 'dart:async';

import 'package:flutter/material.dart';

import 'ads_service.dart';
import 'app.dart';
import 'app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppSettings.instance.load();

  runApp(const ChessAnalyzerApp());

  // موافقة الخصوصية ثم تهيئة الإعلانات (لا تحجب بدء التطبيق).
  unawaited(AdsService.instance.init());
}
