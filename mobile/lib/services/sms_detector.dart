class SmsSpendDetector {
  // Regex patterns matching Indian banks, UPI, cards, wallets:
  // e.g. "Rs 450.00", "Rs. 1,200.50", "INR 350.00", "spent Rs 250", "paid Rs 340"
  static final RegExp _amountRegex = RegExp(
    r'(?:rs\.?|inr|debited\s+for|spent\s+rs\.?|paid\s+rs\.?)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Pattern 1: to/at/info/vpa: [Merchant]
  static final RegExp _toMerchantRegex = RegExp(
    r'(?:to|at|info|vpa:?)\s+([A-Za-z0-9\s&._\-]{2,30}?)(?:\s+on|\s+ref|\s+avl|\s+via|\.|$)',
    caseSensitive: false,
  );

  // Pattern 2: by UPI: [Merchant]
  static final RegExp _upiMerchantRegex = RegExp(
    r'upi:?\s*([A-Za-z0-9\s&._\-]{2,30}?)(?:\s+on|\s+ref|\s+avl|\.|$)',
    caseSensitive: false,
  );

  // Account ending pattern: "A/c *1234", "ending 5678", "card xx1234"
  static final RegExp _accEndingRegex = RegExp(
    r'(?:a\/c|acct|card|ending)\s*(?:no\.?)?\s*[\*xX]*(\d{4})',
    caseSensitive: false,
  );

  static DetectedSpend? parseSms(String body, [int? timestamp]) {
    if (body.isEmpty) return null;
    final lower = body.toLowerCase();

    // Check if it's a debit transaction
    final isDebit = lower.contains('debited') ||
        lower.contains('spent') ||
        lower.contains('paid') ||
        lower.contains('withdrawn') ||
        lower.contains('purchase of') ||
        lower.contains('sent to');

    if (!isDebit) return null;

    final amtMatch = _amountRegex.firstMatch(body);
    if (amtMatch == null) return null;

    final rawAmtStr = amtMatch.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(rawAmtStr ?? '');
    if (amount == null || amount <= 0) return null;

    // Extract merchant / recipient info
    String merchant = 'Card / UPI Payment';
    final toMatch = _toMerchantRegex.firstMatch(body);
    if (toMatch != null && (toMatch.group(1)?.trim().length ?? 0) > 1) {
      merchant = toMatch.group(1)!.trim();
    } else {
      final upiMatch = _upiMerchantRegex.firstMatch(body);
      if (upiMatch != null && (upiMatch.group(1)?.trim().length ?? 0) > 1) {
        merchant = upiMatch.group(1)!.trim();
      }
    }

    // Account ending
    final accMatch = _accEndingRegex.firstMatch(body);
    final accountEnding = accMatch?.group(1);

    // Smart Category detection (1:1 with WebApp detectCategory)
    final category = detectCategory(merchant);

    return DetectedSpend(
      amount: amount,
      merchant: merchant,
      category: category,
      accountEnding: accountEnding,
      rawBody: body,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Automatically categorizes based on merchant name keywords (parity with webapp detectCategory)
  static String detectCategory(String merchantName) {
    final m = merchantName.toLowerCase();
    if (m.contains('uber') ||
        m.contains('ola') ||
        m.contains('rapido') ||
        m.contains('metro') ||
        m.contains('cab') ||
        m.contains('ride') ||
        m.contains('fuel') ||
        m.contains('petrol') ||
        m.contains('transport') ||
        m.contains('auto')) {
      return 'TRANSPORT';
    }
    if (m.contains('zomato') ||
        m.contains('swiggy') ||
        m.contains('food') ||
        m.contains('eat') ||
        m.contains('cafe') ||
        m.contains('coffee') ||
        m.contains('tea') ||
        m.contains('bistro') ||
        m.contains('restaurant') ||
        m.contains('starbucks') ||
        m.contains('instamart') ||
        m.contains('blinkit') ||
        m.contains('zepto') ||
        m.contains('grocery')) {
      return 'FOOD';
    }
    if (m.contains('amazon') ||
        m.contains('flipkart') ||
        m.contains('myntra') ||
        m.contains('shopping') ||
        m.contains('cloth') ||
        m.contains('store') ||
        m.contains('mart') ||
        m.contains('zara') ||
        m.contains('h&m')) {
      return 'SHOPPING';
    }
    if (m.contains('rent') ||
        m.contains('electricity') ||
        m.contains('water') ||
        m.contains('wifi') ||
        m.contains('broadband') ||
        m.contains('utility') ||
        m.contains('maintenance')) {
      return 'HOUSING';
    }
    if (m.contains('movie') ||
        m.contains('cinema') ||
        m.contains('pvr') ||
        m.contains('netflix') ||
        m.contains('hotstar') ||
        m.contains('prime') ||
        m.contains('spotify') ||
        m.contains('concert')) {
      return 'ENTERTAINMENT';
    }
    return 'FOOD';
  }
}

class DetectedSpend {
  final double amount;
  final String merchant;
  final String category;
  final String? accountEnding;
  final String rawBody;
  final int timestamp;

  DetectedSpend({
    required this.amount,
    required this.merchant,
    required this.category,
    this.accountEnding,
    required this.rawBody,
    required this.timestamp,
  });

  /// Unique fingerprint to prevent ever detecting the exact same transaction twice
  String get deduplicationHash =>
      '${amount.toStringAsFixed(2)}_${merchant.toLowerCase()}_${accountEnding ?? ''}';
}
