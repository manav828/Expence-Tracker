import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CategoryIconGroup {
  food('Food & drink'),
  shopping('Shopping'),
  travel('Transport & travel'),
  home('Home & bills'),
  lifestyle('Health & lifestyle'),
  money('Money');

  const CategoryIconGroup(this.label);
  final String label;
}

class CategoryIconOption {
  final String key;
  final String label;
  final IconData icon;
  final List<String> aliases;

  const CategoryIconOption(this.key, this.label, this.icon, this.aliases);

  bool matches(String query) {
    final words = _normalizeIconText(query).split(' ');
    final searchable = _normalizeIconText('$label $key ${aliases.join(' ')}');
    return words.every(searchable.contains);
  }
}

String _normalizeIconText(String text) => text
    .toLowerCase()
    .replaceAll('é', 'e')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

class CategoryIcons {
  static const String _prefKey = 'custom_category_icons_v1';
  static const String _defaultKey = 'category';
  static final Map<String, String> _customIcons = {};

  // Keys are stored in preferences. Keep them stable when changing labels or glyphs.
  static const groups = <CategoryIconGroup, List<CategoryIconOption>>{
    CategoryIconGroup.food: [
      CategoryIconOption('restaurant', 'Food & Dining', Icons.restaurant_outlined, ['restaurant', 'dining', 'food', 'lunch', 'dinner', 'breakfast']),
      CategoryIconOption('fastfood', 'Fast Food', Icons.fastfood_outlined, ['fast food', 'burger', 'pizza', 'takeaway']),
      CategoryIconOption('coffee', 'Coffee & Cafés', Icons.coffee_outlined, ['coffee', 'cafe', 'café', 'tea']),
      CategoryIconOption('shopping_cart', 'Groceries', Icons.shopping_cart_outlined, ['grocery', 'groceries', 'supermarket']),
      CategoryIconOption('bakery', 'Bakery', Icons.bakery_dining_outlined, ['bakery', 'bread', 'pastry', 'cake']),
      CategoryIconOption('local_bar', 'Drinks & Nightlife', Icons.local_bar_outlined, ['bar', 'drinks', 'nightlife']),
      CategoryIconOption('food_delivery', 'Food Delivery', Icons.delivery_dining_outlined, ['food delivery', 'swiggy', 'zomato']),
    ],
    CategoryIconGroup.shopping: [
      CategoryIconOption('shopping_bag', 'Shopping', Icons.shopping_bag_outlined, ['shopping', 'retail']),
      CategoryIconOption('storefront', 'Markets', Icons.storefront_outlined, ['market', 'store']),
      CategoryIconOption('clothing', 'Clothes & Shoes', Icons.checkroom_outlined, ['clothing', 'clothes', 'shoes', 'fashion']),
      CategoryIconOption('electronics', 'Electronics', Icons.devices_outlined, ['electronics', 'tech', 'gadgets']),
      CategoryIconOption('furniture', 'Furniture', Icons.chair_outlined, ['furniture', 'decor', 'sofa']),
      CategoryIconOption('books', 'Books & Stationery', Icons.menu_book_outlined, ['books', 'stationery', 'bookstore']),
      CategoryIconOption('online_orders', 'Online Orders', Icons.inventory_2_outlined, ['online orders', 'package', 'parcel']),
    ],
    CategoryIconGroup.travel: [
      CategoryIconOption('directions_car', 'Transport & Car', Icons.directions_car_outlined, ['transport', 'car', 'car rental']),
      CategoryIconOption('rideshare', 'Taxi & Rideshare', Icons.local_taxi_outlined, ['taxi', 'rideshare', 'cab', 'uber', 'ola']),
      CategoryIconOption('two_wheeler', 'Bike & Scooter', Icons.two_wheeler_outlined, ['bike', 'scooter', 'motorcycle']),
      CategoryIconOption('local_gas_station', 'Fuel', Icons.local_gas_station_outlined, ['fuel', 'petrol', 'diesel', 'gas station']),
      CategoryIconOption('train', 'Train & Metro', Icons.train_outlined, ['train', 'railway', 'metro', 'subway']),
      CategoryIconOption('bus', 'Bus', Icons.directions_bus_outlined, ['bus', 'coach']),
      CategoryIconOption('bicycle', 'Bicycle', Icons.directions_bike_outlined, ['bicycle', 'cycling']),
      CategoryIconOption('parking', 'Parking', Icons.local_parking_outlined, ['parking', 'parking fee']),
      CategoryIconOption('tolls', 'Tolls', Icons.toll_outlined, ['toll', 'tolls', 'fastag']),
      CategoryIconOption('flight', 'Travel & Flights', Icons.flight_outlined, ['travel', 'flight', 'airfare', 'airplane']),
      CategoryIconOption('hotel', 'Hotel & Stay', Icons.hotel_outlined, ['hotel', 'stay', 'resort', 'accommodation']),
      CategoryIconOption('luggage', 'Luggage', Icons.luggage_outlined, ['luggage', 'baggage', 'suitcase']),
    ],
    CategoryIconGroup.home: [
      CategoryIconOption('receipt', 'Bills & Utilities', Icons.receipt_long_outlined, ['bill', 'bills', 'utility', 'utilities']),
      CategoryIconOption('home', 'Housing & Rent', Icons.home_outlined, ['housing', 'rent', 'house', 'home']),
      CategoryIconOption('flash_on', 'Electricity', Icons.bolt_outlined, ['electricity', 'electricity bill', 'power']),
      CategoryIconOption('water_drop', 'Water', Icons.water_drop_outlined, ['water', 'water bill']),
      CategoryIconOption('wifi', 'Internet & Wi-Fi', Icons.wifi, ['internet', 'wifi', 'wi fi', 'broadband']),
      CategoryIconOption('phone_android', 'Mobile Recharge', Icons.phone_android_outlined, ['mobile', 'recharge', 'mobile recharge', 'phone']),
      CategoryIconOption('build', 'Repairs & Maintenance', Icons.build_outlined, ['repair', 'repairs', 'maintenance']),
      CategoryIconOption('cleaning', 'Cleaning', Icons.cleaning_services_outlined, ['cleaning', 'housekeeping', 'laundry']),
    ],
    CategoryIconGroup.lifestyle: [
      CategoryIconOption('favorite', 'Health & Wellness', Icons.favorite_border, ['health', 'wellness']),
      CategoryIconOption('hospital', 'Doctors & Hospital', Icons.local_hospital_outlined, ['doctor', 'hospital', 'clinic', 'medical']),
      CategoryIconOption('medication', 'Medicine', Icons.medication_outlined, ['medicine', 'medicines', 'pharmacy', 'medication']),
      CategoryIconOption('fitness_center', 'Gym & Fitness', Icons.fitness_center_outlined, ['gym', 'fitness', 'workout']),
      CategoryIconOption('brush', 'Personal Care', Icons.brush_outlined, ['personal care', 'beauty', 'salon', 'skincare']),
      CategoryIconOption('spa', 'Spa & Relaxation', Icons.spa_outlined, ['spa', 'massage', 'relaxation']),
      CategoryIconOption('tv', 'Entertainment & Streaming', Icons.tv_outlined, ['entertainment', 'streaming', 'ott', 'subscription', 'subscriptions']),
      CategoryIconOption('movie', 'Movies & Cinema', Icons.movie_outlined, ['movie', 'movies', 'cinema']),
      CategoryIconOption('sports_esports', 'Gaming', Icons.sports_esports_outlined, ['gaming', 'game', 'games', 'esports']),
      CategoryIconOption('sports', 'Sports', Icons.sports_soccer_outlined, ['sport', 'sports', 'football', 'cricket']),
      CategoryIconOption('music', 'Music & Concerts', Icons.headphones_outlined, ['music', 'concert', 'concerts']),
      CategoryIconOption('school', 'Education & Courses', Icons.school_outlined, ['education', 'course', 'courses', 'school', 'tuition']),
      CategoryIconOption('family', 'Family & Childcare', Icons.child_care_outlined, ['family', 'childcare', 'baby', 'kids']),
      CategoryIconOption('pets', 'Pets', Icons.pets_outlined, ['pet', 'pets', 'vet']),
      CategoryIconOption('card_giftcard', 'Gifts', Icons.card_giftcard_outlined, ['gift', 'gifts', 'present']),
      CategoryIconOption('donations', 'Donations', Icons.volunteer_activism_outlined, ['donations', 'donation', 'charity']),
    ],
    CategoryIconGroup.money: [
      CategoryIconOption('payments', 'Salary & Income', Icons.payments_outlined, ['salary', 'payroll', 'income', 'stipend']),
      CategoryIconOption('freelance', 'Freelance', Icons.laptop_chromebook_outlined, ['freelance', 'freelancing', 'consulting', 'contract', 'gig']),
      CategoryIconOption('bonus', 'Bonus', Icons.stars_outlined, ['bonus', 'commission', 'incentive']),
      CategoryIconOption('refund', 'Refund & Cashback', Icons.replay_outlined, ['refund', 'cashback', 'reimbursement']),
      CategoryIconOption('rental_income', 'Rental Income', Icons.key_outlined, ['rental income', 'rent received']),
      CategoryIconOption('trending_up', 'Investments', Icons.show_chart_outlined, ['investment', 'investments', 'stocks', 'mutual fund']),
      CategoryIconOption('interest', 'Interest & Dividends', Icons.percent_outlined, ['interest', 'dividend', 'dividends']),
      CategoryIconOption('savings', 'Savings', Icons.savings_outlined, ['savings', 'saving']),
      CategoryIconOption('account_balance', 'Bank Transfer', Icons.account_balance_outlined, ['bank', 'transfer', 'bank transfer', 'netbanking']),
      CategoryIconOption('loan', 'Loans & EMI', Icons.request_quote_outlined, ['loan', 'loans', 'emi']),
      CategoryIconOption('taxes', 'Taxes', Icons.calculate_outlined, ['tax', 'taxes', 'gst']),
      CategoryIconOption('insurance', 'Insurance', Icons.verified_user_outlined, ['insurance', 'car insurance', 'insurance premium']),
      CategoryIconOption('category', 'General', Icons.category_outlined, ['general', 'other', 'miscellaneous']),
    ],
  };

