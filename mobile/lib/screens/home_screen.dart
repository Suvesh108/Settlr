import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0; // 0: Groups, 1: Personal
  List<Group> _groups = [];
  Group? _activeGroup;
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final groups = await ApiService.getGroups();
      setState(() {
        _groups = groups;
        if (groups.isNotEmpty) {
          _activeGroup = groups.first;
        }
      });
      if (_activeGroup != null) {
        final expenses = await ApiService.getExpenses(_activeGroup!.id);
        setState(() => _expenses = expenses);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _showProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileSheet(
        user: ApiService.currentUser,
        onLogout: () async {
          await ApiService.logout();
          if (!mounted) return;
          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        },
      ),
    );
  }

  void _showAddExpenseDialog() {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  const Text(
                    'Add Expense',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (${_activeGroup?.currency ?? 'INR'})',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SettlrColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () async {
                    final desc = descCtrl.text.trim();
                    final amt = double.tryParse(amtCtrl.text.trim());
                    if (desc.isEmpty || amt == null || amt <= 0 || _activeGroup == null) return;

                    Navigator.pop(ctx);
                    try {
                      await ApiService.addExpense(
                        groupId: _activeGroup!.id,
                        description: desc,
                        amount: (amt * 100).round(),
                        category: 'GENERAL',
                        splitType: 'EQUAL',
                        participantIds: _activeGroup!.members.map((m) => m.userId).toList(),
                      );
                      _loadInitialData();
                    } catch (_) {}
                  },
                  child: const Text('Record Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;

    return Scaffold(
      backgroundColor: SettlrColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SettlrColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('⚡', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
            const Text(
              'Settlr',
              style: TextStyle(
                color: SettlrColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // Profile Avatar Pill
          GestureDetector(
            onTap: _showProfileModal,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SettlrColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: SettlrColors.primary,
                    child: Text(
                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SettlrColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SettlrColors.primary))
          : Column(
              children: [
                // Gliding Segmented Pill Switcher (Groups vs Personal)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFEF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _currentTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _currentTab == 0
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Groups',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _currentTab == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: _currentTab == 0 ? SettlrColors.textMain : SettlrColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _currentTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _currentTab == 1
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Personal',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _currentTab == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: _currentTab == 1 ? SettlrColors.textMain : SettlrColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content View
                Expanded(
                  child: _currentTab == 0
                      ? _buildGroupsView()
                      : _buildPersonalView(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SettlrColors.primary,
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGroupsView() {
    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 48, color: SettlrColors.textSub),
            const SizedBox(height: 12),
            const Text('No Groups Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Create or join a group to start calculating debts.', style: TextStyle(color: SettlrColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Net Standing Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SettlrColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _activeGroup?.name ?? 'Group',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_activeGroup?.members.length ?? 0} members • Invite Code: ${_activeGroup?.inviteCode ?? ''}',
                style: const TextStyle(fontSize: 12, color: SettlrColors.textMuted),
              ),
              const Divider(height: 28),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Continuous Netting', style: TextStyle(fontSize: 12, color: SettlrColors.textMuted)),
                  Text('Balanced (₹0.00)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: SettlrColors.positive)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Transactions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        if (_expenses.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No expenses recorded yet', style: TextStyle(color: SettlrColors.textSub, fontSize: 13))),
          )
        else
          ..._expenses.map((exp) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SettlrColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long, size: 20, color: SettlrColors.textMain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(exp.category, style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                      ],
                    ),
                  ),
                  Text(
                    '₹${(exp.amount / 100).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPersonalView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SettlrColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Personal Solitary Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Private daily spending kept completely off shared groups.', style: TextStyle(fontSize: 12, color: SettlrColors.textMuted)),
              Divider(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Spend', style: TextStyle(fontSize: 12, color: SettlrColors.textMuted)),
                  Text('₹0.00', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSheet extends StatefulWidget {
  final User? user;
  final VoidCallback onLogout;

  const _ProfileSheet({required this.user, required this.onLogout});

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  bool _showConfirmLogout = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.between,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: SettlrColors.primary,
                    child: Text(
                      widget.user?.name.isNotEmpty == true ? widget.user!.name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.user?.name ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('Personal settings & profile', style: TextStyle(color: SettlrColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 24),

          // Custom animated logout warning message bar
          if (_showConfirmLogout)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SettlrColors.negativeBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SettlrColors.negative.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: SettlrColors.negative),
                      SizedBox(width: 8),
                      Text('Confirm Account Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: SettlrColors.negative)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'If you log out, your local session and personal offline data will be removed from this device.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9F1239), height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showConfirmLogout = false),
                        child: const Text('Cancel', style: TextStyle(color: SettlrColors.textMuted, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SettlrColors.negative,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: widget.onLogout,
                        child: const Text('Yes, Log Out', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: SettlrColors.negative),
              title: const Text('Log Out', style: TextStyle(color: SettlrColors.negative, fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () => setState(() => _showConfirmLogout = true),
            ),
          ],
        ],
      ),
    );
  }
}
