import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:main_project_app/src/core/routing/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 파일 로드 (KeypadScreen에서 API URL 사용 시 필요)
  await dotenv.load(fileName: ".env");

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      routerConfig: router,
      title: 'Avoid Call',
      theme: ThemeData(primarySwatch: Colors.blue),
    );
  }
}
