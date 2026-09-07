class ParsedSmsResult {
  final double amount;
  final bool isExpense;
  final String paymentMethod;
  final String bank;
  final String payee;
  final String category;
  final String originalMessage;

  ParsedSmsResult({
    required this.amount,
    required this.isExpense,
    required this.paymentMethod,
    required this.bank,
    required this.payee,
    required this.category,
    required this.originalMessage,
  });
}

class SmsParser {
  static ParsedSmsResult? parse(String message) {
    if (message.trim().isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // 1. Determine Type (Expense vs Income)
    bool isExpense = false;
    bool isIncome = false;

    if (lowerMsg.contains('debited') ||
        lowerMsg.contains('sent rs') ||
        lowerMsg.contains('txn rs') ||
        lowerMsg.contains('spent') ||
        lowerMsg.contains('paid') ||
        lowerMsg.contains('withdrawn')) {
      isExpense = true;
    } else if (lowerMsg.contains('credited') ||
               lowerMsg.contains('received') ||
               lowerMsg.contains('deposited') ||
               lowerMsg.contains('salary') ||
               lowerMsg.contains('deposit') ||
               lowerMsg.contains('added')) {
      isIncome = true;
    } else {
      // Default to expense if unclear
      isExpense = true;
    }

    // 2. Extract Amount
    // Regex matches: "INR 30,185.00", "Rs.20.00", "Rs 600", "INR 500", "debited by 1000.00", "deposited in HDFC"
    final amountRegex = RegExp(
      r'(?:(?:Rs\.?|INR)\s*([0-9,]+\.?[0-9]*))|(?:(?:debited|credited|deposited)\s*(?:by|in|to)?\s*(?:Rs\.?|INR)?\s*([0-9,]+\.?[0-9]*))',
      caseSensitive: false,
    );

    double? amount;
    final match = amountRegex.firstMatch(message);
    if (match != null) {
      final amountStr = match.group(1) ?? match.group(2);
      if (amountStr != null) {
        amount = double.tryParse(amountStr.replaceAll(',', ''));
      }
    }

    if (amount == null || amount <= 0) {
      return null;
    }

    // 3. Payment Method
    String paymentMethod = 'UPI';
    if (lowerMsg.contains('credit card') || lowerMsg.contains('card') || lowerMsg.contains('cc ')) {
      paymentMethod = 'Card';
    } else if (lowerMsg.contains('debit card') || lowerMsg.contains('dc ')) {
      paymentMethod = 'Card';
    } else if (lowerMsg.contains('netbanking') || lowerMsg.contains('transfer') || lowerMsg.contains('trf') || lowerMsg.contains('deposited') || lowerMsg.contains('a/c') || lowerMsg.contains('bank')) {
      paymentMethod = 'Transfer';
    } else if (lowerMsg.contains('cash')) {
      paymentMethod = 'Cash';
    }

    // 4. Detect Bank
    String bank = 'Bank';
    if (lowerMsg.contains('hdfc')) {
      bank = 'HDFC';
    } else if (lowerMsg.contains('sbi')) {
      bank = 'SBI';
    } else if (lowerMsg.contains('icici')) {
      bank = 'ICICI';
    } else if (lowerMsg.contains('axis')) {
      bank = 'Axis';
    } else if (lowerMsg.contains('kotak')) {
      bank = 'Kotak';
    } else if (lowerMsg.contains('pnb')) {
      bank = 'PNB';
    }

    // 5. Detect Payee / Beneficiary / Employer
    String payee = '';
    if (lowerMsg.contains('salary')) {
      // E.g.: "for A2AINT01 - ONPRINTSHOP SOFTWARE PRIVATE LIMITED - Salary - SALARY AUG 2026"
      final salaryRegex = RegExp(
        r'(?:for|from)\s+([A-Za-z0-9@_.\s&-]+?)(?:(?:\s*-\s*Salary)|(?:\.Avl)|(?:\.)|\n|$)',
        caseSensitive: false,
      );
      final sMatch = salaryRegex.firstMatch(message);
      if (sMatch != null) {
        var rawPayee = sMatch.group(1)?.trim() ?? '';
        rawPayee = rawPayee.replaceAll(RegExp(r'^[A-Za-z0-9]+ - '), '').trim();
        if (rawPayee.isNotEmpty) {
          payee = '$rawPayee - Salary';
        } else {
          payee = 'Salary';
        }
      } else {
        payee = 'Salary';
      }
    } else {
      final toRegex = RegExp(
        r'(?:to|at|from|for)\s+([A-Za-z0-9@_.\s&-]+?)(?:\s+(?:on|by|ref|vpa|date|avl|\.|\n|$))',
        caseSensitive: false,
      );
      final payeeMatch = toRegex.firstMatch(message);
      if (payeeMatch != null) {
        payee = payeeMatch.group(1)?.trim() ?? '';
        payee = payee.replaceAll(RegExp(r'^[A-Z0-9]+ - '), '').trim();
      }
    }

    // 6. Suggest Category
    String category = 'General';
    final payeeLower = '$payee $lowerMsg'.toLowerCase();
    if (payeeLower.contains('salary') || payeeLower.contains('payroll') || payeeLower.contains('stipend')) {
      category = 'Salary';
    } else if (payeeLower.contains('mutual fund') || payeeLower.contains('groww') || payeeLower.contains('zerodha') || payeeLower.contains('invest')) {
      category = 'Investment';
    } else if (payeeLower.contains('food') || payeeLower.contains('ghughr') || payeeLower.contains('swiggy') || payeeLower.contains('zomato') || payeeLower.contains('restaurant') || payeeLower.contains('cafe')) {
      category = 'Food & Dining';
    } else if (payeeLower.contains('amazon') || payeeLower.contains('flipkart') || payeeLower.contains('mart') || payeeLower.contains('store') || payeeLower.contains('shopping') || payeeLower.contains('myntra')) {
      category = 'Shopping';
    } else if (payeeLower.contains('uber') || payeeLower.contains('ola') || payeeLower.contains('fuel') || payeeLower.contains('petrol')) {
      category = 'Transport';
    } else if (payeeLower.contains('bill') || payeeLower.contains('recharge') || payeeLower.contains('electricity')) {
      category = 'Bills & Utilities';
    } else if (payeeLower.contains('hospital') || payeeLower.contains('pharmacy') || payeeLower.contains('med')) {
      category = 'Health & Wellness';
    } else if (isIncome) {
      category = 'Salary';
    } else {
      category = 'General';
    }

    return ParsedSmsResult(
      amount: amount,
      isExpense: isExpense,
      paymentMethod: paymentMethod,
      bank: bank,
      payee: payee.isNotEmpty ? payee : bank,
      category: category,
      originalMessage: message,
    );
  }
}
