import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_project_app/src/features/incall/presentation/in_call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('같은 문장을 연달아 보내면 두 메시지 모두 번역된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: InCallScreen(callId: 'test_mode', language: 'Japanese'),
        ),
      ),
    );

    for (var i = 0; i < 2; i++) {
      await tester.enterText(find.byType(TextField), '네');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
    }
    expect(find.text('(Sending...)'), findsNWidgets(2));

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('네 (번역됨)'), findsNWidgets(2));
    expect(find.text('(Sending...)'), findsNothing);
  });
}
