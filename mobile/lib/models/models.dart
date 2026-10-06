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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      defaultCurrency: json['default_currency']?.toString() ?? json['defaultCurrency']?.toString() ?? 'INR',
      token: json['token']?.toString(),
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
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'MEMBER',
      status: json['status']?.toString() ?? 'ACTIVE',
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
            ?.map((m) => GroupMember.fromJson(m is Map<String, dynamic> ? m : Map<String, dynamic>.from(m)))
            .toList() ??
        [];
    return Group(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'INR',
      inviteCode: json['invite_code']?.toString() ?? json['inviteCode']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? json['createdBy']?.toString() ?? '',
      ledgerVersion: (json['ledger_version'] as num? ?? json['ledgerVersion'] as num?)?.toInt() ?? 1,
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
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      shareAmount: (json['share_amount'] as num? ?? json['shareAmount'] as num?)?.toInt() ?? 0,
      basisPoints: (json['basis_points'] as num? ?? json['basisPoints'] as num?)?.toInt(),
      shares: (json['shares'] as num?)?.toInt(),
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
            ?.map((s) => ExpenseShare.fromJson(s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s)))
            .toList() ??
        [];
    return Expense(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? json['groupId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'GENERAL',
      paidBy: json['paid_by']?.toString() ?? json['paidBy']?.toString() ?? '',
      payerName: json['payer_name']?.toString() ?? json['payerName']?.toString(),
      createdBy: json['created_by']?.toString() ?? json['createdBy']?.toString() ?? '',
      isReversed: json['is_reversed'] == true || json['isReversed'] == true,
      isReversal: json['is_reversal'] == true || json['isReversal'] == true,
      reversesExpenseId: json['reverses_expense_id']?.toString() ?? json['reversesExpenseId']?.toString(),
      currency: json['currency']?.toString() ?? 'INR',
      expenseDate: json['expense_date']?.toString() ?? json['expenseDate']?.toString() ?? json['created_at']?.toString() ?? '',
      splitType: json['split_type']?.toString() ?? json['splitType']?.toString() ?? 'EQUAL',
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
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
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      netBalance: (json['net_balance'] as num? ?? json['netBalance'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'net_balance': netBalance,
    };
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
      userA: json['user_a']?.toString() ?? json['userA']?.toString() ?? '',
      userAName: json['user_a_name']?.toString() ?? json['userAName']?.toString() ?? '',
      userB: json['user_b']?.toString() ?? json['userB']?.toString() ?? '',
      userBName: json['user_b_name']?.toString() ?? json['userBName']?.toString() ?? '',
      netDebt: (json['net_debt'] as num? ?? json['netDebt'] as num?)?.toInt() ?? 0,
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_a': userA,
      'user_a_name': userAName,
      'user_b': userB,
      'user_b_name': userBName,
      'net_debt': netDebt,
      'explanation': explanation,
    };
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
      fromUser: json['from_user']?.toString() ?? json['fromUser']?.toString() ?? '',
      fromUserName: json['from_user_name']?.toString() ?? json['fromUserName']?.toString() ?? '',
      toUser: json['to_user']?.toString() ?? json['toUser']?.toString() ?? '',
      toUserName: json['to_user_name']?.toString() ?? json['toUserName']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_user': fromUser,
      'from_user_name': fromUserName,
      'to_user': toUser,
      'to_user_name': toUserName,
      'amount': amount,
    };
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
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? json['groupId']?.toString() ?? '',
      fromUser: json['from_user']?.toString() ?? json['fromUser']?.toString() ?? '',
      fromUserName: json['from_user_name']?.toString() ?? json['fromUserName']?.toString() ?? '',
      toUser: json['to_user']?.toString() ?? json['toUser']?.toString() ?? '',
      toUserName: json['to_user_name']?.toString() ?? json['toUserName']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'PAYMENT_RECORDED',
      recordedBy: json['recorded_by']?.toString() ?? json['recordedBy']?.toString() ?? '',
      confirmedBy: json['confirmed_by']?.toString() ?? json['confirmedBy']?.toString(),
      cancelledBy: json['cancelled_by']?.toString() ?? json['cancelledBy']?.toString(),
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
      confirmedAt: json['confirmed_at']?.toString() ?? json['confirmedAt']?.toString(),
      cancelledAt: json['cancelled_at']?.toString() ?? json['cancelledAt']?.toString(),
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
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? json['groupId']?.toString() ?? '',
      actorId: json['actor_id']?.toString() ?? json['actorId']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? json['actorName']?.toString() ?? 'Member',
      action: json['action']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'actor_id': actorId,
      'actor_name': actorName,
      'action': action,
      'summary': summary,
      'created_at': createdAt,
    };
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
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'GENERAL',
      date: json['date']?.toString() ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
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
