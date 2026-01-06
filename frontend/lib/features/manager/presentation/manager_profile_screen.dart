import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/manager_bunk_provider.dart';
import '../../auth/data/auth_provider.dart';
import '../../auth/data/user_provider.dart';
import '../presentation/manager_home_screen.dart';

class ManagerProfileScreen extends ConsumerWidget {
  const ManagerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final bunkAsync = ref.watch(managerBunkProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager-home'),
        ),
      ),
      body: userProfile.when(
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.manage_accounts, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  user['name'] ?? 'Manager',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  user['phoneNumber'] ?? '',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                const SizedBox(height: 32),

                // Assigned Bunk
                bunkAsync.when(
                  data: (bunk) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_gas_station),
                      title: Text(
                        bunk != null ? bunk['name'] : 'No Bunk Assigned',
                      ),
                      subtitle: Text(
                        bunk != null ? bunk['location'] : 'Contact Admin',
                      ),
                    ),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Error loading bunk: $e'),
                ),

                const SizedBox(height: 32),

                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PIN Reset flow coming soon.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reset PIN'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) context.go('/login');
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
