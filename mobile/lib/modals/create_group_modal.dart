import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class CreateGroupModal extends StatefulWidget {
  final VoidCallback onGroupCreated;

  const CreateGroupModal({super.key, required this.onGroupCreated});

  @override
  State<CreateGroupModal> createState() => _CreateGroupModalState();
}

class _CreateGroupModalState extends State<CreateGroupModal> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _currency = 'INR';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a group name.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.createGroup(
        name: name,
        description: _descCtrl.text.trim(),
        currency: _currency,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onGroupCreated();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to create group: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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
                  Text('Create Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
                  SizedBox(height: 2),
                  Text('Start a new shared expense ledger', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
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

          const Text('Group Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: _inputDecoration('e.g. Flat 4B, Goa Trip 2026'),
          ),
          const SizedBox(height: 12),

          const Text('Description (Optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: _inputDecoration('e.g. Shared apartment expenses and bills'),
          ),
          const SizedBox(height: 12),

          const Text('Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
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
                value: _currency,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                  DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'INR'),
              ),
            ),
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
                  : const Text('Create Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
