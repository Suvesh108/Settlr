import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class AddPersonalExpenseModal extends StatefulWidget {
  final VoidCallback onExpenseAdded;

  const AddPersonalExpenseModal({super.key, required this.onExpenseAdded});

  @override
  State<AddPersonalExpenseModal> createState() => _AddPersonalExpenseModalState();
}

class _AddPersonalExpenseModalState extends State<AddPersonalExpenseModal> {
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _category = 'FOOD';
  String _date = DateTime.now().toIso8601String().split('T')[0];
  bool _loading = false;
  String? _error;

  final List<Map<String, String>> _categories = const [
    {'value': 'FOOD', 'label': 'Food & Groceries'},
    {'value': 'TRANSPORT', 'label': 'Transport & Fuel'},
    {'value': 'HOUSING', 'label': 'Housing & Utilities'},
    {'value': 'ENTERTAINMENT', 'label': 'Entertainment'},
    {'value': 'SHOPPING', 'label': 'Shopping & Personal'},
    {'value': 'GENERAL', 'label': 'General / Other'},
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final desc = _descCtrl.text.trim();
    final amtParsed = double.tryParse(_amtCtrl.text.trim());
    if (desc.isEmpty || amtParsed == null || amtParsed <= 0) {
      setState(() => _error = 'Please enter a description and valid amount.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.addPersonalExpense(
        description: desc,
        amount: (amtParsed * 100).round(),
        category: _category,
        date: _date,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onExpenseAdded();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to save expense: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = ApiService.currentUser?.defaultCurrency ?? 'INR';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Personal Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
                      SizedBox(height: 2),
                      Text('Private solitary expense kept off shared groups', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.close, size: 16, color: SettlrColors.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SettlrColors.negativeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: SettlrColors.negative),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: SettlrColors.negative))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              const Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _descCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: _inputDecoration('e.g. Coffee, Metro card recharge'),
              ),
              const SizedBox(height: 12),

              Text('Amount ($cur)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: _inputDecoration('0.00'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _category,
                              isExpanded: true,
                              style: const TextStyle(fontSize: 13, color: SettlrColors.textMain, fontWeight: FontWeight.w500),
                              items: _categories.map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!))).toList(),
                              onChanged: (v) => setState(() => _category = v ?? 'FOOD'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _date = picked.toIso8601String().split('T')[0]);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E5E5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: SettlrColors.textMain)),
                                const Icon(Icons.calendar_month, size: 16, color: SettlrColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SettlrColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _loading ? null : _handleSubmit,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Log Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E5E5))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E5E5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SettlrColors.textMain, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
