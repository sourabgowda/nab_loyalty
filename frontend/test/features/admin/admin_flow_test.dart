import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bunk_loyalty/features/admin/presentation/admin_home_screen.dart';
import 'package:bunk_loyalty/features/auth/data/auth_provider.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
  });

  group('Admin Feature Flow', () {
    testWidgets('Admin Home renders dashboard cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(mockAuthRepo)],
          child: const MaterialApp(home: AdminHomeScreen()),
        ),
      );

      // Verify Title
      expect(find.text('Admin Dashboard'), findsOneWidget);

      // Verify Cards
      expect(find.text('Manage Users'), findsOneWidget);
      expect(find.text('Manage Bunks'), findsOneWidget);
      expect(find.text('Global Config'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
    });

    testWidgets('Tapping Manage Users shows Coming Soon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(mockAuthRepo)],
          child: const MaterialApp(home: AdminHomeScreen()),
        ),
      );

      await tester.tap(find.text('Manage Users'));
      await tester.pump(); // Start animation
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // Wait for generic SnackBar duration

      expect(find.text('Manage Users - Coming Soon'), findsOneWidget);
    });
  });
}
