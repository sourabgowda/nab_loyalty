import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:bunk_loyalty/features/customer/presentation/customer_home_screen.dart';
import 'package:bunk_loyalty/features/auth/data/user_provider.dart';
import 'package:bunk_loyalty/features/customer/data/transaction_provider.dart';
import 'package:bunk_loyalty/features/auth/data/auth_provider.dart';
import 'package:bunk_loyalty/core/models/transaction_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../helpers/mocks.mocks.dart';

class MockUser extends Mock implements User {
  @override
  String get uid => 'test_uid';
}

final List<TransactionModel> kTestTransactions = [
  TransactionModel(
    txId: '1',
    userId: 'test_uid',
    bunkId: 'bunk1',
    amount: 1000.0,
    fuelType: 'Petrol',
    type: 'CREDIT', // Customer uses CREDIT/DEBIT/EARN
    points: 100.0,
    timestamp: DateTime.now(),
  ),
];

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockUser mockUser;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockUser = MockUser();
    when(mockAuthRepo.currentUser).thenReturn(mockUser);
  });

  group('Customer Feature Flow', () {
    testWidgets('Customer Home shows Points and QR', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userProfileProvider.overrideWith(
              (ref) => Stream.value({'points': 150}),
            ),
            transactionListProvider.overrideWith((ref) => kTestTransactions),
          ],
          child: const MaterialApp(home: CustomerHomeScreen()),
        ),
      );

      // Allow Stream to emit
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify QR Code section
      expect(find.text('My Loyalty Code'), findsOneWidget);
      // QrImageView uses CustomPaint, hard to find by type?
      // It paints on canvas. We can find by Type `QrImageView`.

      // Verify Points
      expect(find.text('Total Points'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('Eligible for Redemption'), findsOneWidget);

      // Verify Transactions
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('Petrol'), findsOneWidget);
      expect(find.text('+100 pts'), findsOneWidget);
    });
  });
}
