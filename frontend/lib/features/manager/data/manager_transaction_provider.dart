import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';

class ManagerTransactionActions {
  final Ref ref;
  ManagerTransactionActions(this.ref);

  Future<void> addFuel({
    required String bunkId,
    required String userId, // Customer UID
    required String fuelType,
    required double fuelAmount, // Optional often, but standard to track
    required double amountPaid, // Amount in currency
  }) async {
    // Call 'addFuelTransaction' cloud function
    // Expects: { bunkId, userId, fuelType, fuelAmount, amountPaid }
    await FirebaseFunctions.instance.httpsCallable('addFuelTransaction').call({
      'bunkId': bunkId,
      'userId': userId,
      'fuelType': fuelType,
      'fuelAmount': fuelAmount,
      'amountPaid': amountPaid,
    });
    // Can invalidate logs provider here
  }

  Future<List<Map<String, dynamic>>> fetchTodaysLogs(
    String bunkId,
    String managerId,
  ) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await FirebaseFunctions.instance
        .httpsCallable('fetchTransactions')
        .call({
          'bunkId': bunkId,
          'managerId': managerId, // Filter by manager
          'startDate': startOfDay.toUtc().toIso8601String(),
          'endDate': endOfDay.toUtc().toIso8601String(),
        });

    return (result.data['transactions'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

final managerTransactionActionsProvider = Provider(
  (ref) => ManagerTransactionActions(ref),
);

final todaysLogsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, bunkId) async {
      // Get current manager ID to filter "his" transactions
      // We assume the user is logged in if they are on this screen.
      // Importing auth_provider.dart is needed if not already available in scope,
      // but 'ref' can access it.
      // Wait, need to import auth provider.
      final user = ref.watch(authRepositoryProvider).currentUser;
      if (user == null) return [];

      return ref
          .watch(managerTransactionActionsProvider)
          .fetchTodaysLogs(bunkId, user.uid);
    });