  static final availableIcons = List<CategoryIconOption>.unmodifiable(
    groups.values.expand((options) => options),
  );

  static final _byKey = {for (final option in availableIcons) option.key: option};

  static final _byAlias = {
    for (final option in availableIcons)
      for (final alias in [option.label, ...option.aliases])
        _normalizeIconText(alias): option.key,
  };

  // Find more specific phrases first, such as "car insurance" before "car".
  static final _matchingAliases = _byAlias.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  static CategoryIconOption optionForKey(String key) =>
      _byKey[key] ?? _byKey[_defaultKey]!;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefKey);
      final decoded = json == null ? null : jsonDecode(json);
      _customIcons.clear();
      if (decoded is Map) {
        decoded.forEach((key, value) {
          _customIcons[key.toString().toLowerCase().trim()] = value.toString();
        });
      }
    } catch (_) {}
  }

  static Future<void> setCustomIcon(String category, String iconKey) async {
    _customIcons[category.toLowerCase().trim()] = iconKey;
    await _saveCustomIcons();
  }

  static IconData get(String category) =>
      optionForKey(getKeyForCategory(category)).icon;

  static String getKeyForCategory(String category) {
    final saved = _customIcons[category.toLowerCase().trim()];
    if (saved != null && _byKey.containsKey(saved)) return saved;

    final name = _normalizeIconText(category);
    final exact = _byAlias[name];
    if (exact != null) return exact;

    final phrase = ' $name ';
    for (final alias in _matchingAliases) {
      if (phrase.contains(' $alias ')) return _byAlias[alias]!;
    }
    return _defaultKey;
  }

  static Future<void> renameCategory(String oldName, String newName) async {
    final saved = _customIcons.remove(oldName.toLowerCase().trim());
    if (saved == null) return;
    _customIcons[newName.toLowerCase().trim()] = saved;
    await _saveCustomIcons();
  }

  static Future<void> deleteCategory(String name) async {
    if (_customIcons.remove(name.toLowerCase().trim()) != null) {
      await _saveCustomIcons();
    }
  }

  static Future<void> _saveCustomIcons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_customIcons));
    } catch (_) {}
  }

  static IconData getPaymentMethodIcon(String method) {
    final lower = method.toLowerCase().trim();
    if (lower.contains('upi') || lower.contains('gpay') || lower.contains('phonepe') || lower.contains('paytm')) {
      return Icons.qr_code_2_rounded;
    } else if (lower.contains('card') || lower.contains('credit') || lower.contains('debit')) {
      return Icons.credit_card_outlined;
    } else if (lower.contains('cash')) {
      return Icons.payments_outlined;
    } else if (lower.contains('transfer') || lower.contains('netbanking') || lower.contains('bank') || lower.contains('a/c')) {
      return Icons.account_balance_outlined;
    } else if (lower.contains('wallet')) {
      return Icons.account_balance_wallet_outlined;
    }
    return Icons.payment_outlined;
  }
}
