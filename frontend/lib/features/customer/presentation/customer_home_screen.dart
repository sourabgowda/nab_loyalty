import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../../auth/data/user_provider.dart';
import '../../admin/data/global_config_provider.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loyalty'),
        actions: [
          IconButton(
            onPressed: () => context.push('/customer/profile'),
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: userProfile.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User profile not found.'));
          }

          final points = profile['points'] as num? ?? 0;
          final phoneNumber =
              profile['phoneNumber'] ?? user?.phoneNumber ?? 'N/A';
          // Using UID as the QR content for identification
          final qrContent = profile['uid'] ?? user?.uid ?? '';

          // Redeem Status Logic
          final globalConfig = ref.watch(globalConfigProvider);
          final minRedeem =
              (globalConfig.value?['minRedeemPoints'] as num?)?.toInt() ?? 50;
          final canRedeem = points >= minRedeem;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. QR Code Section
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'Show this to attendant',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        QrImageView(
                          data: qrContent,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          () {
                            String raw = phoneNumber
                                .replaceAll('+91', '')
                                .trim();
                            if (raw.length < 5) return phoneNumber;
                            String first2 = raw.substring(0, 2);
                            String last3 = raw.substring(raw.length - 3);
                            return '+91 $first2 ***** $last3';
                          }(),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 2. Points Section
                Text(
                  'Available Points',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  points.toString(),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: canRedeem ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    canRedeem
                        ? 'Redeemable'
                        : 'Min $minRedeem points to redeem',
                    style: TextStyle(
                      color: canRedeem ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // 3. Transactions Teaser
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/customer/transactions'),
                    icon: const Icon(Icons.history),
                    label: const Text('View Transaction History'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
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
