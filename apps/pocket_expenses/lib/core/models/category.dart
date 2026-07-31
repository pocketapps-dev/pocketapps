class Category {
  final String id;
  final String appName;
  final String name;
  final String iconName;
  final String colorHex;
  final bool isDefault;
  final int sortOrder;
  final double? budget;
  final String? userId;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.appName,
    required this.name,
    required this.iconName,
    required this.colorHex,
    this.isDefault = false,
    this.sortOrder = 0,
    this.budget,
    this.userId,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      appName: json['app_name'] as String,
      name: json['name'] as String,
      iconName: json['icon_name'] as String,
      colorHex: json['color_hex'] as String,
      isDefault: json['is_default'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      budget: (json['budget'] as num?)?.toDouble(),
      userId: json['user_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_name': appName,
      'name': name,
      'icon_name': iconName,
      'color_hex': colorHex,
      'is_default': isDefault,
      'sort_order': sortOrder,
      'budget': budget,
      'user_id': userId,
    };
  }

  Category copyWith({
    String? id,
    String? appName,
    String? name,
    String? iconName,
    String? colorHex,
    bool? isDefault,
    int? sortOrder,
    double? budget,
    String? userId,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      budget: budget ?? this.budget,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
