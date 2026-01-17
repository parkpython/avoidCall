import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// 1. A Notifier class that holds and manages the state (the language string).
class LanguageNotifier extends Notifier<String> {
  // The `build` method is where the initial state is created.
  @override
  String build() {
    _loadLanguage(); // 앱 시작 시 DB에서 언어 설정 불러오기
    return 'Japanese'; // Default language
  }

  Future<void> _loadLanguage() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('user_settings')
          .select('language')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && data['language'] != null) {
        state = data['language'] as String;
      }
    } catch (e) {
      // 에러 발생 시 기본값 유지
      print('Error loading language: $e');
    }
  }

  // A method to update the state from the UI.
  Future<void> setLanguage(String newLanguage) async {
    state = newLanguage;
    await _saveSetting('language', newLanguage);
  }

  Future<void> _saveSetting(String key, String value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        // upsert: 데이터가 있으면 업데이트, 없으면 생성
        await Supabase.instance.client.from('user_settings').upsert({
          'user_id': user.id,
          key: value,
        });
      } catch (e) {
        print('Error saving setting: $e');
      }
    }
  }
}

/// 2. The NotifierProvider that exposes the LanguageNotifier to the app.
final languageProvider = NotifierProvider<LanguageNotifier, String>(() {
  return LanguageNotifier();
});

/// 3. A Notifier class that holds and manages the greeting message.
class GreetingNotifier extends Notifier<String> {
  @override
  String build() {
    // 언어가 변경되면 현재 인삿말에 대해 다시 프리패치 요청
    ref.listen(languageProvider, (previous, next) {
      prefetch(state);
    });

    const defaultGreeting = '안녕하세요, AI 통역 비서입니다. 잠시만 기다려주세요.';
    _loadGreeting(); // 앱 시작 시 DB에서 인삿말 불러오기

    // 앱 실행(초기화) 시 기본 인삿말 프리패치
    prefetch(defaultGreeting);
    return defaultGreeting;
  }

  Future<void> _loadGreeting() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('user_settings')
          .select('greeting')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && data['greeting'] != null) {
        state = data['greeting'] as String;
        prefetch(state); // 불러온 인삿말 프리패치
      }
    } catch (e) {
      print('Error loading greeting: $e');
    }
  }

  Future<void> setGreeting(String newGreeting) async {
    state = newGreeting;
    // 인삿말 수정 시 즉시 프리패치
    prefetch(newGreeting);
    await _saveSetting('greeting', newGreeting);
  }

  Future<void> _saveSetting(String key, String value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('user_settings').upsert({
          'user_id': user.id,
          key: value,
        });
      } catch (e) {
        print('Error saving greeting: $e');
      }
    }
  }

  Future<void> prefetch(String text) async {
    final language = ref.read(languageProvider);
    final backendUrl = dotenv.env['API_URL'] ?? '';
    if (backendUrl.isEmpty) return;

    try {
      var url = backendUrl;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }

      await http.post(
        Uri.parse('$url/prefetch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'language': language}),
      );
    } catch (e) {
      // 프리패치 실패는 사용자에게 알리지 않고 조용히 넘어감 (로그만 출력)
      print('Greeting prefetch failed: $e');
    }
  }
}

/// 4. The NotifierProvider for the greeting message.
final greetingProvider = NotifierProvider<GreetingNotifier, String>(() {
  return GreetingNotifier();
});
