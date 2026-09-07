import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/add_expense_sheet.dart';

class TransactionDetectionService {
  static const MethodChannel _channel = MethodChannel('com.manav.expense/transaction_detection');
  static bool _isListening = false;

  /// Initialize listener for native background SMS detection broadcasts when app is alive
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    if (_isListening) return;
    _isListening = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTransactionDetected') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final category = data['category'] as String?;
        final paymentMethod = data['paymentMethod'] as String?;
        final comment = data['comment'] as String?;

        if (amount > 0 && navigatorKey.currentContext != null) {
          showDetectedTransactionPopup(
            navigatorKey.currentContext!,
            amount: amount,
            category: category,
            paymentMethod: paymentMethod,
            comment: comment,
          );
        }
      }
    });
  }

  /// Opens the interactive popup with pre-filled amount and details.
  /// If the user confirms/saves, it saves with the chosen category.
  /// If the user dismisses/closes the popup, it automatically logs by default.
  static void showDetectedTransactionPopup(
    BuildContext context, {
    required double amount,
    String? category,
    String? paymentMethod,
    String? comment,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(
        initialAmount: amount,
        initialCategory: category,
        initialPaymentMethod: paymentMethod,
        initialComment: comment,
        isAutoDetected: true,
        autoSaveOnDismiss: true,
      ),
    );
  }
}
