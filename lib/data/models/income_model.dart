import 'package:equatable/equatable.dart';

class IncomeModel extends Equatable {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String? description;
  final String? notes;
  final DateTime date;
  final DateTime createdAt;

  const IncomeModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    this.description,
    this.notes,
    required this.date,
    required this.createdAt,
  });

  factory IncomeModel.fromMap(Map<String, dynamic> map) {
    return IncomeModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      description: map['description'] as String?,
      notes: map['notes'] as String?,
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
      'date': date.toIso8601String().split('T')[0],
    };
  }

  IncomeModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? description,
    String? notes,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return IncomeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, amount, category, date];
}
