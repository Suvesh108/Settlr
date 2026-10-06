import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class GroupSettingsModal extends StatefulWidget {
  final Group group;
  final List<UserBalance> balances;
  final VoidCallback onGroupChanged;

  const GroupSettingsModal({
    super.key,
    required this.group,
    required this.balances,
    required this.onGroupChanged,
  });

  @override
  State<GroupSettingsModal> createState() => _GroupSettingsModalState();
}

class _GroupSettingsModalState extends State<GroupSettingsModal> {
  bool _copied = false;
  bool _leaving = false;
  bool _deleting = false;
  String? _error;

  void _handleCopyCode() {
    Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _handleDeleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Are you sure you want to permanently delete "${widget.group.name}"? This will erase the group and its ledger for all members.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: SettlrColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SettlrColors.negative, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ApiService.deleteGroup(widget.group.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onGroupChanged();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to delete group: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _handleLeaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Are you sure you want to leave "${widget.group.name}"? Your past transactions and settlement records will remain intact for the group.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: SettlrColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SettlrColors.negative, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _leaving = true);
    try {
      await ApiService.leaveGroup(widget.group.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onGroupChanged();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to leave group: $e');
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ApiService.currentUser?.id ?? '';
    final isCreator = widget.group.createdBy == myId;

    final myBalRecord = widget.balances.firstWhere(
      (b) => b.userId == myId,
      orElse: () => UserBalance(userId: myId, name: '', netBalance: 0),
    );
    final isSettled = myBalRecord.netBalance.abs() == 0;
    final currency = widget.group.currency;
    final symbol = currency == 'INR' ? '₹' : currency;

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Group Settings & Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
                    const SizedBox(height: 2),
                    Text('Manage ${widget.group.name} preferences', style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
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

            // Invite Code Section
            if (isCreator) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('INVITE CODE (CREATOR ONLY)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SettlrColors.textMuted, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text(widget.group.inviteCode, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ],
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFE5E5E5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: _handleCopyCode,
                          icon: Icon(_copied ? Icons.check : Icons.copy, size: 14, color: _copied ? SettlrColors.positive : SettlrColors.textMain),
                          label: Text(_copied ? 'Copied' : 'Share Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _copied ? SettlrColors.positive : SettlrColors.textMain)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Share this invite code with friends or roommates to add them to this ledger.', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: SettlrColors.textMuted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Only the creator of this group can view and distribute the join code.', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Members List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('MEMBERS (${widget.group.members.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted, letterSpacing: 0.5)),
                Text('Ledger v${widget.group.ledgerVersion}', style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: widget.group.members.map((m) {
                  final isMe = m.userId == myId;
                  final isMemberCreator = m.userId == widget.group.createdBy;
                  final balRecord = widget.balances.firstWhere(
                    (b) => b.userId == m.userId,
                    orElse: () => UserBalance(userId: m.userId, name: '', netBalance: 0),
                  );
                  final b = balRecord.netBalance;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              m.name.isNotEmpty ? m.name[0].toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SettlrColors.textMain)),
                                  if (isMemberCreator) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Creator', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                    ),
                                  ],
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('You', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
                                    ),
                                  ],
                                ],
                              ),
                              Text(isMemberCreator ? 'OWNER' : m.role, style: const TextStyle(fontSize: 10, color: SettlrColors.textMuted)),
                            ],
                          ),
                        ),
                        Text(
                          b > 0
                              ? '+$symbol${(b / 100).toStringAsFixed(2)}'
                              : b < 0
                                  ? '-$symbol${(-b / 100).toStringAsFixed(2)}'
                                  : 'Settled',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: b > 0 ? SettlrColors.positive : b < 0 ? SettlrColors.negative : SettlrColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Leave / Delete Actions
            if (isCreator) ...[
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SettlrColors.negative,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _deleting ? null : _handleDeleteGroup,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                  label: Text(
                    _deleting ? 'Deleting Group...' : 'Delete Group',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isSettled ? SettlrColors.negative : SettlrColors.textMuted,
                    side: BorderSide(color: isSettled ? const Color(0xFFFECDD3) : const Color(0xFFE5E5E5)),
                    backgroundColor: isSettled ? SettlrColors.negativeBg : const Color(0xFFFAFAFA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (!isSettled || _leaving) ? null : _handleLeaveGroup,
                  icon: const Icon(Icons.logout, size: 16),
                  label: Text(
                    _leaving ? 'Leaving Group...' : isSettled ? 'Leave Group' : 'Settle balance to leave (₹${(myBalRecord.netBalance.abs() / 100).toStringAsFixed(2)})',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSettled ? SettlrColors.negative : SettlrColors.textMuted),
                  ),
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
