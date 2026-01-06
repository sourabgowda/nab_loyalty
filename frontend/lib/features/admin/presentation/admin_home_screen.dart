import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            onPressed: () => context.push('/admin/profile'),
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
        children: [
          _buildCard(
            context,
            "Manage Users",
            Icons.people,
            Colors.blue,
            '/admin/users',
          ),
          _buildCard(
            context,
            "Manage Bunks",
            Icons.local_gas_station,
            Colors.orange,
            '/admin/bunks',
          ),
          _buildCard(
            context,
            "Global Config",
            Icons.settings,
            Colors.grey,
            '/admin/config',
          ),
          _buildCard(
            context,
            "Analytics",
            Icons.analytics,
            Colors.purple,
            '/admin/analytics',
          ),
          // Adding Transactions Shortcut
          _buildCard(
            context,
            "Transactions",
            Icons.receipt_long,
            Colors.green,
            '/admin/transactions',
          ),
          _buildCard(
            context,
            "Audit Logs",
            Icons.history_edu,
            Colors.teal,
            '/admin/audit-logs',
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String route,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
