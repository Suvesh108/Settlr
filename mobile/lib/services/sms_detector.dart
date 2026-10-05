class SmsSpendDetector {
  static final RegExp _amountRegex = RegExp(
    r'(?:rs\.?|inr|debited\s+for|spent\s+rs\.?|paid\s+rs\.?)\s*([0-9]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _merchantRegex = RegExp(
    r'(?:at|to|by\s+upi:|vpa:)\s*([a-zA-Z0-9\s._\-]{3,24})',
    caseSensitive: false,
  );

  static DetectedSpend? parseSms(String body) {
    final lower = body.toLowerCase();
    final isDebit = lower.contains('debited') ||
        lower.contains('spent') ||
        lower.contains('paid') ||
        lower.contains('sent to');

    if (!isDebit) return null;

    final amtMatch = _amountRegex.firstMatch(body);
    if (amtMatch == null) return null;

    final amtStr = amtMatch.group(1);
    final amount = double.tryParse(amtStr ?? '');
    if (amount == null || amount <= 0) return null;

    String merchant = 'Unknown Merchant';
    final merchMatch = _merchantRegex.firstMatch(body);
    if (merchMatch != null) {
      merchant = merchMatch.group(1)?.trim() ?? merchant;
    }

    String category = 'GENERAL';
    if (lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('rapido') ||
        lower.contains('metro')) {
      category = 'TRANSPORT';
    } else if (lower.contains('swiggy') ||
        lower.contains('zomato') ||
        lower.contains('blinkit') ||
        lower.contains('zepto') ||
        lower.contains('food') ||
        lower.contains('cafe')) {
      category = 'FOOD';
    } else if (lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('myntra')) {
      category = 'SHOPPING';
    }

    return DetectedSpend(
      amount: amount,
      merchant: merchant,
      category: category,
      rawBody: body,
    );
  }
}

class DetectedSpend {
  final double amount;
  final String merchant;
  final String category;
  final String rawBody;

  DetectedSpend({
    required this.amount,
    required this.merchant,
    required this.category,
    required this.rawBody,
  });
}
