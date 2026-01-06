import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/transaction_model.dart';

final transactionListProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('fetchTransactions')
            .call({'limit': 5});

        final List<dynamic> data = result.data['transactions'] ?? [];
        return data
            .map((e) => TransactionModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        return []; // Return empty on error or rethrow
      }
    });
