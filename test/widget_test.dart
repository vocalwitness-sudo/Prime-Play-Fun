import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('Lobby screen smoke test', (WidgetTester tester) async {
    // 1. Mock SharedPreferences for the test environment
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // 2. Build our app inside a ProviderScope and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const PrimePlayFunApp(),
      ),
    );

    // 3. Verify that our lobby screen has loaded successfully.
    expect(find.text('Prime Play Fun'), findsOneWidget);
  });
}
