import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:main_project_app/src/core/routing/router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:main_project_app/src/core/providers/device_id_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // .env 파일 로드 (KeypadScreen에서 API URL 사용 시 필요)
    await dotenv.load(fileName: ".env");
    // SharedPreferences 미리 로드
    final prefs = await SharedPreferences.getInstance();

    // Supabase 초기화 (서버 연결)
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('Supabase 환경변수가 누락되었습니다. .env 파일을 확인해주세요.');
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    runApp(
      ProviderScope(
        overrides: [
          // 로드된 prefs를 Provider에 주입
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    // 초기화 실패 시 검은 화면 대신 에러 메시지를 띄웁니다.
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  const Text(
                    '앱 초기화 오류',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(e.toString(), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
