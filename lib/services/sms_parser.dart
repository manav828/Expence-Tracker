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

    // 1. Exclude OTP / 2FA / Verification Messages (Issue #12)
    final otpIndicators = [
      'otp',
      'one time password',
      'verification code',
      'security code',
      'auth code',
      'secret code',
      'do not share',
      'never share',
      'valid for',
      'is your code',
    ];
    for (final indicator in otpIndicators) {
      if (lowerMsg.contains(indicator)) {
        return null;
      }
    }

    // 2. Exclude Promotional / Marketing Messages (Issue #13)
    final promoIndicators = [
      'flat rs',
      'flat inr',
      'cashback',
      'off on',
      'discount',
      'coupon',
      'pre-approved',
      'pre approved',
      'apply for loan',
      'win cash',
      'congratulations',
      'promocode',
      'promo code',
      'save up to',
      'up to rs',
      'hurry',
      'reward points',
      'claim now',
      'free voucher',
    ];
    for (final indicator in promoIndicators) {
      if (lowerMsg.contains(indicator)) {
        return null;
      }
    }

    // 3. Determine Type (Expense vs Income)
    bool isExpense = false;
    bool isIncome = false;

    if (lowerMsg.contains('debited') ||
        lowerMsg.contains('sent rs') ||
        lowerMsg.contains('txn rs') ||
        lowerMsg.contains('spent') ||
        lowerMsg.contains('paid') ||
        lowerMsg.contains('withdrawn') ||
        lowerMsg.contains('charged') ||
        lowerMsg.contains('used at')) {
      isExpense = true;
    } else if (lowerMsg.contains('credited') ||
        lowerMsg.contains('received') ||
        lowerMsg.contains('deposited') ||
        lowerMsg.contains('salary') ||
        lowerMsg.contains('deposit') ||
        lowerMsg.contains('refund') ||
        lowerMsg.contains('added to account')) {
      isIncome = true;
    } else {
      // If neither explicit debit nor credit keywords exist, do not treat as transaction
      return null;
    }

    // 4. Extract Amount - avoiding balance collision (Issue #11)
    // Priority 1: Verb directly associated with amount (e.g. "debited by/for/of Rs 450", "spent Rs 200")
    final verbAmountRegex = RegExp(
      r'(?:debited|credited|spent|paid|withdrawn|deposited|sent|received|txn(?:\s+of)?|charged|used)\s*(?:by|with|for|in|of|to)?\s*(?:rs\.?|inr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    // Priority 2: Amount directly preceding verb (e.g. "Rs 450 debited", "INR 1,200 credited")
    final amountVerbRegex = RegExp(
      r'(?:rs\.?|inr)\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:debited|credited|spent|paid|transferred|deposited|withdrawn)',
      caseSensitive: false,
    );

    double? amount;
    final verbMatch = verbAmountRegex.firstMatch(message);
    if (verbMatch != null && verbMatch.group(1) != null) {
      amount = double.tryParse(verbMatch.group(1)!.replaceAll(',', ''));
    }

    if (amount == null) {
      final amountVerbMatch = amountVerbRegex.firstMatch(message);
      if (amountVerbMatch != null && amountVerbMatch.group(1) != null) {
        amount = double.tryParse(amountVerbMatch.group(1)!.replaceAll(',', ''));
      }
    }

    // Fallback: search for Rs./INR but explicitly ignore if preceded by "bal", "avl", "available", "limit"
    if (amount == null) {
      final generalRegex = RegExp(r'(?:rs\.?|inr)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
      for (final m in generalRegex.allMatches(message)) {
        final startIdx = m.start;
        final prefix = message.substring(startIdx > 20 ? startIdx - 20 : 0, startIdx).toLowerCase();
        if (prefix.contains('bal') || prefix.contains('avl') || prefix.contains('available') || prefix.contains('limit')) {
          continue; // Skip available balance
        }
        final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (val != null && val > 0) {
          amount = val;
          break;
        }
      }
    }

    if (amount == null || amount <= 0) {
      return null;
    }

    // 5. Payment Method
    String paymentMethod = 'UPI';
    if (lowerMsg.contains('credit card') ||
        lowerMsg.contains('card') ||
        lowerMsg.contains('cc ')) {
      paymentMethod = 'Card';
    } else if (lowerMsg.contains('debit card') || lowerMsg.contains('dc ')) {
      paymentMethod = 'Card';
    } else if (lowerMsg.contains('netbanking') ||
        lowerMsg.contains('transfer') ||
        lowerMsg.contains('trf') ||
        lowerMsg.contains('deposited') ||
        lowerMsg.contains('a/c') ||
        lowerMsg.contains('bank')) {
      paymentMethod = 'Transfer';
    } else if (lowerMsg.contains('cash')) {
      paymentMethod = 'Cash';
    }

    // 6. Detect Bank
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

    // 7. Detect Payee / Beneficiary / Employer
    String payee = '';
    if (lowerMsg.contains('salary')) {
      final salaryRegex = RegExp(
        r'(?:for|from)\s+([A-Za-z0-9@_.\s&-]+?)(?:(?:\s*-\s*Salary)|(?:\.Avl)|(?:\.)|\n|$)',
        caseSensitive: false,
      );
      final sMatch = salaryRegex.firstMatch(message);
      if (sMatch != null) {
        var rawPayee = sMatch.group(1)?.trim() ?? '';
        rawPayee = rawPayee.replaceAll(RegExp(r'^[A-Za-z0-9]+ - '), '').trim();
        payee = rawPayee.isNotEmpty ? '$rawPayee - Salary' : 'Salary';
      } else {
        payee = 'Salary';
      }
    } else {
      final toRegex = RegExp(
        r'(?:to|at|from|for|vpa)\s+([A-Za-z0-9@_.\s&-]+?)(?:\s+(?:on|by|ref|vpa|date|avl|bal|\.|\n|$))',
        caseSensitive: false,
      );
      final payeeMatch = toRegex.firstMatch(message);
      if (payeeMatch != null) {
        payee = payeeMatch.group(1)?.trim() ?? '';
        payee = payee.replaceAll(RegExp(r'^[A-Z0-9]+ - '), '').trim();
      }
    }

    // 8. Suggest Category
    String category = 'General';
    final payeeLower = '$payee $lowerMsg'.toLowerCase();
    if (payeeLower.contains('salary') || payeeLower.contains('payroll') || payeeLower.contains('stipend')) {
      category = 'Salary';
    } else if (payeeLower.contains('mutual fund') ||
        payeeLower.contains('groww') ||
        payeeLower.contains('zerodha') ||
        payeeLower.contains('invest')) {
      category = 'Investment';
    } else if (payeeLower.contains('food') ||
        payeeLower.contains('ghughr') ||
        payeeLower.contains('swiggy') ||
        payeeLower.contains('zomato') ||
        payeeLower.contains('restaurant') ||
        payeeLower.contains('cafe')) {
      category = 'Food & Dining';
    } else if (payeeLower.contains('amazon') ||
        payeeLower.contains('flipkart') ||
        payeeLower.contains('mart') ||
        payeeLower.contains('store') ||
        payeeLower.contains('shopping') ||
        payeeLower.contains('myntra')) {
      category = 'Shopping';
    } else if (payeeLower.contains('uber') ||
        payeeLower.contains('ola') ||
        payeeLower.contains('fuel') ||
        payeeLower.contains('petrol')) {
      category = 'Transport';
    } else if (payeeLower.contains('bill') ||
        payeeLower.contains('recharge') ||
        payeeLower.contains('electricity')) {
      category = 'Bills & Utilities';
    } else if (payeeLower.contains('hospital') ||
        payeeLower.contains('pharmacy') ||
        payeeLower.contains('med')) {
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
