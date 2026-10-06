import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class RecordSettlementModal extends StatefulWidget {
  final Group group;
  final List<PairwiseDebt> pairwise;
  final String? prefillToUserId;
  final int? prefillAmountPaise;
  final VoidCallback onSettlementRecorded;

  const RecordSettlementModal({
    super.key,
    required this.group,
    required this.pairwise,
    this.prefillToUserId,
    this.prefillAmountPaise,
    required this.onSettlementRecorded,
  });

  @override
  State<RecordSettlementModal> createState() => _RecordSettlementModalState();
}

class _RecordSettlementModalState extends State<RecordSettlementModal> {
  final _amtCtrl = TextEditingController();
  String _toUser = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final myId = ApiService.currentUser?.id ?? '';
    final eligible = widget.group.members.where((m) => m.userId != myId && m.status == 'ACTIVE').toList();

    if (widget.prefillToUserId != null && eligible.any((m) => m.userId == widget.prefillToUserId)) {
      _toUser = widget.prefillToUserId!;
    } else if (eligible.isNotEmpty) {
      _toUser = eligible.first.userId;
    }

    if (widget.prefillAmountPaise != null && widget.prefillAmountPaise! > 0) {
      _amtCtrl.text = (widget.prefillAmountPaise! / 100).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  int _getDirectDebtToSelected() {
    final myId = ApiService.currentUser?.id ?? '';
    if (_toUser.isEmpty || myId.isEmpty) return 0;

    for (final p in widget.pairwise) {
      if (p.userA == _toUser && p.userB == myId) {
        return p.netDebt;
      } else if (p.userB == _toUser && p.userA == myId) {
        return -p.netDebt;
      }
    }
    return 0;
  }

  Future<void> _handleSubmit() async {
    setState(() => _error = null);

    final amtParsed = double.tryParse(_amtCtrl.text.trim());
    if (_toUser.isEmpty || amtParsed == null || amtParsed <= 0) {
      setState(() => _error = 'Please select a recipient and enter a valid positive payment amount.');
      return;
    }

    final toMember = widget.group.members.firstWhere(
      (m) => m.userId == _toUser,
      orElse: () => GroupMember(userId: _toUser, name: 'Member', email: '', role: 'MEMBER', status: 'ACTIVE'),
    );

    setState(() => _loading = true);
    try {
      await ApiService.recordSettlement(
        groupId: widget.group.id,
        toUser: _toUser,
        toUserName: toMember.name,
        amount: (amtParsed * 100).round(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSettlementRecorded();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to record settlement: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.group.currency;
    final symbol = currency == 'INR' ? '₹' : currency;
    final myId = ApiService.currentUser?.id ?? '';
    final eligible = widget.group.members.where((m) => m.userId != myId && m.status == 'ACTIVE').toList();
    final directDebt = _getDirectDebtToSelected();

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
                      Text('Record Settlement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
                      SizedBox(height: 2),
                      Text('Log an off-platform payment between members', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
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
                    border: Border.all(color: SettlrColors.negative.withOpacity(0.3)),
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

              if (eligible.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.group_outlined, size: 24, color: SettlrColors.textMuted),
                        SizedBox(height: 8),
                        Text(
                          'No other members in this group',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Share your group invite code from Group Settings so roommates or friends can join and settle up.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: SettlrColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Recipient Selector
                const Text('Recipient', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _toUser.isNotEmpty ? _toUser : null,
                      isExpanded: true,
                      hint: const Text('Select member to pay...'),
                      style: const TextStyle(fontSize: 13, color: SettlrColors.textMain, fontWeight: FontWeight.w500),
                      items: eligible.map((m) => DropdownMenuItem(value: m.userId, child: Text(m.name))).toList(),
                      onChanged: (v) => setState(() => _toUser = v ?? _toUser),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Direct Debt Position
                if (_toUser.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Direct debt position:', style: TextStyle(fontSize: 12, color: SettlrColors.textMuted)),
                        Text(
                          directDebt > 0
                              ? '$symbol${(directDebt / 100).toStringAsFixed(2)} (You owe)'
                              : directDebt < 0
                                  ? '$symbol${(-directDebt / 100).toStringAsFixed(2)} (Owed to you)'
                                  : '$symbol 0.00 (No debt)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: directDebt > 0 ? SettlrColors.negative : directDebt < 0 ? SettlrColors.positive : SettlrColors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Amount Paid
                Text('Amount Paid ($currency)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E5E5))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E5E5))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SettlrColors.textMain, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Info Notice
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Marked as Recorded until the recipient confirms receipt.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Submit Button
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
                        : const Text('Record Payment Claim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
