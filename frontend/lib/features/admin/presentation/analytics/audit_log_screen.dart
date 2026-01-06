import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/analytics_provider.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch last 50 logs
    final logsAsync = ref.watch(auditLogProvider(50));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin-home'),
        ),
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No audit logs found.'));
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              return _buildAuditLogTile(context, logs[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading logs: $err')),
      ),
    );
  }

  String _humanReadableTitle(String type, Map<String, dynamic> log) {
    // Try to find a name if available in details, otherwise fallback to generic
    // We could try to resolve Actor/Target IDs here if we had a cache.
    // For now, simplify the action name.

    String action = type;
    switch (type) {
      case 'CREATE':
        action = 'Created';
        break;
      case 'UPDATE':
        action = 'Updated';
        break;
      case 'DELETE':
        action = 'Deleted';
        break;
      case 'DISABLE':
        action = 'Disabled';
        break;
      case 'PIN_RESET':
        action = 'PIN Reset';
        break;
    }

    String target = '';
    if (log['targetUserId'] != null)
      target = 'User';
    else if (log['targetBunkId'] != null)
      target = 'Bunk';
    else if (log['targetConfigId'] != null)
      target = 'Config';

    return '$action $target';
  }

  Widget _buildAuditLogTile(BuildContext context, Map<String, dynamic> log) {
    final String changeType = log['changeType'] ?? 'UNKNOWN';
    final DateTime? date = _parseTimestamp(log['timestamp']);
    final String dateStr = date != null
        ? DateFormat('MMM dd HH:mm').format(date)
        : 'No Date';

    // Actor Details
    final String actorName = log['actorName'] ?? 'Unknown';
    final String actorPhone = log['actorPhone'] ?? log['actorId'] ?? '?';
    final String actorText = '$actorName ($actorPhone)';

    // Target Details
    String targetText = '';
    if (log['targetUserId'] != null) {
      final tName = log['targetName'] ?? 'User';
      final tPhone = log['targetPhone'] ?? log['targetUserId'];
      targetText = 'Target: $tName ($tPhone)';
    } else if (log['targetBunkId'] != null) {
      targetText = 'Target Bunk: ${log['targetBunkId']}';
    }

    // Change Details
    final detailsMap = log['details'] as Map<String, dynamic>? ?? {};
    String detailsText = _formatDetails(changeType, detailsMap);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showLogDetails(context, log),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getColorForType(changeType),
                    radius: 20,
                    child: _getIconForType(changeType),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _humanReadableTitle(changeType, log),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'by $actorText',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              if (targetText.isNotEmpty || detailsText.isNotEmpty) ...[
                const Divider(height: 16),
                if (targetText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      targetText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (detailsText.isNotEmpty)
                  Text(
                    detailsText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.3,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDetails(String type, Map<String, dynamic> details) {
    if (type == 'UPDATE' && details['updates'] != null) {
      final updates = details['updates'] as Map<String, dynamic>;
      return updates.entries
          .where((e) => e.key != 'updatedAt')
          .map((e) {
            final val = e.value;
            if (val is Map &&
                val.containsKey('from') &&
                val.containsKey('to')) {
              return '• Changed ${e.key}: "${val['from']}" -> "${val['to']}"';
            }
            return '• Changed ${e.key}: $val';
          })
          .join('\n');
    }

    // Generic formatter
    return details.entries
        .where((e) => !['updatedAt', 'collection', 'id', 'uid'].contains(e.key))
        .map((e) => '• ${e.key}: ${e.value}')
        .join('\n');
  }

  DateTime? _parseTimestamp(dynamic rawTs) {
    if (rawTs is Timestamp) return rawTs.toDate();
    if (rawTs is Map) {
      if (rawTs['_seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (rawTs['_seconds'] as int) * 1000,
        );
      }
      if (rawTs['seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (rawTs['seconds'] as int) * 1000,
        );
      }
    }
    if (rawTs is String) return DateTime.tryParse(rawTs);
    return null;
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'CREATE':
        return Colors.green.shade100;
      case 'UPDATE':
        return Colors.blue.shade100;
      case 'DELETE':
        return Colors.red.shade100;
      case 'DISABLE':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Icon _getIconForType(String type) {
    switch (type) {
      case 'CREATE':
        return const Icon(Icons.add, color: Colors.green);
      case 'UPDATE':
        return const Icon(Icons.edit, color: Colors.blue);
      case 'DELETE':
        return const Icon(Icons.delete, color: Colors.red);
      case 'DISABLE':
        return const Icon(Icons.block, color: Colors.orange);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }

  void _showLogDetails(BuildContext context, Map<String, dynamic> log) {
    final details = log['details'] as Map<String, dynamic>? ?? {};
    final String content = details.entries
        .map((e) => '${e.key}:\n${e.value}')
        .join('\n\n');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${log['changeType']} Details'),
        content: SingleChildScrollView(
          child: Text(content.isEmpty ? 'No additional details' : content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
