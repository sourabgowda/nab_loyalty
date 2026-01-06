import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';

// Provider to get Manager's Bunk
final managerBunkProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return null;

  final snapshot = await FirebaseFirestore.instance
      .collection('bunks')
      .where('managerIds', arrayContains: user.uid)
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) return null;
  // Inject ID
  final data = snapshot.docs.first.data();
  data['id'] = snapshot.docs.first.id;
  return data;
});
