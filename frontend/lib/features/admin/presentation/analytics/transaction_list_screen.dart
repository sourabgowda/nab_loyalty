import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../data/analytics_provider.dart';
import '../../data/global_config_provider.dart';
import 'package:intl/intl.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _limitController = TextEditingController(text: '20');
  String _selectedType = 'All';
  String _selectedFuelType = 'All';

  // Assuming we might have Bunk list to filter by Bunk ID?
  // For now simple text input for Bunk ID or dropdown if we fetched bunks.
  // Using Text Field for Bunk ID to keep it simple as BunkListProvider is separate.
  final _bunkIdController = TextEditingController();

  @override
  void dispose() {
    _limitController.dispose();
    _bunkIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int limit = int.tryParse(_limitController.text) ?? 20;

    final filter = TransactionFilter(
      limit: limit,
      type: _selectedType,
      fuelType: _selectedFuelType,
      bunkId: _bunkIdController.text,
    );

    final transactionsAsync = ref.watch(adminTransactionListProvider(filter));

    final configAsync = ref.watch(globalConfigProvider);
    final fuelTypes = configAsync.value?['fuelTypes'] is List
        ? List<String>.from(configAsync.value!['fuelTypes'])
        : ['Petrol', 'Diesel']; // Fallback

    final dropdownItems = ['All', ...fuelTypes];
    // Ensure selected value is valid
    if (!dropdownItems.contains(_selectedFuelType)) {
      _selectedFuelType = 'All';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin-home'),
        ),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: ['All', 'CREDIT', 'REDEEM']
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedType = val!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _selectedFuelType,
                            decoration: const InputDecoration(
                              labelText: 'Fuel',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: dropdownItems
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedFuelType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _bunkIdController,
                            decoration: const InputDecoration(
                              labelText: 'Bunk ID',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(
                              () {},
                            ), // Trigger rebuild debounced? No, explicit refresh needed?
                            // Actually watch is reactive to filter object changes.
                            // But TextField onChanged fires every char.
                            // Better to have "Apply" button or debounce.
                            // Implementing Apply button.
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _limitController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Limit',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => setState(() {}),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(child: Text('No transactions recorded.'));
                }

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final type = tx['type'] ?? 'UNKNOWN';
                    final isCredit = type == 'CREDIT';
                    final amount = tx['amount'] ?? 0;
                    final points = tx['points'] ?? 0;
                    final date = _parseTimestamp(tx['timestamp']);
                    final dateStr = date != null
                        ? DateFormat('MM/dd HH:mm').format(date)
                        : 'No Date';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCredit
                              ? Colors.green[100]
                              : Colors.orange[100],
                          child: Icon(
                            isCredit ? Icons.add : Icons.remove,
                            color: isCredit ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(
                          '${isCredit ? '+' : '-'}${points.abs()} Points',
                        ),
                        subtitle: Text(
                          '$dateStr • ${tx['fuelType']} • ₹$amount\n'
                          '${tx['bunkName'] ?? 'Bunk: ' + (tx['bunkId'] ?? '?')}\n'
                          'Config: Rate ${tx['pointValue'] ?? '?'} pts/₹ | ${tx['creditPercentage'] ?? '?'}%',
                        ),
                        isThreeLine: true,
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

  DateTime? _parseTimestamp(dynamic rawTs) {
    if (rawTs == null) return null;
    if (rawTs is Timestamp) return rawTs.toDate();
    if (rawTs is Map) {
      if (rawTs.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(
          (rawTs['_seconds'] as int) * 1000,
        );
      }
      if (rawTs.containsKey('seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(
          (rawTs['seconds'] as int) * 1000,
        );
      }
    }
    if (rawTs is String) return DateTime.tryParse(rawTs);
    return null;
  }
}
