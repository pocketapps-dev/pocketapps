class Subscription {
  final String id;
  final String plan;
  final String status;
  final DateTime? startedAt;
  final DateTime? endsAt;

  const Subscription({
    required this.id,
    required this.plan,
    required this.status,
    this.startedAt,
    this.endsAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      plan: json['plan'] as String? ?? 'free',
      status: json['status'] as String? ?? 'active',
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
    );
  }

  bool get isActive =>
      status == 'active' &&
      plan != 'free' &&
      (endsAt == null || endsAt!.isAfter(DateTime.now()));

  String get displayName {
    switch (plan) {
      case 'founder':
        return 'Founder';
      case 'premium':
        return 'Premium';
      default:
        return 'Free';
    }
  }
}
