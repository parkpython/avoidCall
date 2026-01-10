import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return '안녕하세요, AI 통역 비서입니다. 잠시만 기다려주세요.'; // Default greeting
  }

  void setGreeting(String newGreeting) {
    state = newGreeting;
  }
}

/// 4. The NotifierProvider for the greeting message.
final greetingProvider = NotifierProvider<GreetingNotifier, String>(() {
  return GreetingNotifier();
});
