import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminBunkListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final snapshot = await FirebaseFirestore.instance
          .collection('bunks')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['bunkId'] = doc.id;
        return data;
      }).toList();
    });

final adminBunkDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, bunkId) async {
      if (bunkId == 'new') return null; // Logic for creating new
      final doc = await FirebaseFirestore.instance
          .collection('bunks')
          .doc(bunkId)
          .get();
      return doc.data();
    });

class AdminBunkActions {
  final Ref ref;
  AdminBunkActions(this.ref);

  Future<void> createBunk({
    required String name,
    required String location,
    required List<String> managerIds, // Updated to List
    required bool active,
    required List<String> fuelTypes,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('manageBunk').call({
      'action': 'create',
      'name': name,
      'location': location,
      'managerIds': managerIds,
      'active': active,
      'fuelTypes': fuelTypes,
    });
    ref.invalidate(adminBunkListProvider);
  }

  Future<void> updateBunk(String bunkId, Map<String, dynamic> updates) async {
    await FirebaseFunctions.instance.httpsCallable('manageBunk').call({
      'action': 'update',
      'bunkId': bunkId,
      ...updates, // Spread the specific updates
    });
    ref.invalidate(adminBunkListProvider);
    ref.invalidate(adminBunkDetailProvider(bunkId));
  }

  Future<void> deleteBunk(String bunkId) async {
    await FirebaseFunctions.instance.httpsCallable('manageBunk').call({
      'action': 'delete',
      'bunkId': bunkId,
    });
    ref.invalidate(adminBunkListProvider);
  }
}

final adminBunkActionsProvider = Provider((ref) => AdminBunkActions(ref));
