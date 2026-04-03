import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_project_app/src/core/network/backend_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1. A Notifier class that holds and manages the state (the language string).
class LanguageNotifier extends Notifier<String> {
  // The `build` method is where the initial state is created.
  @override
  String build() {
    _loadLanguage(); // 앱 시작 시 DB에서 언어 설정 불러오기
    return 'Japanese'; // Default language
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('language');
    if (savedLang != null) {
      state = savedLang;
    }
  }

  // A method to update the state from the UI.
  Future<void> setLanguage(String newLanguage) async {
    state = newLanguage;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', newLanguage);
  }
}

/// 2. The NotifierProvider that exposes the LanguageNotifier to the app.
final languageProvider = NotifierProvider<LanguageNotifier, String>(() {
  return LanguageNotifier();
});

/// 2.5. A Notifier class that holds and manages the TTS Voice.
class VoiceNotifier extends Notifier<String> {
  @override
  String build() {
    _loadVoice();
    return 'alloy'; // Default voice
  }

  static const _allowedVoices = {'alloy', 'echo', 'shimmer'};

  Future<void> _loadVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVoice = prefs.getString('voice_preset');
    if (savedVoice != null && _allowedVoices.contains(savedVoice)) {
      state = savedVoice;
    } else if (savedVoice != null && !_allowedVoices.contains(savedVoice)) {
      // 지원 종료된 목소리(fable, nova, onyx 등)가 저장되어 있을 경우 alloy로 초기화
      state = 'alloy';
      await prefs.setString('voice_preset', 'alloy');
    }
  }

  Future<void> setVoice(String newVoice) async {
    state = newVoice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_preset', newVoice);
  }
}

final voiceProvider = NotifierProvider<VoiceNotifier, String>(() {
  return VoiceNotifier();
});

/// 3. A Notifier class that holds and manages the greeting message.
class GreetingNotifier extends Notifier<String> {
  @override
  String build() {
    // 언어가 변경되면 현재 인삿말에 대해 다시 프리패치 요청
    ref.listen(languageProvider, (previous, next) {
      prefetch(state);
    });
    // 목소리가 변경되면 현재 인삿말에 대해 다시 프리패치 요청
    ref.listen(voiceProvider, (previous, next) {
      prefetch(state);
    });

    const defaultGreeting = '안녕하세요, AI 통역 비서입니다. 잠시만 기다려주세요.';
    _loadGreeting(); // 앱 시작 시 DB에서 인삿말 불러오기

    // 앱 실행(초기화) 시 기본 인삿말 프리패치
    prefetch(defaultGreeting);
    return defaultGreeting;
  }

  Future<void> _loadGreeting() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGreeting = prefs.getString('greeting');
    if (savedGreeting != null) {
      state = savedGreeting;
      prefetch(state);
    }
  }

  Future<void> setGreeting(String newGreeting) async {
    state = newGreeting;
    // 인삿말 수정 시 즉시 프리패치
    prefetch(newGreeting);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('greeting', newGreeting);
  }

  Future<void> prefetch(String text) async {
    final language = ref.read(languageProvider);
    final voice = ref.read(voiceProvider);
    final backendClient = ref.read(backendClientProvider);
    if (!backendClient.isConfigured) return;

    try {
      await backendClient.prefetchGreeting(
        text: text,
        language: language,
        voice: voice,
      );
    } catch (e) {
      // 프리패치 실패는 사용자에게 알리지 않고 조용히 넘어감 (로그만 출력)
      debugPrint('Greeting prefetch failed: $e');
    }
  }
}

/// 4. The NotifierProvider for the greeting message.
final greetingProvider = NotifierProvider<GreetingNotifier, String>(() {
  return GreetingNotifier();
});

/// 5. 자주 쓰는 문구(Custom Phrases) 관리
class CustomPhrasesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadPhrases();
    return [];
  }

  Future<void> _loadPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList('custom_phrases');
    if (saved != null) state = saved;
  }

  Future<void> addPhrase(String phrase) async {
    if (state.contains(phrase)) return;
    state = [...state, phrase];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_phrases', state);
  }

  Future<void> removePhrase(String phrase) async {
    state = state.where((p) => p != phrase).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_phrases', state);
  }
}

final customPhrasesProvider =
    NotifierProvider<CustomPhrasesNotifier, List<String>>(() {
      return CustomPhrasesNotifier();
    });

/// 6. 목소리 미리듣기 서비스
final voicePreviewProvider = Provider((ref) {
  final backendClient = ref.watch(backendClientProvider);
  return VoicePreviewService(backendClient);
});

class VoicePreviewService {
  VoicePreviewService(this._backendClient);

  final BackendClient _backendClient;

  Future<Uint8List?> fetchPreview(String text, String voice) async {
    if (!_backendClient.isConfigured) return null;

    try {
      return await _backendClient.fetchVoicePreview(text: text, voice: voice);
    } catch (e) {
      debugPrint('Voice preview failed: $e');
    }
    return null;
  }
}

/// 7. AI 중재(번역) 사용 여부 설정
class AiMediationNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadState();
    return true; // 기본값: 켜짐 (번역 수행)
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('ai_mediation');
    if (saved != null) state = saved;
  }

  Future<void> setAiMediation(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_mediation', value);
  }
}

final aiMediationProvider = NotifierProvider<AiMediationNotifier, bool>(() {
  return AiMediationNotifier();
});
