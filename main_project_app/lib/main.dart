import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_project_app/src/app.dart';

Future<void> main() async {
  // 플러터 엔진을 먼저 초기화해야 assets 로드가 가능합니다.
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }
  runApp(const ProviderScope(child: MyApp()));
}
