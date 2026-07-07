import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localTestModeProvider = Provider<bool>(
  (ref) => AppConfig.isLocalTestMode,
);

class AppConfig {
  static bool get isLocalTestMode {
    const dartDefineMode = String.fromEnvironment('APP_MODE');
    const dartDefineLocalTest = String.fromEnvironment('LOCAL_TEST_MODE');

    final mode =
        (dartDefineMode.isNotEmpty
                ? dartDefineMode
                : dotenv.env['APP_MODE'] ?? '')
            .trim()
            .toLowerCase();
    final localTest =
        (dartDefineLocalTest.isNotEmpty
                ? dartDefineLocalTest
                : dotenv.env['LOCAL_TEST_MODE'] ?? '')
            .trim()
            .toLowerCase();

    return {'local', 'local_test', 'test'}.contains(mode) ||
        {'1', 'true', 'yes', 'on'}.contains(localTest);
  }
}
