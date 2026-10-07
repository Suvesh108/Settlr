import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';
import 'confetti_overlay.dart';

class SmartSpendPopup extends StatefulWidget {
  final List<Group> groups;
  final Group? activeGroup;
  final VoidCallback onTransactionSaved;

  const SmartSpendPopup({
    super.key,
    required this.groups,
    required this.activeGroup,
    required this.onTransactionSaved,
  });

  @override
  State<SmartSpendPopup> createState() => SmartSpendPopupState();
}

class SmartSpendPopupState extends State<SmartSpendPopup> {
  bool _isVisible = false;
  String _detectedMerchant = '';
  double _detectedAmount = 0.0;
  String _selectedCategory = 'FOOD';
  String? _selectedGroupId;
  bool _isGroup = true;
  bool _isSaving = false;

  final List<String> _categories = ['FOOD', 'GROCERIES', 'TRANSPORT', 'RENT', 'SHOPPING', 'GENERAL'];

  void showWithData({
    required String merchant,
    required double amount,
  }) {
    setState(() {
      _detectedMerchant = merchant;
      _detectedAmount = amount;
      _selectedGroupId = widget.activeGroup?.id ?? (widget.groups.isNotEmpty ? widget.groups.first.id : null);
      _isVisible = true;
    });
  }

  void _dismiss() {
    setState(() => _isVisible = false);
  }

  Future<void> _save() async {
    if (_detectedAmount <= 0) return;
    setState(() => _isSaving = true);

    try {
      if (_isGroup && _selectedGroupId != null) {
        final group = widget.groups.firstWhere((g) => g.id == _selectedGroupId);
        final members = group.members ?? [];
        final myId = await ApiService.getUserId();

        final participants = members.map((m) {
          return {
            'user_id': m.user_id,
            'share_amount': ((_detectedAmount * 100) / members.length).round(),
          };
        }).toList();

        await ApiService.addExpense(
          groupId: _selectedGroupId!,
          amount: (_detectedAmount * 100).round(),
          description: _detectedMerchant.isNotEmpty ? _detectedMerchant : 'Quick Spend',
          paidBy: myId,
          splitType: 'EQUAL',
          category: _selectedCategory,
          participants: participants,
        );
      } else {
        await ApiService.addPersonalExpense(
          description: _detectedMerchant.isNotEmpty ? _detectedMerchant : 'Personal Spend',
          amount: (_detectedAmount * 100).round(),
          category: _selectedCategory,
          date: DateTime.now().toIso8601String().split('T')[0],
        );
      }

      // Blast confetti upon success!
      ConfettiOverlayController.instance.blast();
      widget.onTransactionSaved();
      _dismiss();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: SettlrCurves.spring,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1F000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: SettlrColors.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bolt, size: 16, color: SettlrColors.accent),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Smart Spend Detected',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                  ),
                ],
              ),
              BouncyPress(
                onTap: _dismiss,
                scaleDown: 0.90,
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            '$_detectedMerchant · ₹${_detectedAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: SettlrColors.textMain),
          ),
          const SizedBox(height: 10),

          // Segment: Group Split vs Personal Spend
          SlidingPillSegment(
            selectedIndex: _isGroup ? 0 : 1,
            itemCount: 2,
            height: 32,
            onSelected: (idx) => setState(() => _isGroup = idx == 0),
            children: const [
              Text('Split in Group', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              Text('Personal Spend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _dismiss,
                child: const Text('Dismiss', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              BouncyPress(
                onTap: _isSaving ? null : _save,
                scaleDown: 0.94,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: SettlrColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Record Expense',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
