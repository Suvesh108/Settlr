import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../theme/colors.dart';
import '../modals/add_expense_modal.dart';
import '../modals/expense_details_modal.dart';
import '../modals/record_settlement_modal.dart';
import '../modals/pairwise_modal.dart';
import '../modals/group_settings_modal.dart';
import '../modals/create_group_modal.dart';
import '../modals/join_group_modal.dart';
import '../modals/add_personal_expense_modal.dart';
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
  List<UserBalance> _balances = [];
  List<PairwiseDebt> _pairwise = [];
  List<RecommendedTransfer> _transfers = [];
  List<Settlement> _settlements = [];
  List<ActivityItem> _activities = [];

  List<PersonalExpense> _personalExpenses = [];
  String _personalCategoryFilter = 'ALL';
  String _expenseCategoryFilter = 'ALL';

  String _groupSubTab = 'overview'; // 'overview' | 'expenses' | 'settlements' | 'activity'

  bool _isFirstLoad = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Instant Cache-First Load
    final cachedGroups = await ApiService.getCachedGroups();
    final cachedPersonal = await ApiService.getPersonalExpenses();

    if (!mounted) return;

    if (cachedGroups.isEmpty) {
      setState(() => _isFirstLoad = true);
    } else {
      setState(() {
        _groups = cachedGroups;
        _activeGroup = cachedGroups.first;
        _personalExpenses = cachedPersonal;
        _isFirstLoad = false;
      });

      final cachedExp = await ApiService.getCachedExpenses(cachedGroups.first.id);
      final cachedStl = await ApiService.getCachedSettlements(cachedGroups.first.id);
      if (mounted) {
        setState(() {
          _expenses = cachedExp;
          _settlements = cachedStl;
        });
      }
    }

    // 2. Silent Background Server Sync
    _syncServerData();
  }

  Future<void> _syncServerData() async {
    if (mounted) setState(() => _isRefreshing = true);

    try {
      final remoteGroups = await ApiService.getGroups();
      final personal = await ApiService.getPersonalExpenses();

      if (!mounted) return;
      setState(() {
        _groups = remoteGroups;
        _personalExpenses = personal;
        if (_activeGroup == null && remoteGroups.isNotEmpty) {
          _activeGroup = remoteGroups.first;
        } else if (_activeGroup != null && remoteGroups.isNotEmpty) {
          _activeGroup = remoteGroups.firstWhere(
            (g) => g.id == _activeGroup!.id,
            orElse: () => remoteGroups.first,
          );
        }
        _isFirstLoad = false;
      });

      if (_activeGroup != null) {
        await _fetchActiveGroupDetails(_activeGroup!.id);
      }
    } catch (_) {
      if (mounted) setState(() => _isFirstLoad = false);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _fetchActiveGroupDetails(String groupId) async {
    try {
      final exp = await ApiService.getExpenses(groupId);
      final bals = await ApiService.getBalances(groupId, _activeGroup);
      final debts = await ApiService.getPairwiseDebts(groupId);
      final recs = await ApiService.getRecommendedSettlements(groupId, bals);
      final stls = await ApiService.getSettlements(groupId);
      final acts = await ApiService.getActivity(groupId);

      if (!mounted) return;
      setState(() {
        _expenses = exp;
        _balances = bals;
        _pairwise = debts;
        _transfers = recs;
        _settlements = stls;
        _activities = acts;
      });
    } catch (_) {}
  }

  void _switchGroup(Group g) {
    setState(() {
      _activeGroup = g;
      _expenses = [];
      _balances = [];
      _pairwise = [];
      _transfers = [];
      _settlements = [];
      _activities = [];
    });
    _fetchActiveGroupDetails(g.id);
  }

  // ── Modals Trigger ─────────────────────────────────────────────────────────

  void _openAddExpenseModal() {
    if (_activeGroup == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseModal(
        group: _activeGroup!,
        onExpenseAdded: () => _fetchActiveGroupDetails(_activeGroup!.id),
      ),
    );
  }

  void _openExpenseDetailsModal(Expense exp) {
    if (_activeGroup == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseDetailsModal(
        group: _activeGroup!,
        expense: exp,
        onExpenseReversed: () => _fetchActiveGroupDetails(_activeGroup!.id),
      ),
    );
  }

  void _openRecordSettlementModal({String? toUserId, int? amountPaise}) {
    if (_activeGroup == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordSettlementModal(
        group: _activeGroup!,
        pairwise: _pairwise,
        prefillToUserId: toUserId,
        prefillAmountPaise: amountPaise,
        onSettlementRecorded: () => _fetchActiveGroupDetails(_activeGroup!.id),
      ),
    );
  }

  void _openPairwiseModal(String targetUserId, String targetUserName) {
    if (_activeGroup == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PairwiseModal(
        group: _activeGroup!,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        pairwise: _pairwise,
        onSettleUp: (toUserId, amountPaise) {
          _openRecordSettlementModal(toUserId: toUserId, amountPaise: amountPaise);
        },
      ),
    );
  }

  void _openGroupSettingsModal() {
    if (_activeGroup == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupSettingsModal(
        group: _activeGroup!,
        balances: _balances,
        onGroupChanged: _syncServerData,
      ),
    );
  }

  void _openCreateGroupModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateGroupModal(onGroupCreated: _syncServerData),
    );
  }

  void _openJoinGroupModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JoinGroupModal(onGroupJoined: _syncServerData),
    );
  }

  void _openAddPersonalExpenseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPersonalExpenseModal(
        onExpenseAdded: () async {
          final personal = await ApiService.getPersonalExpenses();
          if (mounted) setState(() => _personalExpenses = personal);
        },
      ),
    );
  }

  void _openProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileSheet(
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;

    if (_isFirstLoad) {
      return Scaffold(
        backgroundColor: SettlrColors.background,
        appBar: _buildAppBar(user),
        body: const Center(
          child: CircularProgressIndicator(color: SettlrColors.primary, strokeWidth: 2.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SettlrColors.background,
      appBar: _buildAppBar(user),
      body: Column(
        children: [
          if (_isRefreshing)
            const LinearProgressIndicator(
              minHeight: 2,
              color: SettlrColors.textMain,
              backgroundColor: Colors.transparent,
            ),

          // Segmented Tabs: Groups vs Personal
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Row(
              children: [
                _TabPill(
                  label: 'Groups',
                  icon: Icons.groups_outlined,
                  isActive: _currentTab == 0,
                  onTap: () => setState(() => _currentTab = 0),
                ),
                _TabPill(
                  label: 'Personal',
                  icon: Icons.person_outline,
                  isActive: _currentTab == 1,
                  onTap: () => setState(() => _currentTab = 1),
                ),
              ],
            ),
          ),

          // Main View
          Expanded(
            child: _currentTab == 0 ? _buildGroupsView() : _buildPersonalView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SettlrColors.primary,
        elevation: 0,
        onPressed: _currentTab == 0 ? _openAddExpenseModal : _openAddPersonalExpenseModal,
        icon: const Icon(Icons.add, color: Colors.white, size: 18),
        label: Text(
          _currentTab == 0 ? 'Add Expense' : 'Add Personal',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(User? user) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: const Color(0xFFE5E5E5)),
      ),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset('assets/images/logo.png', width: 26, height: 26, fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          const Text(
            'Settlr',
            style: TextStyle(
              color: SettlrColors.textMain,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: _openProfileModal,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: SettlrColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text(
                      user?.name.isNotEmpty == true ? user!.name.substring(0, 1).toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  user?.name ?? 'User',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SettlrColors.textMain),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Groups Tab View ────────────────────────────────────────────────────────

  Widget _buildGroupsView() {
    if (_groups.isEmpty) {
      return _buildEmptyGroupsState();
    }

    final currency = _activeGroup?.currency ?? 'INR';
    final symbol = currency == 'INR' ? '₹' : currency;
    final myId = ApiService.currentUser?.id ?? '';
    final myBalRecord = _balances.firstWhere((b) => b.userId == myId, orElse: () => UserBalance(userId: myId, name: '', netBalance: 0));
    final myBalance = myBalRecord.netBalance;

    final activeExpenses = _expenses.where((e) => !e.isReversed && !e.isReversal).toList();
    final totalSpend = activeExpenses.fold<int>(0, (sum, e) => sum + e.amount);

    final pendingSettlements = _settlements.where((s) => s.status == 'PAYMENT_RECORDED').toList();

    return RefreshIndicator(
      color: SettlrColors.primary,
      onRefresh: _syncServerData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          // Group selector pills
          _buildGroupSwitcherRow(),
          const SizedBox(height: 12),

          // Net Standing Hero Card
          _buildNetStandingCard(
            group: _activeGroup,
            myBalance: myBalance,
            totalSpend: totalSpend,
            symbol: symbol,
          ),
          const SizedBox(height: 14),

          // Sub Tabs: Overview | Expenses | Settlements | Activity
          _buildSubTabBar(),
          const SizedBox(height: 14),

          // Sub-Tab Content
          if (_groupSubTab == 'overview') ...[
            if (pendingSettlements.isNotEmpty) ...[
              _buildPendingSettlementsBanner(pendingSettlements, symbol),
              const SizedBox(height: 14),
            ],
            _buildSettlementPlanCard(symbol),
            const SizedBox(height: 14),
            _buildMemberStandingsCard(symbol),
          ],

          if (_groupSubTab == 'expenses') ...[
            _buildTransactionActivityCard(symbol),
          ],

          if (_groupSubTab == 'settlements') ...[
            if (pendingSettlements.isNotEmpty) ...[
              _buildPendingSettlementsBanner(pendingSettlements, symbol),
              const SizedBox(height: 14),
            ],
            _buildSettlementPlanCard(symbol),
            const SizedBox(height: 14),
            _buildSettlementsHistoryCard(symbol),
          ],

          if (_groupSubTab == 'activity') ...[
            _buildActivityFeedCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupSwitcherRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._groups.map((g) {
            final active = g.id == _activeGroup?.id;
            return GestureDetector(
              onTap: () => _switchGroup(g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? SettlrColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? SettlrColors.primary : const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  g.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : SettlrColors.textMuted,
                  ),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: _openCreateGroupModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 14, color: SettlrColors.textMuted),
                  SizedBox(width: 4),
                  Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SettlrColors.textMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openJoinGroupModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.group_add_outlined, size: 14, color: SettlrColors.textMuted),
                  SizedBox(width: 4),
                  Text('Join', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SettlrColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetStandingCard({
    required Group? group,
    required int myBalance,
    required int totalSpend,
    required String symbol,
  }) {
    final isCreditor = myBalance > 0;
    final isDebtor = myBalance < 0;
    final isSettled = myBalance == 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SettlrColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group?.name ?? 'Group',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: Text('v${group?.ledgerVersion ?? 1}', style: const TextStyle(fontSize: 10, color: SettlrColors.textMuted, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group?.members.length ?? 0} members · ${group?.inviteCode ?? ''}',
                      style: const TextStyle(fontSize: 12, color: SettlrColors.textMuted),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openGroupSettingsModal,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: const Icon(Icons.settings_outlined, size: 16, color: SettlrColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Balance metrics panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Balance in this Group', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SettlrColors.textMuted)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$symbol${(myBalance.abs() / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isCreditor ? SettlrColors.positive : isDebtor ? SettlrColors.negative : SettlrColors.textMain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSettled ? SettlrColors.positiveBg : isCreditor ? SettlrColors.positiveBg : SettlrColors.negativeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSettled || isCreditor ? const Color(0xFFD1FAE5) : const Color(0xFFFECDD3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSettled ? Icons.check_circle_outline : isCreditor ? Icons.arrow_outward : Icons.arrow_downward,
                            size: 12,
                            color: isSettled || isCreditor ? SettlrColors.positive : SettlrColors.negative,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSettled ? 'All settled up' : isCreditor ? 'You are owed' : 'You owe money',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSettled || isCreditor ? SettlrColors.positive : SettlrColors.negative,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isSettled
                      ? 'Zero pending dues. All your group expenses are fully squared.'
                      : isCreditor
                          ? 'Members with pending balances will transfer funds to zero out accounts.'
                          : 'Use Settle Up to transfer your dues and square your accounts.',
                  style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE5E5E5)),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Group Spending', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '$symbol${(totalSpend / 100).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                        ),
                        Text('${group?.members.length ?? 0} active members', style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SettlrColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _openAddExpenseModal,
                          icon: const Icon(Icons.add, size: 14, color: Colors.white),
                          label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFE5E5E5)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openRecordSettlementModal(),
                          icon: const Icon(Icons.credit_card_outlined, size: 14, color: SettlrColors.textMain),
                          label: const Text('Settle', style: TextStyle(color: SettlrColors.textMain, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabBar() {
    const tabs = ['overview', 'expenses', 'settlements', 'activity'];
    const labels = ['Overview', 'Expenses', 'Settlements', 'Activity'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _groupSubTab == tabs[i];
          return GestureDetector(
            onTap: () => setState(() => _groupSubTab = tabs[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? SettlrColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? SettlrColors.primary : const Color(0xFFE5E5E5)),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : SettlrColors.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPendingSettlementsBanner(List<Settlement> pending, String symbol) {
    final myId = ApiService.currentUser?.id ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              Text(
                'PENDING SETTLEMENTS (${pending.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...pending.map((s) {
            final isReceiver = s.toUser == myId;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${s.fromUserName} paid $symbol${(s.amount / 100).toStringAsFixed(2)} to ${s.toUserName}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SettlrColors.textMain),
                    ),
                  ),
                  if (isReceiver)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SettlrColors.positive,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        if (_activeGroup != null) {
                          await ApiService.confirmSettlement(_activeGroup!.id, s.id);
                          _fetchActiveGroupDetails(_activeGroup!.id);
                        }
                      },
                      child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSettlementPlanCard(String symbol) {
    final myId = ApiService.currentUser?.id ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SettlrColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settlement Plan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
          const SizedBox(height: 2),
          const Text('Minimum cashflow transfers to balance all accounts to zero', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
          const SizedBox(height: 14),

          if (_transfers.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20, color: SettlrColors.positive),
                    SizedBox(height: 6),
                    Text('All accounts are settled', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SettlrColors.textMain)),
                    SizedBox(height: 2),
                    Text('No transfers needed between group members.', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                  ],
                ),
              ),
            ),
          ] else ...[
            ..._transfers.map((t) {
              final isSender = t.fromUser == myId;
              final isReceiver = t.toUser == myId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${t.fromUserName}${isSender ? ' (You)' : ''}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SettlrColors.textMain),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward, size: 14, color: SettlrColors.textMuted),
                          ),
                          Flexible(
                            child: Text(
                              '${t.toUserName}${isReceiver ? ' (You)' : ''}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SettlrColors.textMain),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$symbol${(t.amount / 100).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                    ),
                    if (isSender) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SettlrColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _openRecordSettlementModal(toUserId: t.toUser, amountPaise: t.amount),
                        child: const Text('Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberStandingsCard(String symbol) {
    final myId = ApiService.currentUser?.id ?? '';
    final members = _activeGroup?.members ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SettlrColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Member Standings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
          const SizedBox(height: 2),
          const Text('Tap any member to inspect mutual bilateral expenses', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
          const SizedBox(height: 14),

          ...members.map((m) {
            final isMe = m.userId == myId;
            final isCreator = m.userId == _activeGroup?.createdBy;
            final balRecord = _balances.firstWhere(
              (b) => b.userId == m.userId,
              orElse: () => UserBalance(userId: m.userId, name: m.name, netBalance: 0),
            );
            final b = balRecord.netBalance;

            return GestureDetector(
              onTap: () {
                if (!isMe) _openPairwiseModal(m.userId, m.name);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: SettlrColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          m.name.isNotEmpty ? m.name.substring(0, 1).toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SettlrColors.textMain),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCreator) ...[
                            const SizedBox(width: 4),
                            const Text('*', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            const Text('(You)', style: TextStyle(color: SettlrColors.textMuted, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Balance', style: TextStyle(fontSize: 10, color: SettlrColors.textMuted)),
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
                    if (!isMe) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD4D4D4)),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransactionActivityCard(String symbol) {
    final active = _expenses.where((e) {
      if (e.isReversed) return false;
      if (_expenseCategoryFilter == 'ALL') return true;
      return e.category == _expenseCategoryFilter;
    }).toList();

    const categories = ['ALL', 'FOOD', 'GROCERIES', 'RENT', 'TRAVEL', 'UTILITIES'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SettlrColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transaction Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
          const SizedBox(height: 2),
          const Text('Immutable expense ledger entries with split breakdown', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
          const SizedBox(height: 14),

          // Category Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final activePill = _expenseCategoryFilter == cat;
                return GestureDetector(
                  onTap: () => setState(() => _expenseCategoryFilter = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: activePill ? SettlrColors.primary : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cat == 'ALL' ? 'All' : cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: activePill ? Colors.white : SettlrColors.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          if (active.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 24, color: SettlrColors.textSub),
                    SizedBox(height: 8),
                    Text('No transactions found', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SettlrColors.textMain)),
                    SizedBox(height: 2),
                    Text('Tap Add Expense to log payments in this group.', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                  ],
                ),
              ),
            ),
          ] else ...[
            ...active.map((exp) {
              return GestureDetector(
                onTap: () => _openExpenseDetailsModal(exp),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: Center(
                          child: Text(
                            exp.category.isNotEmpty ? exp.category[0] : 'E',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(exp.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SettlrColors.textMain)),
                            Text('Paid by ${exp.payerName ?? 'Member'} · ${exp.expenseDate}', style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                          ],
                        ),
                      ),
                      Text(
                        '$symbol${(exp.amount / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18, color: Color(0xFFD4D4D4)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSettlementsHistoryCard(String symbol) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SettlrColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settlement History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
                  SizedBox(height: 2),
                  Text('Historical bilateral debt settlements', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SettlrColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openRecordSettlementModal(),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Record', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_settlements.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Center(
                child: Text('No settlement records yet.', style: TextStyle(fontSize: 12, color: SettlrColors.textMuted)),
              ),
            ),
          ] else ...[
            ..._settlements.map((s) {
              final confirmed = s.status == 'CONFIRMED';
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                ),
                child: Row(
                  children: [
                    Icon(
                      confirmed ? Icons.check_circle : Icons.schedule,
                      size: 18,
                      color: confirmed ? SettlrColors.positive : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s.fromUserName} -> ${s.toUserName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SettlrColors.textMain)),
                          Text(confirmed ? 'Confirmed receipt' : 'Recorded claim', style: TextStyle(fontSize: 11, color: confirmed ? SettlrColors.positive : const Color(0xFFD97706))),
                        ],
                      ),
                    ),
                    Text(
                      '$symbol${(s.amount / 100).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityFeedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SettlrColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Audit Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SettlrColors.positiveBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1FAE5)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: SettlrColors.positive),
                    SizedBox(width: 4),
                    Text('Live', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SettlrColors.positive)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_activities.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Center(
                child: Text('No ledger activities recorded yet.', style: TextStyle(fontSize: 12, color: SettlrColors.textMuted)),
              ),
            ),
          ] else ...[
            ..._activities.map((a) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: a.actorName, style: const TextStyle(fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
                          TextSpan(text: ' ${a.summary}', style: const TextStyle(color: SettlrColors.textMain)),
                        ],
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(a.createdAt.isNotEmpty ? a.createdAt : 'Just now', style: const TextStyle(fontSize: 10, color: SettlrColors.textMuted)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyGroupsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/images/logo.png', width: 32, height: 32),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create Your First Ledger',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a group for your apartment, trip, or roommates to start splitting bills with automatic zero-sum debt netting.',
              style: TextStyle(fontSize: 12, color: SettlrColors.textMuted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: SettlrColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openCreateGroupModal,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Create Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE5E5E5)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openJoinGroupModal,
              icon: const Icon(Icons.group_add_outlined, size: 16, color: SettlrColors.textMuted),
              label: const Text('Join with Code', style: TextStyle(color: SettlrColors.textMuted, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Personal Tab View ──────────────────────────────────────────────────────

  Widget _buildPersonalView() {
    final cur = ApiService.currentUser?.defaultCurrency ?? 'INR';
    final symbol = cur == 'INR' ? '₹' : cur;

    final totalSpent = _personalExpenses.fold<int>(0, (sum, e) => sum + e.amount);

    final filtered = _personalExpenses.where((e) {
      if (_personalCategoryFilter == 'ALL') return true;
      return e.category == _personalCategoryFilter;
    }).toList();

    const categories = ['ALL', 'FOOD', 'TRANSPORT', 'HOUSING', 'ENTERTAINMENT', 'SHOPPING', 'GENERAL'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        // Personal Ledger Hero Card
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
              Row(
                children: [
                  const Text('Personal Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: const Text('Private', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SettlrColors.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                'Solitary daily expenses, coffee, transport, and personal purchases kept private from groups.',
                style: TextStyle(fontSize: 12, color: SettlrColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Solitary Spend', style: TextStyle(fontSize: 12, color: SettlrColors.textMuted)),
                  Text(
                    '$symbol${(totalSpent / 100).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SettlrColors.textMain),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Personal History Card
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Personal History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SettlrColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _openAddPersonalExpenseModal,
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Category filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final active = _personalCategoryFilter == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _personalCategoryFilter = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: active ? SettlrColors.primary : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cat == 'ALL' ? 'All' : cat,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : SettlrColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              if (filtered.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 24, color: SettlrColors.textSub),
                        SizedBox(height: 8),
                        Text('No personal entries', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SettlrColors.textMain)),
                        SizedBox(height: 2),
                        Text('Tap Add Expense to log private purchases.', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...filtered.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SettlrColors.textMain)),
                              Text('${e.date} · ${e.category}', style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                            ],
                          ),
                        ),
                        Text(
                          '$symbol${(e.amount / 100).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            await ApiService.deletePersonalExpense(e.id);
                            final updated = await ApiService.getPersonalExpenses();
                            if (mounted) setState(() => _personalExpenses = updated);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline, size: 16, color: SettlrColors.textSub),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Reusable Component Pills & Sheets ────────────────────────────────────────

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabPill({required this.label, required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 4, offset: const Offset(0, 1))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isActive ? SettlrColors.textMain : SettlrColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? SettlrColors.textMain : SettlrColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
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
  bool _isCheckingUpdate = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _updateStatusMessage;
  UpdateInfo? _availableUpdate;

  Future<void> _handleCheckUpdate() async {
    setState(() { _isCheckingUpdate = true; _updateStatusMessage = null; });
    try {
      final info = await UpdateService.checkForUpdate();
      setState(() {
        _isCheckingUpdate = false;
        if (info.hasUpdate) {
          _availableUpdate = info;
          _updateStatusMessage = 'New version ${info.latestVersion} available!';
        } else {
          _availableUpdate = null;
          _updateStatusMessage = 'You are on the latest version (${info.currentVersion})';
        }
      });
    } catch (e) {
      setState(() {
        _isCheckingUpdate = false;
        _updateStatusMessage = 'Could not check: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Future<void> _handleDownloadAndInstall() async {
    if (_availableUpdate?.downloadUrl == null) return;
    setState(() { _isDownloading = true; _downloadProgress = 0.0; _updateStatusMessage = 'Downloading...'; });
    try {
      await UpdateService.downloadAndInstall(
        downloadUrl: _availableUpdate!.downloadUrl!,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = progress;
            final mb = (received / (1024 * 1024)).toStringAsFixed(1);
            final mbT = (total / (1024 * 1024)).toStringAsFixed(1);
            _updateStatusMessage = total > 0 ? 'Downloading: $mb / $mbT MB (${(progress * 100).toInt()}%)' : 'Downloading: $mb MB';
          });
        },
      );
      if (mounted) setState(() { _isDownloading = false; _updateStatusMessage = 'Opening Android installer...'; });
    } catch (e) {
      if (mounted) setState(() { _isDownloading = false; _updateStatusMessage = 'Install failed: $e'; });
    }
  }

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
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFE5E5E5), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: SettlrColors.primary, borderRadius: BorderRadius.circular(20)),
                    child: Center(
                      child: Text(
                        widget.user?.name.isNotEmpty == true ? widget.user!.name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.user?.name ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: SettlrColors.textMain)),
                      Text(widget.user?.email ?? 'Personal settings & profile', style: const TextStyle(color: SettlrColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              IconButton(icon: const Icon(Icons.close, color: SettlrColors.textMuted), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 20),

          // App Updates Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SettlrColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: SettlrColors.border),
                          ),
                          child: const Icon(Icons.system_update_alt_rounded, size: 18, color: SettlrColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('App Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: SettlrColors.textMain)),
                            Text('v${UpdateService.currentVersion}', style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SettlrColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: (_isCheckingUpdate || _isDownloading) ? null : _handleCheckUpdate,
                      child: _isCheckingUpdate
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Check', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                if (_updateStatusMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _updateStatusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _availableUpdate != null ? SettlrColors.positive : SettlrColors.textMuted,
                    ),
                  ),
                ],
                if (_availableUpdate != null) ...[
                  const SizedBox(height: 12),
                  if (_isDownloading)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        color: SettlrColors.positive,
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SettlrColors.positive,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _handleDownloadAndInstall,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text('Download & Install ${_availableUpdate!.latestVersion}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

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
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: SettlrColors.negative),
              title: const Text('Log Out', style: TextStyle(color: SettlrColors.negative, fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () => setState(() => _showConfirmLogout = true),
            ),
        ],
      ),
    );
  }
}
