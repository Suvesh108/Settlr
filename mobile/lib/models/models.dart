class User {
  final String id;
  final String name;
  final String email;
  final String defaultCurrency;
  final String? token;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.defaultCurrency,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      defaultCurrency: json['default_currency'] ?? 'INR',
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'default_currency': defaultCurrency,
      if (token != null) 'token': token,
    };
  }
}

class Group {
  final String id;
  final String name;
  final String description;
  final String currency;
  final String inviteCode;
  final String createdBy;
  final List<GroupMember> members;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.currency,
    required this.inviteCode,
    required this.createdBy,
    this.members = const [],
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    final membersList = (json['members'] as List<dynamic>?)
            ?.map((m) => GroupMember.fromJson(m))
            .toList() ??
        [];
    return Group(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      currency: json['currency'] ?? 'INR',
      inviteCode: json['invite_code'] ?? '',
      createdBy: json['created_by'] ?? '',
      members: membersList,
    );
  }
}

class GroupMember {
  final String userId;
  final String name;
  final String email;
  final String role;
  final String status;

  GroupMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'MEMBER',
      status: json['status'] ?? 'ACTIVE',
    );
  }
}

class Expense {
  final String id;
  final String groupId;
  final String description;
  final int amount; // in minor units (paise)
  final String category;
  final String paidBy;
  final String createdBy;
  final bool isReversed;
  final String createdAt;
  final List<ExpenseShare> shares;

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.category,
    required this.paidBy,
    required this.createdBy,
    required this.isReversed,
    required this.createdAt,
    this.shares = const [],
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final sList = (json['shares'] as List<dynamic>?)
            ?.map((s) => ExpenseShare.fromJson(s))
            .toList() ??
        [];
    return Expense(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      description: json['description'] ?? '',
      amount: json['amount'] ?? 0,
      category: json['category'] ?? 'GENERAL',
      paidBy: json['paid_by'] ?? '',
      createdBy: json['created_by'] ?? '',
      isReversed: json['is_reversed'] ?? false,
      createdAt: json['created_at'] ?? '',
      shares: sList,
    );
  }
}

class ExpenseShare {
  final String userId;
  final int shareAmount;

  ExpenseShare({
    required this.userId,
    required this.shareAmount,
  });

  factory ExpenseShare.fromJson(Map<String, dynamic> json) {
    return ExpenseShare(
      userId: json['user_id'] ?? '',
      shareAmount: json['share_amount'] ?? 0,
    );
  }
}

class PairwiseDebt {
  final String userA;
  final String userB;
  final int netDebt; // positive: user_b owes user_a

  PairwiseDebt({
    required this.userA,
    required this.userB,
    required this.netDebt,
  });

  factory PairwiseDebt.fromJson(Map<String, dynamic> json) {
    return PairwiseDebt(
      userA: json['user_a'] ?? '',
      userB: json['user_b'] ?? '',
      netDebt: json['net_debt'] ?? 0,
    );
  }
}

class RecommendedTransfer {
  final String fromUser;
  final String toUser;
  final int amount;

  RecommendedTransfer({
    required this.fromUser,
    required this.toUser,
    required this.amount,
  });

  factory RecommendedTransfer.fromJson(Map<String, dynamic> json) {
    return RecommendedTransfer(
      fromUser: json['from_user'] ?? '',
      toUser: json['to_user'] ?? '',
      amount: json['amount'] ?? 0,
    );
  }
}

class PersonalExpense {
  final String id;
  final String description;
  final int amount; // paise
  final String category;
  final String date;
  final int createdAt;

  PersonalExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.createdAt,
  });

  factory PersonalExpense.fromJson(Map<String, dynamic> json) {
    return PersonalExpense(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      amount: json['amount'] ?? 0,
      category: json['category'] ?? 'GENERAL',
      date: json['date'] ?? '',
      createdAt: json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'date': date,
      'createdAt': createdAt,
    };
  }
}
