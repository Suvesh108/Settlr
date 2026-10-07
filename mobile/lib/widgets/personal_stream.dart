import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';

class PersonalStream extends StatefulWidget {
  final List<PersonalExpense> expenses;
  final String currency;
  final VoidCallback onAddExpense;
  final Function(String id) onDeleteExpense;

  const PersonalStream({
    super.key,
    required this.expenses,
    required this.currency,
    required this.onAddExpense,
    required this.onDeleteExpense,
  });

  @override
  State<PersonalStream> createState() => _PersonalStreamState();
}

class _PersonalStreamState extends State<PersonalStream> {
  String _selectedCategory = 'ALL';

  static const List<Map<String, String>> categories = [
    {'id': 'ALL', 'label': 'All'},
    {'id': 'FOOD', 'label': 'Food'},
    {'id': 'TRANSPORT', 'label': 'Transport'},
    {'id': 'HOUSING', 'label': 'Housing'},
    {'id': 'ENTERTAINMENT', 'label': 'Entertainment'},
    {'id': 'SHOPPING', 'label': 'Shopping'},
    {'id': 'GENERAL', 'label': 'General'},
  ];

  String _formatMoney(double amount, String curr) {
    final sym = curr == 'INR' ? '₹' : curr == 'USD' ? '\$' : curr == 'EUR' ? '€' : '£';
    return '$sym${amount.toStringAsFixed(2)}';
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, y').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSpent = widget.expenses.fold<double>(0.0, (sum, e) => sum + (e.amount / 100));
    final filtered = _selectedCategory == 'ALL'
        ? widget.expenses
        : widget.expenses.where((e) => e.category.toUpperCase() == _selectedCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Card: Personal Spend Summary
        SettlrPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Ledger',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                      ),
                      Text(
                        'Private offline expense tracking',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  BouncyPress(
                    onTap: widget.onAddExpense,
                    scaleDown: 0.92,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: SettlrColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Add Spend',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x14000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Personal Spending', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      _formatMoney(totalSpent, widget.currency),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: SettlrColors.textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.expenses.length} personal transactions logged',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Transactions List Card
        SettlrPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: BouncyPress(
                        onTap: () => setState(() => _selectedCategory = cat['id']!),
                        scaleDown: 0.92,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? SettlrColors.primary : const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cat['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 14),

              if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_outlined, size: 28, color: Colors.grey),
                      const SizedBox(height: 6),
                      const Text(
                        'No personal expenses',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                      ),
                      Text(
                        'Tap "+ Add Spend" to log individual purchases.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0x0F000000)),
                  itemBuilder: (ctx, i) {
                    final exp = filtered[i];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x14000000)),
                            ),
                            child: Center(
                              child: Text(
                                exp.category.isNotEmpty ? exp.category.substring(0, 1).toUpperCase() : 'P',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: SettlrColors.textMain),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exp.description,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${exp.category} · ${_formatDate(exp.date)}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatMoney(exp.amount / 100, widget.currency),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                          ),
                          const SizedBox(width: 8),
                          BouncyPress(
                            onTap: () => widget.onDeleteExpense(exp.id),
                            scaleDown: 0.90,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
