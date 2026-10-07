import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/sms_detector.dart';
import '../services/sms_service.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';
import 'confetti_overlay.dart';

class SmartSpendPopup extends StatefulWidget {
  final List<Group> groups;
  final Group? activeGroup;
  final Function(bool isPersonal) onTransactionSaved;

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
  String? _accountEnding;
  String _selectedCategory = 'FOOD';
  String? _selectedGroupId;
  String _destination = 'group'; // 'group' | 'personal'
  bool _isSaving = false;
  bool _savedSuccess = false;
  String? _deduplicationHash;

  static const List<Map<String, String>> personalCategories = [
    {'value': 'FOOD', 'label': 'Food & Groceries'},
    {'value': 'TRANSPORT', 'label': 'Transport & Fuel'},
    {'value': 'HOUSING', 'label': 'Housing & Utilities'},
    {'value': 'ENTERTAINMENT', 'label': 'Entertainment'},
    {'value': 'SHOPPING', 'label': 'Shopping & Personal'},
    {'value': 'GENERAL', 'label': 'General / Other'},
  ];

  void showWithData({
    required String merchant,
    required double amount,
    String? accountEnding,
    String? deduplicationHash,
  }) {
    if (_isVisible) return; // Prevent duplicate popup loops

    final autoCat = SmsSpendDetector.detectCategory(merchant);
    setState(() {
      _detectedMerchant = merchant;
      _detectedAmount = amount;
      _accountEnding = accountEnding;
      _deduplicationHash = deduplicationHash;
      _selectedCategory = autoCat;
      _selectedGroupId = widget.activeGroup?.id ?? (widget.groups.isNotEmpty ? widget.groups.first.id : null);
      _destination = (widget.groups.isNotEmpty && widget.activeGroup != null) ? 'group' : 'personal';
      _isSaving = false;
      _savedSuccess = false;
      _isVisible = true;
    });
  }

  void _dismiss() {
    if (_deduplicationHash != null) {
      SmsService.markSpendProcessed(_deduplicationHash!);
    }
    setState(() => _isVisible = false);
  }

  String _formatMoney(double amount, String currency) {
    final sym = currency == 'INR' ? '₹' : currency == 'USD' ? '\$' : currency == 'EUR' ? '€' : '£';
    return '$sym${amount.toStringAsFixed(2)}';
  }

  Future<void> _handleConfirm() async {
    if (_detectedAmount <= 0) return;
    setState(() => _isSaving = true);

    try {
      final isPersonal = _destination == 'personal';

      if (isPersonal) {
        final amountPaise = (_detectedAmount * 100).round();
        await ApiService.addPersonalExpense(
          description: _detectedMerchant.isNotEmpty ? _detectedMerchant : 'Personal Spend',
          amount: amountPaise,
          category: _selectedCategory,
          date: DateTime.now().toIso8601String().split('T')[0],
        );
      } else {
        final targetGroup = widget.groups.firstWhere(
          (g) => g.id == _selectedGroupId,
          orElse: () => widget.activeGroup ?? widget.groups.first,
        );
        final members = (targetGroup.members.isNotEmpty)
            ? targetGroup.members.where((m) => m.status == 'ACTIVE').toList()
            : [GroupMember(userId: ApiService.currentUser?.id ?? 'me', name: 'Me', email: '', role: 'MEMBER', status: 'ACTIVE')];

        final totalPaise = (_detectedAmount * 100).round();
        final participantCount = members.length;
        final baseShare = (totalPaise ~/ participantCount);
        int remainder = totalPaise % participantCount;

        final myId = ApiService.currentUser?.id ?? '';
        final participants = members.map((m) {
          final share = baseShare + (remainder > 0 ? 1 : 0);
          if (remainder > 0) remainder--;
          return {
            'user_id': m.userId,
            'share_amount': share,
          };
        }).toList();

        await ApiService.addExpense(
          groupId: targetGroup.id,
          amount: totalPaise,
          description: _detectedMerchant.isNotEmpty ? _detectedMerchant : 'Quick Spend',
          paidBy: myId.isNotEmpty ? myId : members.first.userId,
          splitType: 'EQUAL',
          category: _selectedCategory,
          participants: participants,
        );
      }

      setState(() => _savedSuccess = true);
      ConfettiOverlayController.instance.blast();

      if (_deduplicationHash != null) {
        SmsService.markSpendProcessed(_deduplicationHash!);
      }

      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        widget.onTransactionSaved(isPersonal);
        _dismiss();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save transaction: $e'),
            backgroundColor: SettlrColors.negative,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final curr = widget.activeGroup?.currency ?? 'INR';
    final targetGroup = widget.groups.firstWhere(
      (g) => g.id == _selectedGroupId,
      orElse: () => widget.activeGroup ?? (widget.groups.isNotEmpty ? widget.groups.first : Group(id: '', name: 'Personal', description: '', currency: 'INR', inviteCode: '', createdBy: '', members: [])),
    );
    final memberCount = targetGroup.members.where((m) => m.status == 'ACTIVE').length;
    final perPerson = memberCount > 0 ? (_detectedAmount / memberCount) : _detectedAmount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1F000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Dismiss handle + Close icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: Color(0xFF0284C7)),
                      SizedBox(width: 5),
                      Text(
                        'SMS Payment Detected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Amount Display
            Text(
              _formatMoney(_detectedAmount, curr),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: SettlrColors.textMain,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$_detectedMerchant${_accountEnding != null ? ' (A/c ••••$_accountEnding)' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: SettlrColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 18),

            // Segmented Switch: Group vs Personal (Exact match to WebApp)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _destination = 'group'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _destination == 'group' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _destination == 'group'
                              ? [const BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 18,
                              color: _destination == 'group' ? const Color(0xFF0284C7) : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Group',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _destination == 'group' ? FontWeight.bold : FontWeight.w500,
                                color: _destination == 'group' ? SettlrColors.textMain : SettlrColors.textMuted,
                              ),
                            ),
                            const Text(
                              'Auto-net debts',
                              style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _destination = 'personal'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _destination == 'personal' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _destination == 'personal'
                              ? [const BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 18,
                              color: _destination == 'personal' ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Personal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _destination == 'personal' ? FontWeight.bold : FontWeight.w500,
                                color: _destination == 'personal' ? SettlrColors.textMain : SettlrColors.textMuted,
                              ),
                            ),
                            const Text(
                              '100% mine',
                              style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // If Group: Group Selector & Split Breakdown
            if (_destination == 'group' && widget.groups.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TARGET LEDGER',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)),
                        ),
                        const SizedBox(height: 2),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGroupId ?? widget.groups.first.id,
                            isDense: true,
                            items: widget.groups.map((g) {
                              return DropdownMenuItem<String>(
                                value: g.id,
                                child: Text(
                                  g.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SettlrColors.textMain),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedGroupId = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    Text(
                      memberCount > 1 ? 'Split: ${_formatMoney(perPerson, curr)} / person' : '1 Member',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
              ),
            ],

            // If Personal: Category Selector
            if (_destination == 'personal') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CATEGORY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isDense: true,
                        items: personalCategories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['value']!,
                            child: Text(
                              c['label']!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SettlrColors.textMain),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _savedSuccess
                      ? const Color(0xFF10B981)
                      : SettlrColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: (_isSaving || _savedSuccess) ? null : _handleConfirm,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : _savedSuccess
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 18, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Logged & Synced!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _destination == 'group' ? 'Log to Group Ledger' : 'Log to Personal Stream',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
