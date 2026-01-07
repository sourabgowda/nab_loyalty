import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Admin Transaction List Provider with Filters
class TransactionFilter {
  final String? bunkId;
  final String? fuelType;
  final String? type; // CREDIT / REDEEM
  final int limit;

  TransactionFilter({this.bunkId, this.fuelType, this.type, this.limit = 20});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TransactionFilter &&
        other.bunkId == bunkId &&
        other.fuelType == fuelType &&
        other.type == type &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    return bunkId.hashCode ^ fuelType.hashCode ^ type.hashCode ^ limit.hashCode;
  }
}

class BunkDailyStats {
  final String id;
  final String bunkId;
  final String date;
  final num totalFuelAmount;
  final num totalPaidAmount;
  final num totalPointsDistributed;
  final num totalPointsRedeemed;
  final int transactionCount;
  final Map<String, dynamic>? managers;
  final String? bunkName;

  BunkDailyStats({
    required this.id,
    required this.bunkId,
    required this.date,
    required this.totalFuelAmount,
    this.totalPaidAmount = 0,
    required this.totalPointsDistributed,
    required this.totalPointsRedeemed,
    required this.transactionCount,
    this.managers,
    this.bunkName,
  });

  factory BunkDailyStats.fromMap(Map<String, dynamic> map) {
    return BunkDailyStats(
      id: map['id']?.toString() ?? '',
      bunkId: map['bunkId']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      totalFuelAmount: (map['totalFuelAmount'] as num?)?.toDouble() ?? 0.0,
      totalPaidAmount: (map['totalPaidAmount'] as num?)?.toDouble() ?? 0.0,
      totalPointsDistributed:
          (map['totalPointsDistributed'] as num?)?.toInt() ?? 0,
      totalPointsRedeemed: (map['totalPointsRedeemed'] as num?)?.toInt() ?? 0,
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
      managers: map['managers'],
      bunkName: map['bunkName'],
    );
  }

  factory BunkDailyStats.empty() {
    return BunkDailyStats(
      id: 'empty',
      bunkId: '',
      date: '',
      totalFuelAmount: 0,
      totalPaidAmount: 0,
      totalPointsDistributed: 0,
      totalPointsRedeemed: 0,
      transactionCount: 0,
      managers: {},
    );
  }
}

final adminTransactionListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, TransactionFilter>((ref, filter) async {
      // Using backend function 'fetchTransactions'
      final params = <String, dynamic>{'limit': filter.limit};
      if (filter.bunkId != null && filter.bunkId!.isNotEmpty) {
        params['bunkId'] = filter.bunkId;
      }
      if (filter.fuelType != null &&
          filter.fuelType!.isNotEmpty &&
          filter.fuelType != 'All') {
        params['fuelType'] = filter.fuelType;
      }
      if (filter.type != null &&
          filter.type!.isNotEmpty &&
          filter.type != 'All') {
        params['type'] = filter.type;
      }

      print(
        "Refetching Transactions. Filter: ${filter.limit}, Bunk: ${filter.bunkId}",
      );
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('fetchTransactions')
            .call(params);

        final data = result.data;

        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['transactions'] is List) {
          return (data['transactions'] as List).cast<Map<String, dynamic>>();
        }
        return [];
      } catch (e, st) {
        // ignore: avoid_print
        // print("FetchTransactions Error: $e");
        // print(st);
        return [];
      }
    });

// Analytics Filter for Period selection
class AnalyticsFilter {
  final String period; // 'day', 'month', 'year', 'custom'
  final DateTime? date;
  final String? bunkId;
  final String? groupBy; // 'bunk' or null
  final String? startDate; // ISO String
  final String? endDate; // ISO String

  const AnalyticsFilter({
    this.period = 'day',
    this.date,
    this.bunkId,
    this.groupBy,
    this.startDate,
    this.endDate,
  });

