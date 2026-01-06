import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_provider.dart';

class CustomerTransactionsScreen extends ConsumerStatefulWidget {
  const CustomerTransactionsScreen({super.key});

  @override
  ConsumerState<CustomerTransactionsScreen> createState() =>
      _CustomerTransactionsScreenState();
}

class _CustomerTransactionsScreenState
    extends ConsumerState<CustomerTransactionsScreen> {
  final List<Map<String, dynamic>> _transactions = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  static const int _limit = 10;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchInitialTransactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMore &&
        !_isLoadingMore) {
      _loadMoreTransactions();
    }
  }

  Future<void> _fetchInitialTransactions() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final query = FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(_limit);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      if (snapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (mounted) {
        setState(() {
          _transactions.clear();
          _transactions.addAll(snapshot.docs.map((doc) => doc.data()).toList());
        });
      }
    } catch (e) {
      debugPrint('Error fetching initial transactions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) return;

      final query = FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_limit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newItems = snapshot.docs.map((d) => d.data()).toList();
        if (mounted) {
          setState(() {
            _transactions.addAll(newItems);
          });
        }
      }

      if (snapshot.docs.length < _limit) {
        if (mounted) setState(() => _hasMore = false);
      }
    } catch (e) {
      // Handle silently
      debugPrint('Error loading more transactions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/customer-home'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
          ? const Center(child: Text('No transactions yet.'))
          : ListView.builder(
              controller: _scrollController,
              itemCount: _transactions.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _transactions.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final tx = _transactions[index];
                final type = tx['type'] ?? 'UNKNOWN';
                final isCredit = type == 'CREDIT';
                final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                final points = (tx['points'] as num?)?.toInt() ?? 0;

                DateTime dt = DateTime.now();
                if (tx['timestamp'] is Timestamp) {
                  dt = (tx['timestamp'] as Timestamp).toDate();
                }

                final dateStr = DateFormat('MMM dd, yyyy • HH:mm').format(dt);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCredit
                          ? Colors.green[100]
                          : Colors.orange[100],
                      child: Icon(
                        isCredit ? Icons.local_gas_station : Icons.redeem,
                        color: isCredit ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text(
                      isCredit ? 'Fuel Purchase' : 'Points Redemption',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(dateStr),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isCredit ? '+' : '-'}${points.abs()} Pts',
                          style: TextStyle(
                            color: isCredit ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (amount > 0)
                          Text(
                            '₹$amount',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
