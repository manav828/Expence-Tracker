import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryIconOption {
  final String key;
  final String label;
  final IconData icon;

  const CategoryIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

class CategoryIcons {
  static const String _prefKey = 'custom_category_icons_v1';
  static final Map<String, String> _customIcons = {};

  static const List<CategoryIconOption> availableIcons = [
    CategoryIconOption(key: 'restaurant', label: 'Food & Dining', icon: Icons.restaurant),
    CategoryIconOption(key: 'fastfood', label: 'Fast Food', icon: Icons.fastfood),
    CategoryIconOption(key: 'coffee', label: 'Cafe / Coffee', icon: Icons.coffee),
    CategoryIconOption(key: 'local_bar', label: 'Drinks / Nightlife', icon: Icons.local_bar),
    CategoryIconOption(key: 'shopping_bag', label: 'Shopping', icon: Icons.shopping_bag),
    CategoryIconOption(key: 'shopping_cart', label: 'Groceries', icon: Icons.shopping_cart),
    CategoryIconOption(key: 'storefront', label: 'Market / Store', icon: Icons.storefront),
    CategoryIconOption(key: 'directions_car', label: 'Transport / Car', icon: Icons.directions_car),
    CategoryIconOption(key: 'two_wheeler', label: 'Bike / Scooter', icon: Icons.two_wheeler),
    CategoryIconOption(key: 'local_gas_station', label: 'Fuel / Petrol', icon: Icons.local_gas_station),
    CategoryIconOption(key: 'flight', label: 'Travel / Flight', icon: Icons.flight),
    CategoryIconOption(key: 'receipt', label: 'Bills & Utilities', icon: Icons.receipt),
    CategoryIconOption(key: 'flash_on', label: 'Electricity', icon: Icons.flash_on),
    CategoryIconOption(key: 'water_drop', label: 'Water', icon: Icons.water_drop),
    CategoryIconOption(key: 'wifi', label: 'Internet / Wifi', icon: Icons.wifi),
    CategoryIconOption(key: 'phone_android', label: 'Mobile Recharge', icon: Icons.phone_android),
    CategoryIconOption(key: 'tv', label: 'Entertainment / OTT', icon: Icons.tv),
    CategoryIconOption(key: 'sports_esports', label: 'Gaming', icon: Icons.sports_esports),
    CategoryIconOption(key: 'movie', label: 'Movies / Cinema', icon: Icons.movie),
    CategoryIconOption(key: 'favorite', label: 'Health & Wellness', icon: Icons.favorite),
    CategoryIconOption(key: 'medication', label: 'Pharmacy / Medicine', icon: Icons.medication),
    CategoryIconOption(key: 'fitness_center', label: 'Gym / Fitness', icon: Icons.fitness_center),
    CategoryIconOption(key: 'trending_up', label: 'Investment / Stocks', icon: Icons.trending_up),
    CategoryIconOption(key: 'savings', label: 'Savings', icon: Icons.savings),
    CategoryIconOption(key: 'payments', label: 'Salary / Income', icon: Icons.payments),
    CategoryIconOption(key: 'account_balance', label: 'Bank / Transfer', icon: Icons.account_balance),
    CategoryIconOption(key: 'school', label: 'Education / Courses', icon: Icons.school),
    CategoryIconOption(key: 'home', label: 'Housing / Rent', icon: Icons.home),
    CategoryIconOption(key: 'card_giftcard', label: 'Gifts & Donations', icon: Icons.card_giftcard),
    CategoryIconOption(key: 'pets', label: 'Pets', icon: Icons.pets),
    CategoryIconOption(key: 'brush', label: 'Personal Care', icon: Icons.brush),
    CategoryIconOption(key: 'build', label: 'Maintenance / Repair', icon: Icons.build),
    CategoryIconOption(key: 'category', label: 'General / Other', icon: Icons.category),
  ];

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          _customIcons.clear();
          decoded.forEach((k, v) {
            _customIcons[k.toString().toLowerCase().trim()] = v.toString();
          });
        }
      }
    } catch (_) {}
  }

  static Future<void> setCustomIcon(String category, String iconKey) async {
    _customIcons[category.toLowerCase().trim()] = iconKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_customIcons));
    } catch (_) {}
  }

  static IconData get(String category) {
    final lower = category.toLowerCase().trim();

    // 1. Check user-assigned custom icon
    final customKey = _customIcons[lower];
    if (customKey != null) {
      final match = availableIcons.firstWhere(
        (opt) => opt.key == customKey,
        orElse: () => const CategoryIconOption(key: 'category', label: 'General', icon: Icons.category),
      );
      return match.icon;
    }

    // 2. Default keyword matching
    if (lower.contains('food') || lower.contains('dining') || lower.contains('restaurant')) {
      return Icons.restaurant;
    } else if (lower.contains('coffee') || lower.contains('cafe')) {
      return Icons.coffee;
    } else if (lower.contains('grocer')) {
      return Icons.shopping_cart;
    } else if (lower.contains('shop') || lower.contains('clothing')) {
      return Icons.shopping_bag;
    } else if (lower.contains('transport') || lower.contains('fuel') || lower.contains('cab') || lower.contains('car') || lower.contains('uber') || lower.contains('petrol')) {
      return Icons.directions_car;
    } else if (lower.contains('bill') || lower.contains('utilit') || lower.contains('recharge') || lower.contains('electric')) {
      return Icons.receipt;
    } else if (lower.contains('entertain') || lower.contains('stream') || lower.contains('movie') || lower.contains('ott')) {
      return Icons.tv;
    } else if (lower.contains('health') || lower.contains('wellness') || lower.contains('medical') || lower.contains('pharmacy')) {
      return Icons.favorite;
    } else if (lower.contains('fitness') || lower.contains('gym') || lower.contains('workout')) {
      return Icons.fitness_center;
    } else if (lower.contains('invest') || lower.contains('stock') || lower.contains('mutual')) {
      return Icons.trending_up;
    } else if (lower.contains('salary') || lower.contains('payroll') || lower.contains('income') || lower.contains('stipend')) {
      return Icons.payments;
    } else if (lower.contains('rent') || lower.contains('house') || lower.contains('housing')) {
      return Icons.home;
    } else if (lower.contains('education') || lower.contains('course') || lower.contains('school')) {
      return Icons.school;
    } else if (lower.contains('gift')) {
      return Icons.card_giftcard;
    } else if (lower.contains('pet')) {
      return Icons.pets;
    }

    return Icons.category;
  }

  static String getKeyForCategory(String category) {
    final lower = category.toLowerCase().trim();
    if (_customIcons.containsKey(lower)) {
      return _customIcons[lower]!;
    }
    if (lower.contains('food') || lower.contains('dining') || lower.contains('restaurant')) {
      return 'restaurant';
    } else if (lower.contains('coffee') || lower.contains('cafe')) {
      return 'coffee';
    } else if (lower.contains('grocer')) {
      return 'shopping_cart';
    } else if (lower.contains('shop') || lower.contains('clothing')) {
      return 'shopping_bag';
    } else if (lower.contains('transport') || lower.contains('cab') || lower.contains('car') || lower.contains('uber')) {
      return 'directions_car';
    } else if (lower.contains('fuel') || lower.contains('petrol')) {
      return 'local_gas_station';
    } else if (lower.contains('bill') || lower.contains('utilit')) {
      return 'receipt';
    } else if (lower.contains('electric')) {
      return 'flash_on';
    } else if (lower.contains('recharge') || lower.contains('phone')) {
      return 'phone_android';
    } else if (lower.contains('entertain') || lower.contains('stream') || lower.contains('ott')) {
      return 'tv';
    } else if (lower.contains('movie')) {
      return 'movie';
    } else if (lower.contains('health') || lower.contains('wellness')) {
      return 'favorite';
    } else if (lower.contains('fitness') || lower.contains('gym') || lower.contains('workout')) {
      return 'fitness_center';
    } else if (lower.contains('medical') || lower.contains('pharmacy')) {
      return 'medication';
    } else if (lower.contains('invest') || lower.contains('stock') || lower.contains('mutual')) {
      return 'trending_up';
    } else if (lower.contains('salary') || lower.contains('income')) {
      return 'payments';
    } else if (lower.contains('rent') || lower.contains('house') || lower.contains('housing')) {
      return 'home';
    } else if (lower.contains('education') || lower.contains('school')) {
      return 'school';
    } else if (lower.contains('gift')) {
      return 'card_giftcard';
    } else if (lower.contains('pet')) {
      return 'pets';
    }
    return 'category';
  }

  static Future<void> renameCategory(String oldName, String newName) async {
    final oldKey = oldName.toLowerCase().trim();
    final newKey = newName.toLowerCase().trim();
    if (_customIcons.containsKey(oldKey)) {
      final iconVal = _customIcons.remove(oldKey)!;
      _customIcons[newKey] = iconVal;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey, jsonEncode(_customIcons));
      } catch (_) {}
    }
  }

  static Future<void> deleteCategory(String name) async {
    final key = name.toLowerCase().trim();
    if (_customIcons.containsKey(key)) {
      _customIcons.remove(key);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey, jsonEncode(_customIcons));
      } catch (_) {}
    }
  }

  static IconData getPaymentMethodIcon(String method) {
    final lower = method.toLowerCase().trim();
    if (lower.contains('upi') || lower.contains('gpay') || lower.contains('phonepe') || lower.contains('paytm')) {
      return Icons.qr_code_2;
    } else if (lower.contains('card') || lower.contains('credit') || lower.contains('debit')) {
      return Icons.credit_card;
    } else if (lower.contains('cash')) {
      return Icons.payments_outlined;
    } else if (lower.contains('transfer') || lower.contains('netbanking') || lower.contains('bank') || lower.contains('a/c')) {
      return Icons.account_balance;
    }
    return Icons.payment;
  }
}
