import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase의 인증 상태 변경 스트림을 구독하는 Provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// 현재 로그인된 사용자 객체를 반환하는 Provider (로그인 안 되어 있으면 null)
final userProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user ??
      Supabase.instance.client.auth.currentUser;
});

/// 로그인 여부를 boolean으로 반환하는 Provider
final isLoggedInProvider = Provider<bool>((ref) {
  final user = ref.watch(userProvider);
  return user != null;
});
