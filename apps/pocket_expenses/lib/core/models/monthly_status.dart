class MonthlyStatus {
  final String id;
  final String expenseId;
  final String userId;
  final DateTime expenseMonth;
  final bool isPaid;
  final DateTime? paidDate;
  final bool isSkipped;
  final bool amountConfirmed;
  final double? confirmedAmount;

  MonthlyStatus({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.expenseMonth,
    this.isPaid = false,
    this.paidDate,
    this.isSkipped = false,
    this.amountConfirmed = false,
    this.confirmedAmount,
  });

  factory MonthlyStatus.fromJson(Map<String, dynamic> json) {
    return MonthlyStatus(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      userId: json['user_id'] as String,
      expenseMonth: DateTime.parse(json['expense_month'] as String),
      isPaid: json['is_paid'] as bool? ?? false,
      paidDate: json['paid_date'] != null
          ? DateTime.parse(json['paid_date'] as String)
          : null,
      isSkipped: json['is_skipped'] as bool? ?? false,
      amountConfirmed: json['amount_confirmed'] as bool? ?? false,
      confirmedAmount: json['confirmed_amount'] != null
          ? (json['confirmed_amount'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expense_id': expenseId,
      'user_id': userId,
      'expense_month': expenseMonth.toIso8601String().split('T')[0],
      'is_paid': isPaid,
      'paid_date': paidDate?.toIso8601String(),
      'is_skipped': isSkipped,
      'amount_confirmed': amountConfirmed,
      'confirmed_amount': confirmedAmount,
    };
  }
}
