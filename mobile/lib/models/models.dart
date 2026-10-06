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

class GroupMember {
  final String userId;
  final String name;
  final String email;
  final String role; // 'OWNER' | 'ADMIN' | 'MEMBER'
  final String status; // 'ACTIVE' | 'LEFT' | 'REMOVED'

  GroupMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] ?? json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'MEMBER',
      status: json['status'] ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
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
  final int ledgerVersion;
  final List<GroupMember> members;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.currency,
    required this.inviteCode,
    required this.createdBy,
    this.ledgerVersion = 1,
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
      inviteCode: json['invite_code'] ?? json['inviteCode'] ?? '',
      createdBy: json['created_by'] ?? json['createdBy'] ?? '',
      ledgerVersion: json['ledger_version'] ?? json['ledgerVersion'] ?? 1,
      members: membersList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'currency': currency,
      'invite_code': inviteCode,
      'created_by': createdBy,
      'ledger_version': ledgerVersion,
      'members': members.map((m) => m.toJson()).toList(),
    };
  }
}

class ExpenseShare {
  final String userId;
  final int shareAmount; // in paise
  final int? basisPoints;
  final int? shares;

  ExpenseShare({
    required this.userId,
    required this.shareAmount,
    this.basisPoints,
    this.shares,
  });

  factory ExpenseShare.fromJson(Map<String, dynamic> json) {
    return ExpenseShare(
      userId: json['user_id'] ?? json['userId'] ?? '',
      shareAmount: json['share_amount'] ?? json['shareAmount'] ?? 0,
      basisPoints: json['basis_points'] ?? json['basisPoints'],
      shares: json['shares'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'share_amount': shareAmount,
      if (basisPoints != null) 'basis_points': basisPoints,
      if (shares != null) 'shares': shares,
    };
  }
}

class Expense {
  final String id;
  final String groupId;
  final String description;
  final int amount; // in paise
  final String category;
  final String paidBy;
  final String? payerName;
  final String createdBy;
  final bool isReversed;
  final bool isReversal;
  final String? reversesExpenseId;
  final String currency;
  final String expenseDate;
  final String splitType; // 'EQUAL' | 'EXACT' | 'PERCENTAGE' | 'SHARES'
  final String createdAt;
  final List<ExpenseShare> shares;

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.category,
    required this.paidBy,
    this.payerName,
    required this.createdBy,
    this.isReversed = false,
    this.isReversal = false,
    this.reversesExpenseId,
    this.currency = 'INR',
    required this.expenseDate,
    this.splitType = 'EQUAL',
    required this.createdAt,
    this.shares = const [],
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final sList = (json['shares'] as List<dynamic>? ??
            json['participants'] as List<dynamic>?)
            ?.map((s) => ExpenseShare.fromJson(s))
            .toList() ??
        [];
    return Expense(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? json['groupId'] ?? '',
      description: json['description'] ?? '',
      amount: json['amount'] ?? 0,
      category: json['category'] ?? 'GENERAL',
      paidBy: json['paid_by'] ?? json['paidBy'] ?? '',
      payerName: json['payer_name'] ?? json['payerName'],
      createdBy: json['created_by'] ?? json['createdBy'] ?? '',
      isReversed: json['is_reversed'] ?? json['isReversed'] ?? false,
      isReversal: json['is_reversal'] ?? json['isReversal'] ?? false,
      reversesExpenseId: json['reverses_expense_id'] ?? json['reversesExpenseId'],
      currency: json['currency'] ?? 'INR',
      expenseDate: json['expense_date'] ?? json['expenseDate'] ?? json['created_at'] ?? '',
      splitType: json['split_type'] ?? json['splitType'] ?? 'EQUAL',
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      shares: sList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'description': description,
      'amount': amount,
      'category': category,
      'paid_by': paidBy,
      if (payerName != null) 'payer_name': payerName,
      'created_by': createdBy,
      'is_reversed': isReversed,
      'is_reversal': isReversal,
      if (reversesExpenseId != null) 'reverses_expense_id': reversesExpenseId,
      'currency': currency,
      'expense_date': expenseDate,
      'split_type': splitType,
      'created_at': createdAt,
      'shares': shares.map((s) => s.toJson()).toList(),
    };
  }
}

class UserBalance {
  final String userId;
  final String name;
  final String email;
  final int netBalance; // in paise: >0 creditor, <0 debtor

  UserBalance({
    required this.userId,
    required this.name,
    this.email = '',
    required this.netBalance,
  });

