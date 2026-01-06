import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/bunk_management_provider.dart';

class BunkListScreen extends ConsumerStatefulWidget {
  const BunkListScreen({super.key});

  @override
  ConsumerState<BunkListScreen> createState() => _BunkListScreenState();
}

class _BunkListScreenState extends ConsumerState<BunkListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final bunksAsync = ref.watch(adminBunkListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bunk Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin-home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/admin/bunks/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Bunk Name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: bunksAsync.when(
              data: (bunks) {
                final filtered = bunks.where((b) {
                  final name = (b['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No bunks found.'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final bunk = filtered[index];
                    final bunkId = bunk['bunkId'] ?? bunk['id'] ?? '';
                    final active = bunk['active'] != false;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.local_gas_station,
                          color: active ? Colors.green : Colors.grey,
                        ),
                        title: Text(bunk['name'] ?? 'Unnamed Bunk'),
                        subtitle: Text(bunk['location'] ?? 'No Location'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/admin/bunks/$bunkId'),
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
}
