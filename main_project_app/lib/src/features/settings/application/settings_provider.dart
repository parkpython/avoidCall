import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// 1. A Notifier class that holds and manages the state (the language string).
class LanguageNotifier extends Notifier<String> {
  // The `build` method is where the initial state is created.
  @override
  String build() {
    return 'Japanese'; // Default language
  }

  // A method to update the state from the UI.
  void setLanguage(String newLanguage) {
    state = newLanguage;
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
    // 앱 실행(초기화) 시 기본 인삿말 프리패치
    prefetch(defaultGreeting);
    return defaultGreeting;
  }

  void setGreeting(String newGreeting) {
    state = newGreeting;
    // 인삿말 수정 시 즉시 프리패치
    prefetch(newGreeting);
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
