import 'package:flutter/material.dart';

class ThemeInfo {
  final String themeKey;
  final String name;
  final String description;
  final int priceCents;
  final String seedColorHex;
  final String brightness;
  final bool isPremium;
  final bool isPaid;
  final int sortOrder;
  final bool available;
  final bool purchased;

  const ThemeInfo({
    required this.themeKey,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.seedColorHex,
    this.brightness = 'light',
    required this.isPremium,
    required this.isPaid,
    required this.sortOrder,
    required this.available,
    required this.purchased,
  });

  factory ThemeInfo.fromJson(Map<String, dynamic> json) {
    return ThemeInfo(
      themeKey: json['theme_key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priceCents: json['price_cents'] as int? ?? 0,
      seedColorHex: json['seed_color'] as String? ?? '#6366F1',
      brightness: json['brightness'] as String? ?? 'light',
      isPremium: json['is_premium'] == true,
      isPaid: json['is_paid'] == true,
      sortOrder: json['sort_order'] as int? ?? 0,
      available: json['available'] == true,
      purchased: json['purchased'] == true,
    );
  }

  bool get isFree => !isPremium && !isPaid;

  Color get seedColor {
    final hex = seedColorHex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return const Color(0xFF6366F1);
    return Color(0xFF000000 | value);
  }

  String get priceLabel {
    final euros = priceCents / 100;
    final text = euros == euros.roundToDouble()
        ? euros.toStringAsFixed(0)
        : euros.toStringAsFixed(2).replaceAll('.', ',');
    return '$text €';
  }
}
