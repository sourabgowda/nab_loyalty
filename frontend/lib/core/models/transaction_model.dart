import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String txId;
  final String userId;
  final String bunkId;
  final double amount;
  final String fuelType;
  final double points;
  final String type; // CREDIT or REDEEM
  final DateTime timestamp;

  TransactionModel({
    required this.txId,
    required this.userId,
    required this.bunkId,
    required this.amount,
    required this.fuelType,
    required this.points,
    required this.type,
    required this.timestamp,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      txId: map['txId'] ?? '',
      userId: map['userId'] ?? '',
      bunkId: map['bunkId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      fuelType: map['fuelType'] ?? '',
      points: (map['points'] ?? 0).toDouble(),
      type: map['type'] ?? 'CREDIT',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
