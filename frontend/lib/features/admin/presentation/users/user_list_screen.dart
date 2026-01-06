import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/user_management_provider.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  final _searchController = TextEditingController();
  String _selectedRole = 'All';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider with filter
    // Note: If we change role, we refetch from DB.
    final userListAsync = ref.watch(adminUserListProvider(_selectedRole));

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin-home'),
        ),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Name / Phone',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedRole,
                  items: ['All', 'Customer', 'Manager', 'Admin']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: userListAsync.when(
              data: (users) {
                // Client-side search filtering
                final filtered = users.where((u) {
                  final name = (u['name'] ?? '').toString().toLowerCase();
                  final phone = (u['phoneNumber'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(_searchQuery) ||
                      phone.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    final uid = user['uid'] ?? user['id'] ?? '';
                    final role = user['role'] ?? 'No Role';
                    final isActive =
                        user['active'] != false; // Default true if missing

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(role),
                          child: Icon(_getRoleIcon(role), color: Colors.white),
                        ),
                        title: Text(
                          user['name'] ?? user['phoneNumber'] ?? 'Unknown User',
                        ),
                        subtitle: Text(
                          '${user['phoneNumber'] ?? 'No Phone'} • $role',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isActive)
                              Chip(
                                label: const Text('Disabled'),
                                backgroundColor: Colors.red[100],
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: uid.isNotEmpty
                            ? () => context.push('/admin/users/$uid')
                            : null, // Disable tap if UID is missing
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppTheme.primaryColor;
      case 'manager':
        return Colors.orange;
      case 'customer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.local_gas_station;
      case 'customer':
        return Icons.person;
      default:
        return Icons.help;
    }
  }
}
