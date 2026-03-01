import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// 1. 앱이 시작될 때 SharedPreferences 인스턴스를 주입받기 위한 Provider
// (main.dart에서 override 해줄 예정입니다)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// 2. 기기 ID를 관리하는 Provider
final deviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  // 저장된 ID가 있는지 확인
  String? deviceId = prefs.getString('device_id');

  // 없으면 새로 생성 (최초 실행 시)
  if (deviceId == null) {
    deviceId = const Uuid().v4(); // 랜덤 UUID 생성 (예: 123e4567-e89b-...)
    prefs.setString('device_id', deviceId);
  }

  return deviceId;
});
