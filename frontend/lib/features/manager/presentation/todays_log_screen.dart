import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../data/manager_bunk_provider.dart';
import '../data/manager_transaction_provider.dart';

class TodaysLogScreen extends ConsumerWidget {
  const TodaysLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bunkAsync = ref.watch(managerBunkProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Logs"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager-home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Invalidate provider to refresh
              bunkAsync.whenData((bunk) {
                if (bunk != null && bunk['id'] != null) {
                  ref.invalidate(todaysLogsProvider(bunk['id']));
                }
              });
            },
          ),
        ],
      ),
      body: bunkAsync.when(
        data: (bunk) {
          if (bunk == null) {
            return const Center(child: Text("No Bunk Assigned."));
          }
          final String bunkId = bunk['id']; // Ensure ID logic is consistent

          final logsAsync = ref.watch(todaysLogsProvider(bunkId));

          return logsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(child: Text("No transactions today."));
              }

              // Sort DESC just in case
              // Assuming API returns sorted, but safe to client sort:
              // timestamp can be String (ISO) or Timestamp.
              // fetchTransactions returns list of maps.
              // Cloud function usually returns ISO string for dates if sanitized, or Timestamp if direct.
              // Let's handle both or assume standard.

              return ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  // Extract Data
                  // Format: amount, fuelType, timestamp, userId, type (CREDIT/REDEEM)
                  final bool isRedeem =
                      log['type'] == 'REDEEM' || log['isRedeem'] == true;
                  final double amount =
                      (log['amount'] as num?)?.toDouble() ?? 0.0;
                  final String fuelType = log['fuelType'] ?? 'Fuel';

                  // Timestamp
                  // It might be a Map {_seconds: ...} or String.
                  DateTime dt;
                  try {
                    if (log['timestamp'] is String) {
                      dt = DateTime.parse(log['timestamp']);
                    } else if (log['timestamp'] is Timestamp) {
                      dt = (log['timestamp'] as Timestamp).toDate();
                    } else if (log['timestamp'] is Map &&
                        log['timestamp']['_seconds'] != null) {
                      dt = DateTime.fromMillisecondsSinceEpoch(
                        log['timestamp']['_seconds'] * 1000,
                      );
                    } else {
                      dt = DateTime.now();
                    }
                  } catch (e) {
                    dt = DateTime.now();
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRedeem
                          ? Colors.orange[100]
                          : Colors.green[100],
                      child: Icon(
                        isRedeem
                            ? Icons.card_giftcard
                            : Icons.local_gas_station,
                        color: isRedeem ? Colors.orange : Colors.green,
                      ),
                    ),
                    title: Text("Paid: ₹$amount - $fuelType"),
                    subtitle: Text(
                      "${DateFormat('hh:mm a').format(dt)} . ${_getDisplayName(log['userName'])} (${_maskPhone(log['userPhone'] ?? '')})",
                    ),
                    trailing: isRedeem
                        ? Text(
                            "-${log['pointsRedeemed'] ?? 0} Pts",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : Text(
                            "+${(amount / 100).floor()} Pts",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ), // Approx calc, real value hidden?
                    // Better just show "CREDIT"
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Error: $e")),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error loading bunk: $e")),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 5) return phone;
    return "${phone.substring(0, 2)}*****${phone.substring(phone.length - 3)}";
  }

  String _getDisplayName(String? name) {
    if (name == null || name == 'Unknown' || name.isEmpty) return 'Customer';
    return name;
  }
}
