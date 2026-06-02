import 'package:flutter/foundation.dart';

class Sale {
  final String id;
  final double amount;
  final DateTime timestamp;

  Sale({
    String? id,
    required this.amount,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
  };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'],
    amount: (json['amount'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
  );
}
