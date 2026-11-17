import 'package:equatable/equatable.dart';

class SavingsGoalModel extends Equatable {
  final String id;
  final String userId;
  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final String? notes;
  final DateTime createdAt;

  const SavingsGoalModel({
    required this.id,
    required this.userId,
    required this.goalName,
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    this.notes,
    required this.createdAt,
  });

  double get remaining => targetAmount - currentAmount;
  double get percentage =>
      targetAmount > 0 ? (currentAmount / targetAmount * 100).clamp(0, 100) : 0;
  bool get isCompleted => currentAmount >= targetAmount;

  factory SavingsGoalModel.fromMap(Map<String, dynamic> map) {
    return SavingsGoalModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      goalName: map['goal_name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num?)?.toDouble() ?? 0,
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'goal_name': goalName,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'deadline': deadline?.toIso8601String().split('T')[0],
      'notes': notes,
    };
  }

  SavingsGoalModel copyWith({
    String? goalName,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? notes,
  }) {
    return SavingsGoalModel(
      id: id,
      userId: userId,
      goalName: goalName ?? this.goalName,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, goalName];
}
