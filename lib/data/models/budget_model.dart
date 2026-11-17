import 'package:equatable/equatable.dart';

class BudgetModel extends Equatable {
  final String id;
  final String userId;
  final String category;
  final double amount;
  final int month;
  final int year;
  final DateTime createdAt;
  // Computed: filled in by repository
  final double spent;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    required this.month,
    required this.year,
    required this.createdAt,
    this.spent = 0,
  });

  double get remaining => amount - spent;
  double get percentage => amount > 0 ? (spent / amount * 100).clamp(0, 100) : 0;
  bool get isExceeded => spent > amount;
  bool get isNearLimit => percentage >= 75;

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      spent: (map['spent'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'category': category,
      'amount': amount,
      'month': month,
      'year': year,
    };
  }

  BudgetModel copyWith({double? spent}) {
    return BudgetModel(
      id: id,
      userId: userId,
      category: category,
      amount: amount,
      month: month,
      year: year,
      createdAt: createdAt,
      spent: spent ?? this.spent,
    );
  }

  @override
  List<Object?> get props => [id, userId, category, month, year];
}
