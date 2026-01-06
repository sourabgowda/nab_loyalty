import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/analytics_provider.dart';

import 'package:intl/intl.dart';

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState
    extends ConsumerState<AnalyticsDashboardScreen> {
  String _period = 'day'; // day, month, year
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // 1. Construct Filter
    final filter = AnalyticsFilter(
      period: _period,
      date: _selectedDate,
      // Global dashboard or specific bunk?
      // User didn't specify context, assuming specific Bunk context is often passed
      // or this is the "Global" view. Backend handles 'no bunkId' by fetchng what?
      // Backend fetchAnalytics: if no bunkId, query constrained by date.
      // But for aggregation it might return mixed data?
      // Step 2239: backend uses bunkId in query IF present. If not, it just queries by date range across all daily stats?
      // Yes. So it aggregates EVERY bunk's daily stats if bunkId is null.
      // This is perfect for "Global Analytics".
      bunkId: null, // For Admin Home dashboard, usually global.
    );

    final analyticsAsync = ref.watch(analyticsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin-home'),
        ),
      ),
      body: Column(
        children: [
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Period Toggle
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'day', label: Text('Daily')),
                    ButtonSegment(value: 'month', label: Text('Monthly')),
                    ButtonSegment(value: 'year', label: Text('Yearly')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _period = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Date Picker Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_formatDateLabel()),
                  onPressed: _pickDate,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: analyticsAsync.when(
              data: (data) => _buildContent(data),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateLabel() {
    if (_period == 'day')
      return DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
    if (_period == 'month')
      return DateFormat('MMMM yyyy').format(_selectedDate);
    return DateFormat('yyyy').format(_selectedDate);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildContent(AnalyticsResponse data) {
    print(
      "UI Received Data: Fuel=${data.totals.totalFuelAmount}, Count=${data.totals.transactionCount}",
    );
    if (data.totals.transactionCount == 0 && data.totals.totalFuelAmount == 0) {
      print("UI: Showing No Data Message");
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "No Data found for this period.\nDebug: Fuel=${data.totals.totalFuelAmount}, Count=${data.totals.transactionCount}",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Totals Card
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Divider(),
                _statRow('Total Fuel', '₹${data.totals.totalFuelAmount}'),
                _statRow('Total Paid', '₹${data.totals.totalPaidAmount}'),
                _statRow(
                  'Points Distributed',
                  '${data.totals.totalPointsDistributed}',
                ),
                _statRow(
                  'Points Redeemed',
                  '${data.totals.totalPointsRedeemed}',
                ),
                _statRow('Transactions', '${data.totals.transactionCount}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Manager Breakdown
        if (data.managers.isNotEmpty) ...[
          Text(
            'Manager Performance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...data.managers.map((m) {
            final mName = m['managerName'] ?? 'Unknown';
            final mFuel = m['fuelAmount'] ?? 0;
            final mPaid = m['paidAmount'] ?? 0;
            final mCount = m['txCount'] ?? 0;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(mName[0])),
                title: Text(mName),
                subtitle: Text('Tx: $mCount • Fuel: ₹$mFuel'),
                trailing: Text(
                  '₹$mPaid',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }).toList(),
        ] else
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("No Manager Data recorded."),
          ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
