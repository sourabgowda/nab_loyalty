import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Stream the config
final globalConfigProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('globalConfig')
      .doc('main')
      .snapshots()
      .map((snapshot) => snapshot.data());
});

class AdminConfigActions {
  final Ref ref;
  AdminConfigActions(this.ref);

  Future<void> updateConfig({
    required double pointValue,
    required double creditPercentage,
    required double minRedeemPoints,
    required double maxFuelAmount,
    required List<String> fuelTypes,
  }) async {
    final func = FirebaseFunctions.instance.httpsCallable('updateGlobalConfig');
    await func.call({
      'pointValue': pointValue,
      'creditPercentage': creditPercentage,
      'minRedeemPoints': minRedeemPoints,
      'maxFuelAmount': maxFuelAmount,
      'fuelTypes': fuelTypes,
    });
  }
}

final adminConfigActionsProvider = Provider((ref) => AdminConfigActions(ref));
