import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bunk_loyalty/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We wrap it in ProviderScope because BunkLoyaltyApp uses Riverpod.
    // Note: This might still fail if Firebase isn't mocked, but at least compiles.
    await tester.pumpWidget(const ProviderScope(child: BunkLoyaltyApp()));
  });
}
