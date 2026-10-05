import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  // Point to local Go server IP or standard emulator loopback 10.0.2.2
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  static String? _token;
  static User? _currentUser;

  static User? get currentUser => _currentUser;
  static String? get token => _token;

  static Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    final rawUser = prefs.getString('user_data');
    if (rawUser != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(rawUser));
      } catch (_) {}
    }
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
    final email = '${name.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@local';
    final response = await http.post(
      Uri.parse('$baseUrl/auth/session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'default_currency': defaultCurrency,
      }),
    );

    final resJson = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final user = User.fromJson(resJson['data']);
      if (user.token != null) {
        await saveAuth(user, user.token!);
      }
      return user;
    } else {
      throw Exception(resJson['error']?['message'] ?? 'Failed to initialize session');
    }
  }

  static Future<List<Group>> getGroups() async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );

    final resJson = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List<dynamic> list = resJson['data'] ?? [];
      return list.map((g) => Group.fromJson(g)).toList();
    }
    return [];
  }

  static Future<Group> createGroup({
    required String name,
    required String description,
    required String currency,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'currency': currency,
      }),
    );

    final resJson = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Group.fromJson(resJson['data']);
    } else {
      throw Exception(resJson['error']?['message'] ?? 'Failed to create group');
    }
  }

  static Future<String> joinGroup(String inviteCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups/join'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'invite_code': inviteCode}),
    );

    final resJson = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return resJson['data']?['group_id'] ?? '';
    } else {
      throw Exception(resJson['error']?['message'] ?? 'Invalid invite code');
    }
  }

  static Future<List<Expense>> getExpenses(String groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups/$groupId/expenses'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );

    final resJson = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List<dynamic> list = resJson['data'] ?? [];
      return list.map((e) => Expense.fromJson(e)).toList();
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
    final response = await http.post(
      Uri.parse('$baseUrl/groups/$groupId/expenses'),
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
    );

    if (response.statusCode >= 300) {
      final resJson = jsonDecode(response.body);
      throw Exception(resJson['error']?['message'] ?? 'Failed to record expense');
    }
  }
}
