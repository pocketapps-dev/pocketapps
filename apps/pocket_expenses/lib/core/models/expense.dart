class Expense {
  final String id;
  final String userId;
  final String categoryId;
  final String name;
  final double amount;
  final String type; // 'recurring' or 'unique'
  final bool isVariable;
  final int? dueDay;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? installments;
  final int? frequency;
  final int reminderDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  Expense({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.type,
    this.isVariable = false,
    this.dueDay,
    this.startDate,
    this.endDate,
    this.installments,
    this.frequency,
    this.reminderDays = 3,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      isVariable: json['is_variable'] as bool? ?? false,
      dueDay: json['due_day'] as int?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      installments: json['installments'] as int?,
      frequency: json['frequency'] as int?,
      reminderDays: json['reminder_days'] as int? ?? 3,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      categoryName: json['categories']?['name'] as String?,
      categoryIcon: json['categories']?['icon_name'] as String?,
      categoryColor: json['categories']?['color_hex'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'name': name,
      'amount': amount,
      'type': type,
      'is_variable': isVariable,
      'due_day': dueDay,
      'start_date': startDate?.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'installments': installments,
      'frequency': frequency,
      'reminder_days': reminderDays,
      'is_active': isActive,
    };
  }

  Expense copyWith({
    String? id,
    String? userId,
    String? categoryId,
    String? name,
    double? amount,
    String? type,
    bool? isVariable,
    int? dueDay,
    DateTime? startDate,
    DateTime? endDate,
    int? installments,
    int? frequency,
    int? reminderDays,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      isVariable: isVariable ?? this.isVariable,
      dueDay: dueDay ?? this.dueDay,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      installments: installments ?? this.installments,
      frequency: frequency ?? this.frequency,
      reminderDays: reminderDays ?? this.reminderDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
    );
  }
}
