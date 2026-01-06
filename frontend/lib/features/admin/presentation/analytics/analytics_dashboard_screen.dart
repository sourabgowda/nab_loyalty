import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/analytics_provider.dart';

import 'package:intl/intl.dart';

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  final String? bunkId;
  final String? initialPeriod;
  final String? initialStartDate;
  final String? initialEndDate;

  const AnalyticsDashboardScreen({
    super.key,
    this.bunkId,
    this.initialPeriod,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState
    extends ConsumerState<AnalyticsDashboardScreen> {
  late String _period; // day, month, year, custom
  DateTime? _date; // Single date for day/month/year modes
  DateTimeRange? _customRange; // For custom mode

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod ?? 'day';

    // Initialize Custom Range if provided
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      _customRange = DateTimeRange(
        start: DateTime.parse(widget.initialStartDate!),
        end: DateTime.parse(widget.initialEndDate!),
      );
    }

    // Default single date (used for day/month/year logic)
    _date = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Construct Filter
    final filter = AnalyticsFilter(
      period: _period,
      date: _date,
      bunkId: widget.bunkId,
      startDate: _customRange?.start.toIso8601String(),
      endDate: _customRange?.end.toIso8601String(),
    );

    final analyticsAsync = ref.watch(analyticsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.pop(), // Pop to return to list, don't hardcode route
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'day', label: Text('Daily')),
                      ButtonSegment(value: 'month', label: Text('Monthly')),
                      ButtonSegment(value: 'year', label: Text('Yearly')),
                      ButtonSegment(value: 'custom', label: Text('Custom')),
                    ],
                    selected: {_period},
                    onSelectionChanged: (Set<String> newSelection) async {
                      final newPeriod = newSelection.first;
                      if (newPeriod == 'custom') {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: _customRange,
                        );
                        if (picked != null) {
                          setState(() {
                            _period = 'custom';
                            _customRange = picked;
                          });
                        }
                      } else {
                        setState(() {
                          _period = newPeriod;
                          _customRange = null; // Clear range
                          _date = DateTime.now(); // Reset base date
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Date Picker Button (Only for Non-Custom Modes)
                if (_period != 'custom')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_formatDateLabel()),
                    onPressed: _pickDate,
                  ),

                // Custom Range Display
                if (_period == 'custom' && _customRange != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "${DateFormat('MMM d, yyyy').format(_customRange!.start)} - ${DateFormat('MMM d, yyyy').format(_customRange!.end)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
    if (_period == 'day') return DateFormat('EEE, MMM d, yyyy').format(_date!);
    if (_period == 'month') return DateFormat('MMMM yyyy').format(_date!);
    return DateFormat('yyyy').format(_date!);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Logic varies by period (Year picker vs Month picker vs Day picker)
    // For simplicity, standard day picker is used.
    // Ideally, monthly/yearly modes need specialized pickers or just picking any day in that period.
    final picked = await showDatePicker(
      context: context,
      initialDate: _date!,
      firstDate: DateTime(2023),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Widget _buildContent(AnalyticsResponse data) {
    if (data.totals.transactionCount == 0 && data.totals.totalFuelAmount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "No Data found for this period.",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header info if available
        if (data.bunkDetails != null) ...[
          Text(
            data.bunkDetails!['name'] ?? 'Unknown Bunk',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            data.bunkDetails!['location'] ?? '',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Divider(),
        ],

        // Totals Card
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overview', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
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
                leading: CircleAvatar(
                  child: Text(mName.isNotEmpty ? mName[0] : 'U'),
                ),
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
