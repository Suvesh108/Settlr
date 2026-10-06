import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static String _baseUrl = 'http://10.0.2.2:8080/api/v1';
  static String get baseUrl => _baseUrl;

  static String? _token;
  static User? _currentUser;

  static User? get currentUser => _currentUser;
  static String? get token => _token;

  static Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    _baseUrl = prefs.getString('server_base_url') ?? 'http://10.0.2.2:8080/api/v1';
    final rawUser = prefs.getString('user_data');
    if (rawUser != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(rawUser));
      } catch (_) {}
    }
  }

  static Future<void> setServerUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_base_url', _baseUrl);
  }

  static Future<void> saveAuth(User user, String token) async {
    _currentUser = user;
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('user_data', jsonEncode(user.toJson()));
  }

  static Future<void> logout() async {
    _currentUser = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_data');
    await prefs.remove('active_group_id');
  }

  static Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // ── Authentication & Session ───────────────────────────────────────────────

  static Future<User> startSession({
    required String name,
    required String defaultCurrency,
  }) async {
    final email = '${name.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@settlr.local';

    // 1. Try remote backend
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'default_currency': defaultCurrency,
        }),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final resJson = jsonDecode(response.body);
        final user = User.fromJson(resJson['data']);
        if (user.token != null) {
          await saveAuth(user, user.token!);
        }
        return user;
      }
    } catch (_) {}

    // 2. Offline / local-first fallback
    final localUser = User(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      defaultCurrency: defaultCurrency,
      token: 'local_token_${DateTime.now().millisecondsSinceEpoch}',
    );

    await saveAuth(localUser, localUser.token!);

    // Initialize default local group if none exists
    final prefs = await SharedPreferences.getInstance();
    final rawGroups = prefs.getString('local_groups');
    if (rawGroups == null || rawGroups.isEmpty) {
      final defaultGroup = Group(
        id: 'grp_default_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Personal & Friends',
        description: 'Automated bilateral settlement and shared expense ledger.',
        currency: defaultCurrency,
        inviteCode: 'SETTLR-01',
        createdBy: localUser.id,
        ledgerVersion: 1,
        members: [
          GroupMember(
            userId: localUser.id,
            name: localUser.name,
            email: localUser.email,
            role: 'OWNER',
            status: 'ACTIVE',
          ),
        ],
      );
      await prefs.setString('local_groups', jsonEncode([defaultGroup.toJson()]));
    }

    return localUser;
  }

  // ── Groups Management ──────────────────────────────────────────────────────

  static Future<List<Group>> getCachedGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final rawGroups = prefs.getString('local_groups');
    if (rawGroups != null && rawGroups.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawGroups);
        return list.map((g) => Group.fromJson(g)).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<List<Group>> getGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final List<dynamic> list = resJson['data'] ?? [];
        final remoteGroups = list.map((g) => Group.fromJson(g)).toList();
        if (remoteGroups.isNotEmpty) {
          // Cache remotely fetched groups
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'local_groups',
            jsonEncode(remoteGroups.map((g) => g.toJson()).toList()),
          );
          return remoteGroups;
        }
      }
    } catch (_) {}

    return getCachedGroups();
  }

  static Future<Group> createGroup({
    required String name,
    required String description,
    required String currency,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/groups'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'currency': currency,
        }),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final resJson = jsonDecode(response.body);
        return Group.fromJson(resJson['data']);
      }
    } catch (_) {}

    // Offline group creation
    final newGroup = Group(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      currency: currency,
      inviteCode: 'SET-${(1000 + (DateTime.now().millisecond % 9000)).toString()}',
      createdBy: _currentUser?.id ?? 'me',
      ledgerVersion: 1,
      members: [
        if (_currentUser != null)
          GroupMember(
            userId: _currentUser!.id,
            name: _currentUser!.name,
            email: _currentUser!.email,
            role: 'OWNER',
            status: 'ACTIVE',
          )
      ],
    );

    final prefs = await SharedPreferences.getInstance();
    final cached = await getCachedGroups();
    cached.insert(0, newGroup);
    await prefs.setString('local_groups', jsonEncode(cached.map((g) => g.toJson()).toList()));

    return newGroup;
  }

  static Future<String> joinGroup(String inviteCode) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/groups/join'),
        headers: _headers(),
        body: jsonEncode({'invite_code': inviteCode}),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final resJson = jsonDecode(response.body);
        return resJson['data']?['group_id'] ?? '';
      }
    } catch (_) {}

    return 'grp_joined';
  }

  static Future<void> deleteGroup(String groupId) async {
    try {
      await http.delete(
        Uri.parse('$_baseUrl/groups/$groupId'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cached = await getCachedGroups();
    cached.removeWhere((g) => g.id == groupId);
    await prefs.setString('local_groups', jsonEncode(cached.map((g) => g.toJson()).toList()));
  }

  static Future<void> leaveGroup(String groupId) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/groups/$groupId/leave'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cached = await getCachedGroups();
    cached.removeWhere((g) => g.id == groupId);
    await prefs.setString('local_groups', jsonEncode(cached.map((g) => g.toJson()).toList()));
  }

  // ── Expenses Management ────────────────────────────────────────────────────

  static Future<List<Expense>> getCachedExpenses(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_expenses_$groupId');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((e) => Expense.fromJson(e)).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<List<Expense>> getExpenses(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/$groupId/expenses'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final List<dynamic> list = resJson['data'] ?? [];
        final remote = list.map((e) => Expense.fromJson(e)).toList();
        if (remote.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'local_expenses_$groupId',
            jsonEncode(remote.map((e) => e.toJson()).toList()),
          );
          return remote;
        }
      }
    } catch (_) {}

    return getCachedExpenses(groupId);
  }

  static Future<void> addExpense({
    required String groupId,
    required String description,
    required int amount,
    required String category,
    required String splitType,
    required String paidBy,
    required List<Map<String, dynamic>> participants,
  }) async {
    // 1. Try remote
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/groups/$groupId/expenses'),
        headers: _headers(),
        body: jsonEncode({
          'description': description,
          'amount': amount,
          'category': category,
          'paid_by': paidBy,
          'split_type': splitType,
          'participants': participants,
        }),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode < 300) return;
    } catch (_) {}

    // 2. Offline local storage
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_expenses_$groupId');
    List<dynamic> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        list = jsonDecode(raw);
      } catch (_) {}
    }

    final newExpense = {
      'id': 'exp_${DateTime.now().millisecondsSinceEpoch}',
      'group_id': groupId,
      'description': description,
      'amount': amount,
      'category': category,
      'paid_by': paidBy,
      'payer_name': _currentUser?.name ?? 'You',
      'created_by': _currentUser?.id ?? 'me',
      'is_reversed': false,
      'is_reversal': false,
      'currency': 'INR',
      'expense_date': DateTime.now().toIso8601String().split('T')[0],
      'split_type': splitType,
      'created_at': DateTime.now().toIso8601String(),
      'participants': participants.map((p) {
        final share = p['share_amount'] ?? (amount / (participants.isEmpty ? 1 : participants.length)).round();
        return {
          'user_id': p['user_id'],
          'share_amount': share,
          if (p['basis_points'] != null) 'basis_points': p['basis_points'],
          if (p['shares'] != null) 'shares': p['shares'],
        };
      }).toList(),
    };
    list.insert(0, newExpense);
    await prefs.setString('local_expenses_$groupId', jsonEncode(list));

    // Also add to local activity feed
    await _addLocalActivity(
      groupId: groupId,
      action: 'EXPENSE_CREATE',
      summary: 'added "$description" for ₹${(amount / 100).toStringAsFixed(2)}',
    );
  }

  static Future<void> reverseExpense(String groupId, String expenseId) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/groups/$groupId/expenses/$expenseId/reverse'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));
      return;
    } catch (_) {}

    // Offline reversal
    final prefs = await SharedPreferences.getInstance();
    final expenses = await getCachedExpenses(groupId);
    final idx = expenses.indexWhere((e) => e.id == expenseId);
    if (idx != -1) {
      final old = expenses[idx];
      expenses[idx] = Expense(
        id: old.id,
        groupId: old.groupId,
        description: old.description,
        amount: old.amount,
        category: old.category,
        paidBy: old.paidBy,
        payerName: old.payerName,
        createdBy: old.createdBy,
        isReversed: true,
        isReversal: old.isReversal,
        reversesExpenseId: old.reversesExpenseId,
        currency: old.currency,
        expenseDate: old.expenseDate,
        splitType: old.splitType,
        createdAt: old.createdAt,
        shares: old.shares,
      );
      await prefs.setString('local_expenses_$groupId', jsonEncode(expenses.map((e) => e.toJson()).toList()));
    }
  }

  // ── Balances & Debt Matrix ─────────────────────────────────────────────────

  static Future<List<UserBalance>> getBalances(String groupId, Group? group) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/$groupId/balances'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final List<dynamic> list = resJson['balances'] ?? [];
        return list.map((b) => UserBalance.fromJson(b)).toList();
      }
    } catch (_) {}

    // Offline computation of balances
    final expenses = await getCachedExpenses(groupId);
    final settlements = await getCachedSettlements(groupId);
    final members = group?.members ?? [];

    final Map<String, int> netMap = {};
    for (final m in members) {
      netMap[m.userId] = 0;
    }
    if (_currentUser != null && !netMap.containsKey(_currentUser!.id)) {
      netMap[_currentUser!.id] = 0;
    }

    // Process active expenses
    for (final exp in expenses) {
      if (exp.isReversed || exp.isReversal) continue;
      // Payer paid the total
      netMap[exp.paidBy] = (netMap[exp.paidBy] ?? 0) + exp.amount;
      // Subtract each participant's share
      for (final s in exp.shares) {
        netMap[s.userId] = (netMap[s.userId] ?? 0) - s.shareAmount;
      }
    }

    // Process confirmed settlements
    for (final s in settlements) {
      if (s.status == 'CONFIRMED') {
        netMap[s.fromUser] = (netMap[s.fromUser] ?? 0) + s.amount;
        netMap[s.toUser] = (netMap[s.toUser] ?? 0) - s.amount;
      }
    }

    final List<UserBalance> result = [];
    for (final m in members) {
      result.add(UserBalance(
        userId: m.userId,
        name: m.name,
        email: m.email,
        netBalance: netMap[m.userId] ?? 0,
      ));
    }
    return result;
  }

  static Future<List<PairwiseDebt>> getPairwiseDebts(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/$groupId/balances/pairwise'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final List<dynamic> list = resJson['pairwise'] ?? [];
        return list.map((p) => PairwiseDebt.fromJson(p)).toList();
      }
    } catch (_) {}

    return [];
  }

  static Future<List<RecommendedTransfer>> getRecommendedSettlements(
    String groupId,
    List<UserBalance> balances,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/$groupId/settlements/recommended'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final List<dynamic> list = resJson['transfers'] ?? [];
        return list.map((t) => RecommendedTransfer.fromJson(t)).toList();
      }
    } catch (_) {}

    // Offline greedy settlement computation
    return _computeGreedySettlements(balances);
  }

  static List<RecommendedTransfer> _computeGreedySettlements(List<UserBalance> balances) {
    final List<RecommendedTransfer> transfers = [];

    // Separate debtors and creditors
    final debtors = <Map<String, dynamic>>[];
    final creditors = <Map<String, dynamic>>[];

    for (final b in balances) {
      if (b.netBalance < 0) {
        debtors.add({'userId': b.userId, 'name': b.name, 'amount': -b.netBalance});
      } else if (b.netBalance > 0) {
        creditors.add({'userId': b.userId, 'name': b.name, 'amount': b.netBalance});
      }
    }

    debtors.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));
    creditors.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));

    int dIdx = 0;
    int cIdx = 0;

    while (dIdx < debtors.length && cIdx < creditors.length) {
      final d = debtors[dIdx];
      final c = creditors[cIdx];

      final int settleAmount = (d['amount'] as int) < (c['amount'] as int)
          ? (d['amount'] as int)
          : (c['amount'] as int);

      if (settleAmount > 0) {
        transfers.add(RecommendedTransfer(
          fromUser: d['userId'],
          fromUserName: d['name'],
          toUser: c['userId'],
          toUserName: c['name'],
          amount: settleAmount,
        ));
      }

      d['amount'] = (d['amount'] as int) - settleAmount;
      c['amount'] = (c['amount'] as int) - settleAmount;

      if ((d['amount'] as int) <= 0) dIdx++;
      if ((c['amount'] as int) <= 0) cIdx++;
    }

    return transfers;
  }

  // ── Settlements Management ────────────────────────────────────────────────

  static Future<List<Settlement>> getCachedSettlements(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_settlements_$groupId');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((s) => Settlement.fromJson(s)).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<List<Settlement>> getSettlements(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/$groupId/settlements'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final List<dynamic> list = resJson['data'] ?? [];
        final remote = list.map((s) => Settlement.fromJson(s)).toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'local_settlements_$groupId',
          jsonEncode(remote.map((s) => s.toJson()).toList()),
        );
        return remote;
      }
    } catch (_) {}

    return getCachedSettlements(groupId);
  }

  static Future<void> recordSettlement({
    required String groupId,
    required String toUser,
    required String toUserName,
    required int amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/groups/$groupId/settlements'),
        headers: _headers(),
        body: jsonEncode({
          'to_user': toUser,
          'amount': amount,
        }),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode < 300) return;
    } catch (_) {}

    // Offline recording
    final prefs = await SharedPreferences.getInstance();
    final list = await getCachedSettlements(groupId);
    final newSettlement = Settlement(
      id: 'stl_${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      fromUser: _currentUser?.id ?? 'me',
      fromUserName: _currentUser?.name ?? 'You',
      toUser: toUser,
      toUserName: toUserName,
      amount: amount,
      status: 'PAYMENT_RECORDED',
      recordedBy: _currentUser?.id ?? 'me',
      createdAt: DateTime.now().toIso8601String(),
    );
    list.insert(0, newSettlement);
    await prefs.setString(
      'local_settlements_$groupId',
      jsonEncode(list.map((s) => s.toJson()).toList()),
    );

    await _addLocalActivity(
      groupId: groupId,
      action: 'SETTLEMENT_RECORD',
      summary: 'recorded payment of ₹${(amount / 100).toStringAsFixed(2)} to $toUserName',
    );
  }

  static Future<void> confirmSettlement(String groupId, String settlementId) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/groups/$groupId/settlements/$settlementId/confirm'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));
      return;
    } catch (_) {}

    // Offline confirmation
    final prefs = await SharedPreferences.getInstance();
    final list = await getCachedSettlements(groupId);
    final idx = list.indexWhere((s) => s.id == settlementId);
    if (idx != -1) {
      final old = list[idx];
      list[idx] = Settlement(
        id: old.id,
        groupId: old.groupId,
        fromUser: old.fromUser,
        fromUserName: old.fromUserName,
        toUser: old.toUser,
        toUserName: old.toUserName,
        amount: old.amount,
        status: 'CONFIRMED',
        recordedBy: old.recordedBy,
        confirmedBy: _currentUser?.id ?? 'me',
        createdAt: old.createdAt,
        confirmedAt: DateTime.now().toIso8601String(),
      );
      await prefs.setString(
        'local_settlements_$groupId',
        jsonEncode(list.map((s) => s.toJson()).toList()),
      );
    }
  }

  // ── Activity Log ───────────────────────────────────────────────────────────

  static Future<List<ActivityItem>> getActivity(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/$groupId/activity'),
        headers: _headers(),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final List<dynamic> list = resJson['data'] ?? [];
        return list.map((a) => ActivityItem.fromJson(a)).toList();
      }
    } catch (_) {}

    // Offline activities
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_activity_$groupId');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((a) => ActivityItem.fromJson(a)).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> _addLocalActivity({
    required String groupId,
    required String action,
    required String summary,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_activity_$groupId');
    List<dynamic> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        list = jsonDecode(raw);
      } catch (_) {}
    }
    list.insert(0, {
      'id': 'act_${DateTime.now().millisecondsSinceEpoch}',
      'group_id': groupId,
      'actor_id': _currentUser?.id ?? 'me',
      'actor_name': _currentUser?.name ?? 'You',
      'action': action,
      'summary': summary,
      'created_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString('local_activity_$groupId', jsonEncode(list));
  }

  // ── Personal Expenses (Solitary Ledger) ────────────────────────────────────

  static Future<List<PersonalExpense>> getPersonalExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _currentUser?.id ?? 'default';
    final raw = prefs.getString('personal_expenses_$uid');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((e) => PersonalExpense.fromJson(e)).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<PersonalExpense> addPersonalExpense({
    required String description,
    required int amount,
    required String category,
    required String date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _currentUser?.id ?? 'default';
    final expenses = await getPersonalExpenses();

    final newExp = PersonalExpense(
      id: 'pers_${DateTime.now().millisecondsSinceEpoch}',
      description: description,
      amount: amount,
      category: category,
      date: date,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    expenses.insert(0, newExp);
    await prefs.setString('personal_expenses_$uid', jsonEncode(expenses.map((e) => e.toJson()).toList()));
    return newExp;
  }

  static Future<void> deletePersonalExpense(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _currentUser?.id ?? 'default';
    final expenses = await getPersonalExpenses();
    expenses.removeWhere((e) => e.id == id);
    await prefs.setString('personal_expenses_$uid', jsonEncode(expenses.map((e) => e.toJson()).toList()));
  }
}
