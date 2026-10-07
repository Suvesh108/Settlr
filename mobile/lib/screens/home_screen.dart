import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../widgets/motion_wrapper.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/island_header.dart';
import '../widgets/haptic_dock.dart';
import '../widgets/net_standing_card.dart';
import '../widgets/bilateral_debt_matrix.dart';
import '../widgets/transaction_table.dart';
import '../widgets/personal_stream.dart';
import '../widgets/activity_feed.dart';
import '../widgets/smart_spend_popup.dart';
import '../modals/add_expense_modal.dart';
import '../modals/expense_details_modal.dart';
import '../modals/record_settlement_modal.dart';
import '../modals/pairwise_modal.dart';
import '../modals/group_settings_modal.dart';
import '../modals/create_group_modal.dart';
import '../modals/join_group_modal.dart';
import '../modals/add_personal_expense_modal.dart';
import '../modals/profile_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0; // 0: Groups, 1: Personal
  String _groupSubTab = 'overview'; // 'overview' | 'expenses' | 'settlements' | 'activity'

  List<Group> _groups = [];
  Group? _activeGroup;

  List<Expense> _expenses = [];
  List<UserBalance> _balances = [];
  List<PairwiseDebt> _pairwise = [];
  List<RecommendedTransfer> _transfers = [];
  List<Settlement> _settlements = [];
  List<ActivityItem> _activities = [];
  List<PersonalExpense> _personalExpenses = [];

  bool _isFirstLoad = false;
  bool _isRefreshing = false;

  final GlobalKey<_HomeScreenState> _scaffoldKey = GlobalKey<_HomeScreenState>();

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Instant Cache-First Load
    final cachedGroups = await ApiService.getCachedGroups();
    final cachedPersonal = await ApiService.getPersonalExpenses();
    final savedGroupId = await ApiService.getActiveGroupId();

    if (!mounted) return;

    if (cachedGroups.isEmpty) {
      setState(() {
        _groups = [];
        _personalExpenses = cachedPersonal;
        _isFirstLoad = false;
      });
    } else {
      final active = (savedGroupId != null && cachedGroups.any((g) => g.id == savedGroupId))
          ? cachedGroups.firstWhere((g) => g.id == savedGroupId)
          : cachedGroups.first;

      final cachedExp = await ApiService.getCachedExpenses(active.id);
      final cachedStl = await ApiService.getCachedSettlements(active.id);
      final cachedAct = await ApiService.getCachedActivity(active.id);

      // Compute initial balances & debts from cache
      final localBals = await ApiService.getBalances(active.id, active);
      final localDebts = await ApiService.getPairwiseDebts(active.id, active);
      final localTransfers = await ApiService.getRecommendedSettlements(active.id, localBals);

      if (mounted) {
        setState(() {
          _groups = cachedGroups;
          _activeGroup = active;
          _personalExpenses = cachedPersonal;
          _expenses = cachedExp;
          _settlements = cachedStl;
          _activities = cachedAct;
          _balances = localBals;
          _pairwise = localDebts;
          _transfers = localTransfers;
          _isFirstLoad = false;
        });
      }
    }

    // 2. Silent Background Server Sync
    _syncServerData(isUserInitiated: false);
  }

  Future<void> _syncServerData({bool isUserInitiated = false}) async {
    if (isUserInitiated && mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      final remoteGroups = await ApiService.getGroups();
      final personal = await ApiService.getPersonalExpenses();
      final savedGroupId = await ApiService.getActiveGroupId();

      if (!mounted) return;
      setState(() {
        _groups = remoteGroups;
        _personalExpenses = personal;
        if (remoteGroups.isNotEmpty) {
          if (_activeGroup == null) {
            _activeGroup = (savedGroupId != null && remoteGroups.any((g) => g.id == savedGroupId))
                ? remoteGroups.firstWhere((g) => g.id == savedGroupId)
                : remoteGroups.first;
          } else {
            _activeGroup = remoteGroups.firstWhere(
              (g) => g.id == _activeGroup!.id,
              orElse: () => remoteGroups.first,
            );
          }
        }
        _isFirstLoad = false;
      });

      if (_activeGroup != null) {
        await _fetchActiveGroupDetails(_activeGroup!.id);
      }
    } catch (_) {
      if (mounted) setState(() => _isFirstLoad = false);
    } finally {
      if (isUserInitiated && mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _fetchActiveGroupDetails(String groupId) async {
    try {
      final results = await Future.wait([
        ApiService.getExpenses(groupId),
        ApiService.getBalances(groupId, _activeGroup),
        ApiService.getPairwiseDebts(groupId, _activeGroup),
        ApiService.getSettlements(groupId),
        ApiService.getActivity(groupId),
      ]);

      final exp = (results[0] as List).cast<Expense>();
      final bals = (results[1] as List).cast<UserBalance>();
      final debts = (results[2] as List).cast<PairwiseDebt>();
      final stls = (results[3] as List).cast<Settlement>();
      final acts = (results[4] as List).cast<ActivityItem>();

      final trs = await ApiService.getRecommendedSettlements(groupId, bals);

      if (!mounted) return;
      setState(() {
        _expenses = exp;
        _balances = bals;
        _pairwise = debts;
        _settlements = stls;
        _activities = acts;
        _transfers = trs;
      });
    } catch (_) {}
  }

  Future<void> _handleSwitchGroup(Group g) async {
    if (_activeGroup?.id == g.id) return;
    setState(() => _activeGroup = g);
    await ApiService.setActiveGroupId(g.id);

    // Instant cache read for new group
    final cachedExp = await ApiService.getCachedExpenses(g.id);
    final cachedStl = await ApiService.getCachedSettlements(g.id);
    final cachedAct = await ApiService.getCachedActivity(g.id);
    final localBals = await ApiService.getBalances(g.id, g);
    final localDebts = await ApiService.getPairwiseDebts(g.id, g);
    final localTransfers = await ApiService.getRecommendedSettlements(g.id, localBals);

    if (mounted) {
      setState(() {
        _expenses = cachedExp;
        _settlements = cachedStl;
        _activities = cachedAct;
        _balances = localBals;
        _pairwise = localDebts;
        _transfers = localTransfers;
      });
    }

    _fetchActiveGroupDetails(g.id);
  }

  // ── Modal Triggers ──────────────────────────────────────────────────────────

  void _openAddExpenseModal() {
    if (_activeGroup == null) {
      _openCreateGroupModal();
      return;
    }
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
        onGroupChanged: () => _syncServerData(),
      ),
    );
  }

  void _openCreateGroupModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateGroupModal(onGroupCreated: () => _syncServerData()),
    );
  }

  void _openJoinGroupModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JoinGroupModal(onGroupJoined: () => _syncServerData()),
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
    ProfileModal.show(
      context,
      onProfileUpdated: () => _syncServerData(),
    );
  }

  Future<void> _handleConfirmSettlement(String settlementId) async {
    if (_activeGroup == null) return;
    try {
      await ApiService.confirmSettlement(_activeGroup!.id, settlementId);
      ConfettiOverlayController.instance.blast();
      _fetchActiveGroupDetails(_activeGroup!.id);
    } catch (_) {}
  }

  Future<void> _handleDeletePersonalExpense(String id) async {
    await ApiService.deletePersonalExpense(id);
    final personal = await ApiService.getPersonalExpenses();
    if (mounted) setState(() => _personalExpenses = personal);
  }

  Future<void> _handleReverseExpense(Expense exp) async {
    if (_activeGroup == null) return;
    try {
      await ApiService.reverseExpense(_activeGroup!.id, exp.id);
      _fetchActiveGroupDetails(_activeGroup!.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ApiService.currentUser?.id ?? '';
    final userName = ApiService.currentUser?.name ?? 'User';
    final currentCurrency = _activeGroup?.currency ?? ApiService.currentUser?.defaultCurrency ?? 'INR';

    final totalSpending = _expenses
        .where((e) => !e.is_reversed && !e.is_reversal)
        .fold<double>(0.0, (sum, e) => sum + (e.amount / 100));

    return ConfettiOverlay(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: SettlrColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Island Header (Brand, Animated Mode Segment, Group Switcher, Profile Pill)
              IslandHeader(
                currentMode: _currentTab,
                onModeChanged: (mode) {
                  setState(() => _currentTab = mode);
                },
                groups: _groups,
                activeGroup: _activeGroup,
                onSelectGroup: _handleSwitchGroup,
                onCreateGroup: _openCreateGroupModal,
                onJoinGroup: _openJoinGroupModal,
                onOpenProfile: _openProfileModal,
                userName: userName,
                currentUserId: currentUserId,
              ),

              // 2. Main Content Area with fluid AnimatedSwitcher
              Expanded(
                child: RefreshIndicator(
                  color: SettlrColors.primary,
                  onRefresh: () => _syncServerData(isUserInitiated: true),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: SettlrCurves.spring,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _currentTab == 1
                          ? KeyedSubtree(
                              key: const ValueKey('personal-stream-tab'),
                              child: PersonalStream(
                                expenses: _personalExpenses,
                                currency: currentCurrency,
                                onAddExpense: _openAddPersonalExpenseModal,
                                onDeleteExpense: _handleDeletePersonalExpense,
                              ),
                            )
                          : _groups.isEmpty
                              ? KeyedSubtree(
                                  key: const ValueKey('empty-groups-tab'),
                                  child: _buildEmptyGroupsState(),
                                )
                              : _activeGroup == null
                                  ? const KeyedSubtree(
                                      key: ValueKey('loading-tab'),
                                      child: Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(40),
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    )
                                  : KeyedSubtree(
                                      key: ValueKey('group-subtab-$_groupSubTab-${_activeGroup!.id}'),
                                      child: _buildGroupSubTabView(
                                        totalSpending: totalSpending,
                                        currentUserId: currentUserId,
                                      ),
                                    ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Floating Bottom Navigation Dock (when in Groups mode and groups exist)
        bottomNavigationBar: (_currentTab == 0 && _groups.isNotEmpty)
            ? HapticDock(
                activeTab: _groupSubTab,
                onTabChanged: (tab) => setState(() => _groupSubTab = tab),
                onAddExpense: _openAddExpenseModal,
              )
            : null,
      ),
    );
  }

  Widget _buildGroupSubTabView({
    required double totalSpending,
    required String currentUserId,
  }) {
    if (_activeGroup == null) return const SizedBox.shrink();

    switch (_groupSubTab) {
      case 'overview':
        return Column(
          children: [
            NetStandingCard(
              group: _activeGroup!,
              balances: _balances,
              totalSpending: totalSpending,
              currentUserId: currentUserId,
              onAddExpense: _openAddExpenseModal,
              onRecordSettlement: () => _openRecordSettlementModal(),
              onOpenSettings: _openGroupSettingsModal,
            ),
            const SizedBox(height: 14),
            BilateralDebtMatrix(
              groupId: _activeGroup!.id,
              currency: _activeGroup!.currency,
              creatorId: _activeGroup!.created_by,
              currentUserId: currentUserId,
              balances: _balances,
              transfers: _transfers,
              settlements: _settlements,
              onPayTransfer: (t) {
                _openRecordSettlementModal(
                  toUserId: t.to_user,
                  amountPaise: t.amount,
                );
              },
              onMemberTap: (m) {
                _openPairwiseModal(m.user_id, m.name);
              },
              onConfirmSettlement: _handleConfirmSettlement,
            ),
          ],
        );

      case 'expenses':
        return TransactionTable(
          groupId: _activeGroup!.id,
          currency: _activeGroup!.currency,
          expenses: _expenses,
          currentUserId: currentUserId,
          onSelectExpense: _openExpenseDetailsModal,
          onReverseExpense: _handleReverseExpense,
        );

      case 'settlements':
        return BilateralDebtMatrix(
          groupId: _activeGroup!.id,
          currency: _activeGroup!.currency,
          creatorId: _activeGroup!.created_by,
          currentUserId: currentUserId,
          balances: _balances,
          transfers: _transfers,
          settlements: _settlements,
          onPayTransfer: (t) {
            _openRecordSettlementModal(
              toUserId: t.to_user,
              amountPaise: t.amount,
            );
          },
          onMemberTap: (m) {
            _openPairwiseModal(m.user_id, m.name);
          },
          onConfirmSettlement: _handleConfirmSettlement,
        );

      case 'activity':
        return ActivityFeed(activity: _activities);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmptyGroupsState() {
    return SettlrPanel(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1F000000)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create Your First Ledger',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: SettlrColors.textMain,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a group for your apartment, trip, or roommates to start splitting bills with automatic zero-sum debt netting.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BouncyPress(
                onTap: _openCreateGroupModal,
                scaleDown: 0.94,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: SettlrColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Create Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              BouncyPress(
                onTap: _openJoinGroupModal,
                scaleDown: 0.94,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1F000000)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.group_add_outlined, size: 16, color: SettlrColors.textMain),
                      SizedBox(width: 6),
                      Text('Join with Code', style: TextStyle(color: SettlrColors.textMain, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
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
