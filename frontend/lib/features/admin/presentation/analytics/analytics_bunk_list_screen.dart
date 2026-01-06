import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/analytics_provider.dart';

class AnalyticsBunkListScreen extends ConsumerStatefulWidget {
  const AnalyticsBunkListScreen({super.key});

  @override
  ConsumerState<AnalyticsBunkListScreen> createState() =>
      _AnalyticsBunkListScreenState();
}

class _AnalyticsBunkListScreenState
    extends ConsumerState<AnalyticsBunkListScreen> {
  // Filters
  AnalyticsFilter _filter = const AnalyticsFilter(period: 'day');
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // 1. Fetch Aggregated Bunk List
    // We passgroupBy: 'bunk' to get the list of bunks with totals
    final filterWithGroup = _filter.copyWith(groupBy: 'bunk');
    final analyticsAsync = ref.watch(analyticsProvider(filterWithGroup));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Overview'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Period Toggle
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'day', label: Text('Today')),
                    ButtonSegment(value: 'month', label: Text('Month')),
                    ButtonSegment(value: 'year', label: Text('Year')),
                    ButtonSegment(value: 'custom', label: Text('Custom')),
                  ],
                  selected: {_filter.period},
                  onSelectionChanged: (Set<String> newSelection) async {
                    final newPeriod = newSelection.first;
                    if (newPeriod == 'custom') {
                      // Open Date Range Picker
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange:
                            (_filter.startDate != null &&
                                _filter.endDate != null)
                            ? DateTimeRange(
                                start: DateTime.parse(_filter.startDate!),
                                end: DateTime.parse(_filter.endDate!),
                              )
                            : null,
                      );
                      if (picked != null) {
                        setState(() {
                          _filter = _filter.copyWith(
                            period: 'custom',
                            startDate: picked.start.toIso8601String(),
                            endDate: picked.end.toIso8601String(),
                          );
                        });
                      }
                    } else {
                      setState(() {
                        // Clear custom dates if switching back to preset
                        _filter = _filter.copyWith(
                          period: newPeriod,
                          startDate: null,
                          endDate: null,
                        );
                      });
                    }
                  },
                ),
              ),
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search Bunks...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ],
          ),
        ),
      ),
      body: analyticsAsync.when(
        data: (response) {
          final bunks = response.bunks ?? [];
          print("UI Check: bunks length = ${bunks.length}");

          if (bunks.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("No Data Available in Bunk List"),
                    const SizedBox(height: 20),
                    const Text(
                      "Debug Info:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(
                        "Period: $_filter\n"
                        "Totals: Fuel=${response.totals.totalFuelAmount}\n"
                        "Bunks Type: ${response.bunks?.runtimeType}\n"
                        "Bunks Raw: ${response.bunks}",
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Filter by Search
          final filteredBunks = bunks.where((b) {
            // Safe Cast
            final map = Map<String, dynamic>.from(b as Map);
            final name = (map['bunkName'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          if (filteredBunks.isEmpty && _searchQuery.isNotEmpty) {
            return const Center(child: Text("No bunks match your search"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredBunks.length,
            itemBuilder: (context, index) {
              final bunk = Map<String, dynamic>.from(
                filteredBunks[index] as Map,
              );
              return _buildBunkCard(context, bunk);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: SelectableText('Error: $err\nStack: $stack')),
      ),
    );
  }

  Widget _buildBunkCard(BuildContext context, Map<String, dynamic> bunk) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final totalFuel = bunk['totalFuelAmount'] ?? 0;
    final totalPaid = bunk['totalPaidAmount'] ?? 0;
    final bunkName = bunk['bunkName'] ?? 'Unknown Bunk';
    final bunkId = bunk['bunkId'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to Detailed Dashboard
          // We pass the CURRENT filter settings so the detail view opens in the same state
          final queryParams = {'bunkId': bunkId, 'period': _filter.period};
          if (_filter.startDate != null)
            queryParams['startDate'] = _filter.startDate;
          if (_filter.endDate != null) queryParams['endDate'] = _filter.endDate;

          context.pushNamed(
            'analytics_dashboard',
            queryParameters: queryParams,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bunkName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    context,
                    'Fuel',
                    currencyFormat.format(totalFuel),
                    Colors.blue,
                  ),
                  _buildStatItem(
                    context,
                    'Paid',
                    currencyFormat.format(totalPaid),
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
