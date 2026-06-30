// Basic smoke test for the ATSVS College app.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/main.dart';

void main() {
  testWidgets('Login screen shows on first launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();

    await tester.pumpWidget(const ProviderScope(child: ATSVSApp()));
    await tester.pumpAndSettle();

    expect(find.text('ATSVS College'), findsWidgets);
    expect(find.text('Login as Parent'), findsOneWidget);
  });

  test('student login is gated by admin records', () async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();

    // Wrong numbers -> denied.
    expect(await AppState.instance.loginStudent('0000000000', '0000000000'),
        isFalse);
    // Parent number right but student number wrong -> denied.
    expect(await AppState.instance.loginStudent('0000000000', '9876543210'),
        isFalse);
    // Both student number and parent number match -> allowed.
    expect(await AppState.instance.loginStudent('9000000001', '9876543210'),
        isTrue);
  });
}
