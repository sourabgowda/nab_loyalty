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
    print("Parsing Totals from: $map");
    final stats = BunkDailyStats(
      id: map['id'] ?? '',
      bunkId: map['bunkId'] ?? '',
      date: map['date'] ?? '',
      totalFuelAmount: (map['totalFuelAmount'] as num?)?.toDouble() ?? 0.0,
      totalPaidAmount: (map['totalPaidAmount'] as num?)?.toDouble() ?? 0.0,
      totalPointsDistributed:
          (map['totalPointsDistributed'] as num?)?.toInt() ?? 0,
      totalPointsRedeemed: (map['totalPointsRedeemed'] as num?)?.toInt() ?? 0,
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
      managers: map['managers'],
      bunkName: map['bunkName'],
    );
    print(
      "Parsed Stats: Fuel=${stats.totalFuelAmount}, Count=${stats.transactionCount}",
    );
    return stats;
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
        print("FetchTransactions Result: $data");

        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['transactions'] is List) {
          return (data['transactions'] as List).cast<Map<String, dynamic>>();
        }
        print("Unknown Data Format");
        return [];
      } catch (e, st) {
        print("FetchTransactions Error: $e");
        print(st);
        throw e;
      }
    });

// Analytics Filter for Period selection
class AnalyticsFilter {
  final String period; // 'day', 'month', 'year'
  final DateTime? date;
  final String? bunkId;

  AnalyticsFilter({this.period = 'day', this.date, this.bunkId});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnalyticsFilter &&
        other.period == period &&
        other.date == date &&
        other.bunkId == bunkId;
  }

  @override
  int get hashCode => period.hashCode ^ date.hashCode ^ bunkId.hashCode;
}

class AnalyticsResponse {
  final BunkDailyStats totals;
  final List<dynamic> managers;
  final Map<String, dynamic>? bunkDetails;

  AnalyticsResponse({
    required this.totals,
    required this.managers,
    this.bunkDetails,
  });

  factory AnalyticsResponse.fromMap(Map<String, dynamic> map) {
    return AnalyticsResponse(
      totals: BunkDailyStats.fromMap(
        map['totals'] != null ? Map<String, dynamic>.from(map['totals']) : {},
      ),
      managers: map['managers'] ?? [],
      bunkDetails: map['bunkDetails'],
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
        };

        print("Analytics Request Params: $params");

        final result = await FirebaseFunctions.instance
            .httpsCallable('fetchAnalytics')
            .call(params);

        print("Analytics Result Data: ${result.data}");

        if (result.data is Map) {
          return AnalyticsResponse.fromMap(
            Map<String, dynamic>.from(result.data),
          );
        }

        // Fallback emptiness
        return AnalyticsResponse(
          totals: BunkDailyStats(
            id: 'empty',
            bunkId: '',
            date: '',
            totalFuelAmount: 0,
            totalPointsDistributed: 0,
            totalPointsRedeemed: 0,
            transactionCount: 0,
          ),
          managers: [],
        );
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