  // CopyWith helper
  AnalyticsFilter copyWith({
    String? period,
    DateTime? date,
    String? bunkId,
    String? groupBy,
    String? startDate,
    String? endDate,
  }) {
    return AnalyticsFilter(
      period: period ?? this.period,
      date: date ?? this.date,
      bunkId: bunkId ?? this.bunkId,
      groupBy: groupBy ?? this.groupBy,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnalyticsFilter &&
        other.period == period &&
        other.date == date &&
        other.bunkId == bunkId &&
        other.groupBy == groupBy &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode =>
      period.hashCode ^
      date.hashCode ^
      bunkId.hashCode ^
      groupBy.hashCode ^
      startDate.hashCode ^
      endDate.hashCode;
}

class AnalyticsResponse {
  final BunkDailyStats totals;
  final List<dynamic> managers;
  final Map<String, dynamic>? bunkDetails;
  final List<dynamic>? bunks; // For Bunk List View

  AnalyticsResponse({
    required this.totals,
    required this.managers,
    this.bunkDetails,
    this.bunks,
  });

  factory AnalyticsResponse.fromMap(Map<String, dynamic> map) {
    return AnalyticsResponse(
      totals: BunkDailyStats.fromMap(
        map['totals'] != null ? Map<String, dynamic>.from(map['totals']) : {},
      ),
      managers: map['managers'] ?? [],
      bunkDetails: map['bunkDetails'],
      bunks: map['bunks'] is List ? (map['bunks'] as List) : [],
    );
  }
}

// Analytics Highlights Provider
final analyticsProvider = FutureProvider.autoDispose
    .family<AnalyticsResponse, AnalyticsFilter>((ref, filter) async {
      try {
        final params = <String, dynamic>{
          'period': filter.period,
          if (filter.date != null)
            'date': filter.date!.toIso8601String().split('T')[0],
          if (filter.bunkId != null) 'bunkId': filter.bunkId,
          if (filter.groupBy != null) 'groupBy': filter.groupBy,
          if (filter.startDate != null) 'startDate': filter.startDate,
          if (filter.endDate != null) 'endDate': filter.endDate,
        };

        final result = await FirebaseFunctions.instance
            .httpsCallable('fetchAnalytics')
            .call(params);

        if (result.data is Map) {
          return AnalyticsResponse.fromMap(
            Map<String, dynamic>.from(result.data),
          );
        }

        if (result.data is List) {
          final list = (result.data as List).cast<dynamic>();

          if (list.isEmpty) {
            return AnalyticsResponse(
              totals: BunkDailyStats.empty(),
              managers: [],
            );
          }

          // Aggregate
          num totalFuel = 0;
          num totalPaid = 0;
          num totalPointsDist = 0;
          num totalPointsRed = 0;
          int totalTx = 0;
          final managerMap = <String, Map<String, dynamic>>{};

          for (final item in list) {
            final m = Map<String, dynamic>.from(item);
            totalFuel += (m['totalFuelAmount'] as num?) ?? 0;
            totalPaid += (m['totalPaidAmount'] as num?) ?? 0;
            totalPointsDist += (m['totalPointsDistributed'] as num?) ?? 0;
            totalPointsRed += (m['totalPointsRedeemed'] as num?) ?? 0;
            totalTx += (m['transactionCount'] as num?)?.toInt() ?? 0;

            // Managers
            if (m['managers'] is Map) {
              final managers = Map<String, dynamic>.from(m['managers']);
              managers.forEach((mgrId, mgrData) {
                final dataMap = Map<String, dynamic>.from(mgrData as Map);
                if (!managerMap.containsKey(mgrId)) {
                  managerMap[mgrId] = {
                    'managerId': mgrId,
                    'managerName':
                        'Unknown', // No hydration here without refetch, but maybe fine
                    'fuelAmount': 0.0,
                    'paidAmount': 0.0,
                    'txCount': 0,
                  };
                }
                managerMap[mgrId]!['fuelAmount'] =
                    (managerMap[mgrId]!['fuelAmount'] as num) +
                    ((dataMap['fuelAmount'] as num?) ?? 0);
                managerMap[mgrId]!['paidAmount'] =
                    (managerMap[mgrId]!['paidAmount'] as num) +
                    ((dataMap['paidAmount'] as num?) ?? 0);
                managerMap[mgrId]!['txCount'] =
                    (managerMap[mgrId]!['txCount'] as int) +
                    ((dataMap['txCount'] as num?)?.toInt() ?? 0);
              });
            }
          }

          return AnalyticsResponse(
            totals: BunkDailyStats(
              id: 'aggregated',
              bunkId: filter.bunkId ?? 'global',
              date: filter.date?.toIso8601String() ?? 'range',
              totalFuelAmount: totalFuel,
              totalPaidAmount: totalPaid,
              totalPointsDistributed: totalPointsDist,
              totalPointsRedeemed: totalPointsRed,
              transactionCount: totalTx,
            ),
            managers: managerMap.values.toList(),
          );
        }

        // Fallback emptiness
        return AnalyticsResponse(totals: BunkDailyStats.empty(), managers: []);
      } catch (e) {
        print("Analytics Fetch Error: $e");
        // Return empty on error to prevent UI crash
        return AnalyticsResponse(
          totals: BunkDailyStats(
            id: 'error',
            bunkId: '',
            date: '',
            totalFuelAmount: 0,
            totalPointsDistributed: 0,
            totalPointsRedeemed: 0,
            transactionCount: 0,
          ),
          managers: [],
        );
      }
    });

// Audit Logs Provider
final auditLogProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, limit) async {
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('fetchAuditLogs')
            .call({'limit': limit});

        final data = result.data;
        if (data is Map && data['logs'] is List) {
          return (data['logs'] as List).cast<Map<String, dynamic>>();
        }
        return [];
      } catch (e, stack) {
        // ignore: avoid_print
        print('Audit Log Fetch Error: $e\n$stack');
        return [];
      }
    });
