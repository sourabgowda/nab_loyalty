import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bunk_loyalty/features/manager/presentation/manager_home_screen.dart';

import 'package:bunk_loyalty/features/customer/data/transaction_provider.dart';
import 'package:bunk_loyalty/core/models/transaction_model.dart';

// Mock Transaction Data
final List<TransactionModel> kTestTransactions = [
  TransactionModel(
    txId: '1',
    userId: 'user1',
    bunkId: 'bunk1',
    amount: 500.0,
    fuelType: 'Petrol',
    type: 'EARN',
    points: 50.0,
    timestamp: DateTime.now(),
  ),
];

void main() {
  const MethodChannel channel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'start') return null; // void
          if (methodCall.method == 'stop') return null;
          if (methodCall.method == 'analyzeImage') return null;
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Manager Feature Flow', () {
    testWidgets('Manager Home shows transactions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionListProvider.overrideWith((ref) => kTestTransactions),
            // Mock auth repo if needed for logout button
            // authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          ],
          child: const MaterialApp(home: ManagerHomeScreen()),
        ),
      );

      expect(find.text('Manager Dashboard'), findsOneWidget);
      expect(find.text('My Bunk Station'), findsOneWidget);
      expect(find.text('Petrol'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.text('Add Fuel'), findsOneWidget);
    });

    /*
    testWidgets('Add Fuel Screen renders scanner and form', (tester) async {
       await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AddFuelScreen()),
        ),
      );
      
      // Should not crash due to mock channel
      expect(find.text('Add Fuel Transaction'), findsOneWidget);
      expect(find.text('Scan Customer QR Code'), findsOneWidget);
      expect(find.text('Fuel Amount (₹)'), findsOneWidget);
    });
    */
  });
}
