export interface ParsedTransaction {
  amount: number; // in Rupees / main currency units
  merchant: string;
  accountEnding?: string;
  type: 'DEBIT' | 'CREDIT';
  rawText: string;
  detectedAt: Date;
}

/**
 * Extracts transaction data from SMS notifications (Indian banks, UPI, cards, wallets)
 * Example SMS strings:
 * - "A/c *1234 debited for Rs 450.00 on 04-Oct-26 by UPI: ZOMATO. Avl Bal: Rs 12,340.00"
 * - "Rs. 1,200.00 debited from HDFC Bank A/c ending 5678 to Swiggy on 04-10-2026"
 * - "Paid Rs 340 to Blue Tokai Coffee via Google Pay"
 */
export function parseBankSMS(smsText: string): ParsedTransaction | null {
  if (!smsText || typeof smsText !== 'string') return null;

  const lower = smsText.toLowerCase();

  // Check if it's a debit transaction
  const isDebit =
    lower.includes('debited') ||
    lower.includes('spent') ||
    lower.includes('paid') ||
    lower.includes('withdrawn') ||
    lower.includes('purchase of');

  if (!isDebit) return null;

  // Regex patterns for amounts: Rs. 500, Rs 1,200.50, INR 350.00
  const amountRegex = /(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)/i;
  const amountMatch = smsText.match(amountRegex);

  if (!amountMatch) return null;

  const rawAmountStr = amountMatch[1].replace(/,/g, '');
  const amount = parseFloat(rawAmountStr);
  if (isNaN(amount) || amount <= 0) return null;

  // Extract merchant / recipient info
  let merchant = 'Card / UPI Payment';

  // Pattern 1: to/at [Merchant]
  const toMatch = smsText.match(/(?:to|at|info|vpa:?)\s+([A-Za-z0-9\s&._-]+?)(?:\s+on|\s+ref|\s+avl|\s+via|\.|$)/i);
  if (toMatch && toMatch[1].trim().length > 1) {
    merchant = toMatch[1].trim();
  } else {
    // Pattern 2: by UPI: [Merchant]
    const upiMatch = smsText.match(/upi:?\s*([A-Za-z0-9\s&._-]+?)(?:\s+on|\s+ref|\s+avl|\.|$)/i);
    if (upiMatch && upiMatch[1].trim().length > 1) {
      merchant = upiMatch[1].trim();
    }
  }

  // Account ending
  const accMatch = smsText.match(/(?:a\/c|acct|card|ending)\s*(?:no\.?)?\s*[\*xX]*(\d{4})/i);
  const accountEnding = accMatch ? accMatch[1] : undefined;

  return {
    amount,
    merchant,
    accountEnding,
    type: 'DEBIT',
    rawText: smsText,
    detectedAt: new Date(),
  };
}