  factory UserBalance.fromJson(Map<String, dynamic> json) {
    return UserBalance(
      userId: json['user_id'] ?? json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      netBalance: json['net_balance'] ?? json['netBalance'] ?? 0,
    );
  }
}

class PairwiseDebt {
  final String userA;
  final String userAName;
  final String userB;
  final String userBName;
  final int netDebt; // positive: user_b owes user_a
  final String explanation;

  PairwiseDebt({
    required this.userA,
    required this.userAName,
    required this.userB,
    required this.userBName,
    required this.netDebt,
    this.explanation = '',
  });

  factory PairwiseDebt.fromJson(Map<String, dynamic> json) {
    return PairwiseDebt(
      userA: json['user_a'] ?? json['userA'] ?? '',
      userAName: json['user_a_name'] ?? json['userAName'] ?? '',
      userB: json['user_b'] ?? json['userB'] ?? '',
      userBName: json['user_b_name'] ?? json['userBName'] ?? '',
      netDebt: json['net_debt'] ?? json['netDebt'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }
}

class RecommendedTransfer {
  final String fromUser;
  final String fromUserName;
  final String toUser;
  final String toUserName;
  final int amount; // in paise

  RecommendedTransfer({
    required this.fromUser,
    required this.fromUserName,
    required this.toUser,
    required this.toUserName,
    required this.amount,
  });

  factory RecommendedTransfer.fromJson(Map<String, dynamic> json) {
    return RecommendedTransfer(
      fromUser: json['from_user'] ?? json['fromUser'] ?? '',
      fromUserName: json['from_user_name'] ?? json['fromUserName'] ?? '',
      toUser: json['to_user'] ?? json['toUser'] ?? '',
      toUserName: json['to_user_name'] ?? json['toUserName'] ?? '',
      amount: json['amount'] ?? 0,
    );
  }
}

class Settlement {
  final String id;
  final String groupId;
  final String fromUser;
  final String fromUserName;
  final String toUser;
  final String toUserName;
  final int amount; // in paise
  final String status; // 'PAYMENT_RECORDED' | 'CONFIRMED' | 'CANCELLED'
  final String recordedBy;
  final String? confirmedBy;
  final String? cancelledBy;
  final String createdAt;
  final String? confirmedAt;
  final String? cancelledAt;

  Settlement({
    required this.id,
    required this.groupId,
    required this.fromUser,
    this.fromUserName = '',
    required this.toUser,
    this.toUserName = '',
    required this.amount,
    required this.status,
    required this.recordedBy,
    this.confirmedBy,
    this.cancelledBy,
    required this.createdAt,
    this.confirmedAt,
    this.cancelledAt,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? json['groupId'] ?? '',
      fromUser: json['from_user'] ?? json['fromUser'] ?? '',
      fromUserName: json['from_user_name'] ?? json['fromUserName'] ?? '',
      toUser: json['to_user'] ?? json['toUser'] ?? '',
      toUserName: json['to_user_name'] ?? json['toUserName'] ?? '',
      amount: json['amount'] ?? 0,
      status: json['status'] ?? 'PAYMENT_RECORDED',
      recordedBy: json['recorded_by'] ?? json['recordedBy'] ?? '',
      confirmedBy: json['confirmed_by'] ?? json['confirmedBy'],
      cancelledBy: json['cancelled_by'] ?? json['cancelledBy'],
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      confirmedAt: json['confirmed_at'] ?? json['confirmedAt'],
      cancelledAt: json['cancelled_at'] ?? json['cancelledAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'from_user': fromUser,
      'from_user_name': fromUserName,
      'to_user': toUser,
      'to_user_name': toUserName,
      'amount': amount,
      'status': status,
      'recorded_by': recordedBy,
      'created_at': createdAt,
    };
  }
}

class ActivityItem {
  final String id;
  final String groupId;
  final String actorId;
  final String actorName;
  final String action;
  final String summary;
  final String createdAt;

  ActivityItem({
    required this.id,
    required this.groupId,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.summary,
    required this.createdAt,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? json['groupId'] ?? '',
      actorId: json['actor_id'] ?? json['actorId'] ?? '',
      actorName: json['actor_name'] ?? json['actorName'] ?? 'Member',
      action: json['action'] ?? '',
      summary: json['summary'] ?? '',
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
    );
  }
}

class PersonalExpense {
  final String id;
  final String description;
  final int amount; // in paise
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
