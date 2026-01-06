import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Model for Admin User View
// Reusing/enhancing existing User model approach or Map for flexibility
// For now sending raw Maps or types if available.

final adminUserListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, roleFilter) async {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
        'users',
      );

      if (roleFilter != null && roleFilter.isNotEmpty && roleFilter != 'All') {
        query = query.where('role', isEqualTo: roleFilter.toLowerCase());
      }

      // Order by createdAt desc? standard
      // query = query.orderBy('createdAt', descending: true);
      // Need index? Using default for now.

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    });

final userDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, uid) async {
      // We can use the generic getUserProfile function or direct DB
      // Using generic function from data.ts: getUserProfile({ uid: uid })

      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('getUserProfile')
            .call({'uid': uid});

        final data = result.data as Map<String, dynamic>;
        if (data['user'] != null) {
          return Map<String, dynamic>.from(data['user']);
        }
        return null;
      } catch (e) {
        // Fallback to direct DB if function fails or for dev speed
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        return doc.data();
      }
    });

// Controller for actions
class AdminUserActions {
  final Ref ref;
  AdminUserActions(this.ref);

  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    await FirebaseFunctions.instance.httpsCallable('adminUpdateUser').call({
      'uid': uid,
      ...updates,
    });
    // Invalidate list and detail to refresh
    ref.invalidate(adminUserListProvider);
    ref.invalidate(userDetailProvider(uid));
  }

  Future<void> deleteUser(String uid) async {
    await FirebaseFunctions.instance.httpsCallable('deleteUser').call({
      'uid': uid,
    });
    ref.invalidate(adminUserListProvider);
    // No need to invalidate detail as we will navigate back usually
  }
}

final adminUserActionsProvider = Provider((ref) => AdminUserActions(ref));

// Provider to fetch available managers (not assigned to other bunks)
// Returns list of Users who are managers and NOT in the set of assigned IDs (excluding current bunk)
final availableManagersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, currentBunkId) async {
      // 1. Get all managers
      final managersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .get();
      final allManagers = managersQuery.docs.map((d) {
        final data = d.data();
        data['uid'] = d.id; // Ensure UID is present
        return data;
      }).toList();

      // 2. Get all bunks (to see who is assigned)
      final bunksQuery = await FirebaseFirestore.instance
          .collection('bunks')
          .get();
      final assignedIds = <String>{};

      for (var doc in bunksQuery.docs) {
        if (doc.id == currentBunkId)
          continue; // Ignore the bunk we are currently editing
        final data = doc.data();
        // Support both single managerId (legacy) and list managerIds
        final ids = List<String>.from(data['managerIds'] ?? []);
        if (data['managerId'] != null) ids.add(data['managerId']);

        assignedIds.addAll(ids);
      }

      // 3. Filter
      return allManagers.where((m) => !assignedIds.contains(m['uid'])).toList();
    });
