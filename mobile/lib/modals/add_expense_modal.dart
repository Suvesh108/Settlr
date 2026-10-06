import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class AddExpenseModal extends StatefulWidget {
  final Group group;
  final VoidCallback onExpenseAdded;

  const AddExpenseModal({
    super.key,
    required this.group,
    required this.onExpenseAdded,
  });

  @override
  State<AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();

  String _category = 'FOOD';
  String _splitType = 'EQUAL'; // EQUAL, EXACT, PERCENTAGE, SHARES
  String _paidBy = '';

  List<String> _selectedUserIds = [];
  final Map<String, TextEditingController> _exactCtrls = {};
  final Map<String, TextEditingController> _pctCtrls = {};
  final Map<String, TextEditingController> _shareCtrls = {};

  bool _loading = false;
  String? _error;

  final List<Map<String, String>> _categories = const [
    {'value': 'FOOD', 'label': 'Food & Dining'},
    {'value': 'GROCERIES', 'label': 'Groceries'},
    {'value': 'RENT', 'label': 'Rent & Housing'},
    {'value': 'UTILITIES', 'label': 'Utilities & Wifi'},
    {'value': 'TRAVEL', 'label': 'Travel & Transport'},
    {'value': 'ENTERTAINMENT', 'label': 'Entertainment'},
    {'value': 'SHOPPING', 'label': 'Shopping'},
    {'value': 'GENERAL', 'label': 'General'},
  ];

  @override
  void initState() {
    super.initState();
    final members = widget.group.members.where((m) => m.status == 'ACTIVE').toList();
    _selectedUserIds = members.map((m) => m.userId).toList();

    final myId = ApiService.currentUser?.id ?? '';
    if (members.any((m) => m.userId == myId)) {
      _paidBy = myId;
    } else if (members.isNotEmpty) {
      _paidBy = members.first.userId;
    }

    for (final m in members) {
      _exactCtrls[m.userId] = TextEditingController();
      _pctCtrls[m.userId] = TextEditingController();
      _shareCtrls[m.userId] = TextEditingController(text: '1');
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    for (final c in _exactCtrls.values) {
      c.dispose();
    }
    for (final c in _pctCtrls.values) {
      c.dispose();
    }
    for (final c in _shareCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSplitTypeChanged(String newType) {
    setState(() {
      _splitType = newType;
      _error = null;

      final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
      if (amt > 0 && _selectedUserIds.isNotEmpty) {
        if (newType == 'EXACT') {
          final perPerson = (amt / _selectedUserIds.length).toStringAsFixed(2);
          for (final uid in _selectedUserIds) {
            _exactCtrls[uid]?.text = perPerson;
          }
        } else if (newType == 'PERCENTAGE') {
          final perPersonPct = (100.0 / _selectedUserIds.length).toStringAsFixed(1);
          for (final uid in _selectedUserIds) {
            _pctCtrls[uid]?.text = perPersonPct;
          }
        }
      }
    });
  }

  void _toggleUser(String uid) {
    setState(() {
      if (_selectedUserIds.contains(uid)) {
        if (_selectedUserIds.length > 1) {
          _selectedUserIds.remove(uid);
        }
      } else {
        _selectedUserIds.add(uid);
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _error = null);

    final desc = _descCtrl.text.trim();
    final amtParsed = double.tryParse(_amtCtrl.text.trim());
    if (desc.isEmpty || amtParsed == null || amtParsed <= 0) {
      setState(() => _error = 'Please provide a valid description and positive amount.');
      return;
    }

    final totalPaise = (amtParsed * 100).round();
    if (_selectedUserIds.isEmpty) {
      setState(() => _error = 'Select at least one participant.');
      return;
    }

    final List<Map<String, dynamic>> participantPayload = [];

    if (_splitType == 'EQUAL') {
      final base = totalPaise ~/ _selectedUserIds.length;
      final rem = totalPaise % _selectedUserIds.length;
      for (int i = 0; i < _selectedUserIds.length; i++) {
        final share = base + (i < rem ? 1 : 0);
        participantPayload.add({
          'user_id': _selectedUserIds[i],
          'share_amount': share,
        });
      }
    } else if (_splitType == 'EXACT') {
      int sum = 0;
      for (final uid in _selectedUserIds) {
        final val = double.tryParse(_exactCtrls[uid]?.text.trim() ?? '') ?? 0;
        final pPaise = (val * 100).round();
        if (pPaise <= 0) {
          setState(() => _error = 'Each participant must have a positive exact share.');
          return;
        }
        sum += pPaise;
        participantPayload.add({'user_id': uid, 'share_amount': pPaise});
      }
      if (sum != totalPaise) {
        final cur = widget.group.currency;
        setState(() => _error = 'Exact shares sum ($cur ${(sum / 100).toStringAsFixed(2)}) must match total ($cur ${(totalPaise / 100).toStringAsFixed(2)}).');
        return;
      }
    } else if (_splitType == 'PERCENTAGE') {
      int bpsSum = 0;
      for (final uid in _selectedUserIds) {
        final val = double.tryParse(_pctCtrls[uid]?.text.trim() ?? '') ?? 0;
        final bps = (val * 100).round();
        if (bps <= 0) {
          setState(() => _error = 'Each participant must have a positive percentage.');
          return;
        }
        bpsSum += bps;
      }
      if (bpsSum != 10000) {
        setState(() => _error = 'Percentages must total exactly 100% (currently ${(bpsSum / 100).toStringAsFixed(1)}%).');
        return;
      }
      int allocated = 0;
      for (int i = 0; i < _selectedUserIds.length; i++) {
        final uid = _selectedUserIds[i];
        final val = double.tryParse(_pctCtrls[uid]?.text.trim() ?? '') ?? 0;
        final bps = (val * 100).round();
        final share = i == _selectedUserIds.length - 1
            ? totalPaise - allocated
            : ((totalPaise * bps) / 10000).round();
        allocated += share;
        participantPayload.add({'user_id': uid, 'share_amount': share, 'basis_points': bps});
      }
    } else if (_splitType == 'SHARES') {
      int totalShares = 0;
      for (final uid in _selectedUserIds) {
        final val = int.tryParse(_shareCtrls[uid]?.text.trim() ?? '1') ?? 1;
        totalShares += val;
      }
      int allocated = 0;
      for (int i = 0; i < _selectedUserIds.length; i++) {
        final uid = _selectedUserIds[i];
        final val = int.tryParse(_shareCtrls[uid]?.text.trim() ?? '1') ?? 1;
        final share = i == _selectedUserIds.length - 1
            ? totalPaise - allocated
            : ((totalPaise * val) / (totalShares > 0 ? totalShares : 1)).round();
        allocated += share;
        participantPayload.add({'user_id': uid, 'share_amount': share, 'shares': val});
      }
    }

    setState(() => _loading = true);
    try {
      await ApiService.addExpense(
        groupId: widget.group.id,
        description: desc,
        amount: totalPaise,
        category: _category,
        splitType: _splitType,
        paidBy: _paidBy,
        participants: participantPayload,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onExpenseAdded();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to record expense: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.group.currency;
    final symbol = currency == 'INR' ? '₹' : currency;
    final members = widget.group.members.where((m) => m.status == 'ACTIVE').toList();

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
                      Text(
                        'Add Expense',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                      ),
                      Text(
                        'Record a new group transaction',
                        style: TextStyle(fontSize: 11, color: SettlrColors.textMuted),
                      ),
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
                      Expanded(
                        child: Text(_error!, style: const TextStyle(fontSize: 12, color: SettlrColors.negative)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Amount & Category row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amount ($currency)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amtCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: _inputDecoration('0.00'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
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
                ],
              ),
              const SizedBox(height: 12),

              // Description
              const Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _descCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: _inputDecoration('e.g. Dinner, Grocery run'),
              ),
              const SizedBox(height: 12),

              // Paid By Dropdown
              const Text('Paid by', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
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
                    value: _paidBy.isNotEmpty ? _paidBy : (members.isNotEmpty ? members.first.userId : null),
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: SettlrColors.textMain, fontWeight: FontWeight.w500),
                    items: members.map((m) {
                      final isMe = m.userId == ApiService.currentUser?.id;
                      return DropdownMenuItem(
                        value: m.userId,
                        child: Text('${m.name}${isMe ? ' (You)' : ''}'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _paidBy = v ?? _paidBy),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Participant Checklist
              Text(
                'Split between (${_selectedUserIds.length} selected)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: members.map((m) {
                  final selected = _selectedUserIds.contains(m.userId);
                  return GestureDetector(
                    onTap: () => _toggleUser(m.userId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? SettlrColors.primary : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? SettlrColors.primary : const Color(0xFFE5E5E5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : SettlrColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Split Method Selector
              const Text('Split method', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: ['EQUAL', 'EXACT', 'PERCENTAGE', 'SHARES'].map((mode) {
                    final active = _splitType == mode;
                    final label = mode == 'EQUAL' ? 'Equal' : mode == 'EXACT' ? 'Exact' : mode == 'PERCENTAGE' ? '%' : 'Shares';
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onSplitTypeChanged(mode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3)] : null,
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                                color: active ? SettlrColors.textMain : SettlrColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Dynamic Split Breakdown
              if (_splitType == 'EQUAL') ...[
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
                      Text('Per person (${_selectedUserIds.length} members):', style: const TextStyle(fontSize: 12, color: SettlrColors.textMuted)),
                      Text(
                        '$symbol${_selectedUserIds.isNotEmpty && double.tryParse(_amtCtrl.text) != null ? ((double.parse(_amtCtrl.text) / _selectedUserIds.length)).toStringAsFixed(2) : '0.00'}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                      ),
                    ],
                  ),
                ),
              ] else if (_splitType == 'EXACT') ...[
                ..._selectedUserIds.map((uid) {
                  final m = members.firstWhere((mem) => mem.userId == uid, orElse: () => GroupMember(userId: uid, name: 'User', email: '', role: 'MEMBER', status: 'ACTIVE'));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _exactCtrls[uid],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              prefixText: '$symbol ',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ] else if (_splitType == 'PERCENTAGE') ...[
                ..._selectedUserIds.map((uid) {
                  final m = members.firstWhere((mem) => mem.userId == uid, orElse: () => GroupMember(userId: uid, name: 'User', email: '', role: 'MEMBER', status: 'ACTIVE'));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _pctCtrls[uid],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              suffixText: '%',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ] else if (_splitType == 'SHARES') ...[
                ..._selectedUserIds.map((uid) {
                  final m = members.firstWhere((mem) => mem.userId == uid, orElse: () => GroupMember(userId: uid, name: 'User', email: '', role: 'MEMBER', status: 'ACTIVE'));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: _shareCtrls[uid],
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              suffixText: 'pt',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              const SizedBox(height: 20),

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
                      : const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    );
  }
}
