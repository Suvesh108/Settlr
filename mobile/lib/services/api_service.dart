import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  // Configurable base URL, defaults to local emulator or LAN IP
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

  static Future<User> startSession({
    required String name,
    required String defaultCurrency,
  }) async {
    final email = '${name.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@settlr.local';

    // 1. Try remote backend with short timeout
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
    } catch (_) {
      // Remote server unreachable or offline - fall through gracefully to local-first mode
    }

    // 2. Local-first offline mode (instant durability on physical device)
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
        description: 'Default local ledger',
        currency: defaultCurrency,
        inviteCode: 'SETTLR-01',
        createdBy: localUser.id,
        members: [
          GroupMember(
            userId: localUser.id,
            name: localUser.name,
            email: localUser.email,
            role: 'ADMIN',
            status: 'ACTIVE',
          ),
        ],
      );
      final List<Map<String, dynamic>> groupsList = [
        {
          'id': defaultGroup.id,
          'name': defaultGroup.name,
          'description': defaultGroup.description,
          'currency': defaultGroup.currency,
          'invite_code': defaultGroup.inviteCode,
          'created_by': defaultGroup.createdBy,
          'members': [
            {
              'user_id': localUser.id,
              'name': localUser.name,
              'email': localUser.email,
              'role': 'ADMIN',
              'status': 'ACTIVE',
            }
          ]
        }
      ];
      await prefs.setString('local_groups', jsonEncode(groupsList));
    }

    return localUser;
  }

  static Future<List<Group>> getGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final List<dynamic> list = resJson['data'] ?? [];
        final remoteGroups = list.map((g) => Group.fromJson(g)).toList();
        if (remoteGroups.isNotEmpty) return remoteGroups;
      }
    } catch (_) {}

    // Fall back to local groups
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

  static Future<Group> createGroup({
    required String name,
    required String description,
    required String currency,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/groups'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
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

    // Local-first group creation
    final newGroup = Group(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      currency: currency,
      inviteCode: 'SET-${(1000 + DateTime.now().millisecond).toString()}',
      createdBy: _currentUser?.id ?? 'me',
      members: [
        if (_currentUser != null)
          GroupMember(
            userId: _currentUser!.id,
            name: _currentUser!.name,
            email: _currentUser!.email,
            role: 'ADMIN',
            status: 'ACTIVE',
          )
      ],
    );

    final prefs = await SharedPreferences.getInstance();
    final rawGroups = prefs.getString('local_groups');
    List<dynamic> list = [];
    if (rawGroups != null && rawGroups.isNotEmpty) {
      try {
        list = jsonDecode(rawGroups);
      } catch (_) {}
    }
    list.add({
      'id': newGroup.id,
      'name': newGroup.name,
      'description': newGroup.description,
      'currency': newGroup.currency,
      'invite_code': newGroup.inviteCode,
      'created_by': newGroup.createdBy,
      'members': newGroup.members.map((m) => {
        'user_id': m.userId,
        'name': m.name,
        'email': m.email,
        'role': m.role,
        'status': m.status,
      }).toList(),
    });
    await prefs.setString('local_groups', jsonEncode(list));

    return newGroup;
  }

  static Future<String> joinGroup(String inviteCode) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/groups/join'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'invite_code': inviteCode}),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final resJson = jsonDecode(response.body);
        return resJson['data']?['group_id'] ?? '';
      }
    } catch (_) {}

    return 'grp_joined';
  }

  static Future<List<Expense>> getExpenses(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/$groupId/expenses'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final List<dynamic> list = resJson['data'] ?? [];
        final remote = list.map((e) => Expense.fromJson(e)).toList();
        if (remote.isNotEmpty) return remote;
      }
    } catch (_) {}

    // Fall back to local expenses
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

  static Future<void> addExpense({
    required String groupId,
    required String description,
    required int amount,
    required String category,
    required String splitType,
    required List<String> participantIds,
  }) async {
    // Try remote
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/groups/$groupId/expenses'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'description': description,
          'amount': amount,
          'category': category,
          'paid_by': _currentUser?.id,
          'split_type': splitType,
          'participant_ids': participantIds,
        }),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode < 300) return;
    } catch (_) {}

    // Local storage
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
      'paid_by': _currentUser?.id ?? 'me',
      'created_by': _currentUser?.id ?? 'me',
      'is_reversed': false,
      'created_at': DateTime.now().toIso8601String(),
      'shares': participantIds.map((p) => {
        'user_id': p,
        'share_amount': (amount / (participantIds.isEmpty ? 1 : participantIds.length)).round(),
      }).toList(),
    };
    list.insert(0, newExpense);
    await prefs.setString('local_expenses_$groupId', jsonEncode(list));
  }
}
