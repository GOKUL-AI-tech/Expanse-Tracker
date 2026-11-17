import 'package:equatable/equatable.dart';

class ExpenseModel extends Equatable {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String? description;
  final String? notes;
  final String? receiptUrl;
  final List<String> tags;
  final String paymentMethod;
  final DateTime date;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    this.description,
    this.notes,
    this.receiptUrl,
    this.tags = const [],
    this.paymentMethod = 'Cash',
    required this.date,
    required this.createdAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      receiptUrl: map['receipt_url'] as String?,
      tags: map['tags'] != null
          ? List<String>.from(map['tags'] as List)
          : [],
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'amount': amount,
      'category': category,
      'description': description,
      'notes': notes,
      'receipt_url': receiptUrl,
      'tags': tags,
      'payment_method': paymentMethod,
      'date': date.toIso8601String().split('T')[0],
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? description,
    String? notes,
    String? receiptUrl,
    List<String>? tags,
    String? paymentMethod,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      tags: tags ?? this.tags,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, amount, category, date];
}
