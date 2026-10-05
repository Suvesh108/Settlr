export interface User {
  id: string;
  name: string;
  email: string;
  default_currency: string;
  token?: string;
}

export interface GroupMember {
  user_id: string;
  name: string;
  email: string;
  role: 'OWNER' | 'ADMIN' | 'MEMBER';
  status: 'ACTIVE' | 'LEFT' | 'REMOVED';
  joined_at: string;
}

export interface Group {
  id: string;
  name: string;
  description: string;
  currency: string;
  invite_code: string;
  ledger_version: number;
  created_by: string;
  created_at: string;
  members?: GroupMember[];
}

export type SplitType = 'EQUAL' | 'EXACT' | 'PERCENTAGE' | 'SHARES';

export interface ParticipantShare {
  user_id: string;
  share_amount: number; // in paise
  basis_points?: number;
  shares?: number;
}

export interface Expense {
  id: string;
  group_id: string;
  paid_by: string;
  payer_name?: string;
  amount: number; // in paise
  currency: string;
  description: string;
  category: string;
  split_type: SplitType;
  expense_date: string;
  is_reversal: boolean;
  is_reversed: boolean;
  reverses_expense_id?: string;
  created_by: string;
  created_at: string;
  participants: ParticipantShare[];
}

export interface UserBalance {
  user_id: string;
  name: string;
  email: string;
  net_balance: number; // in paise: > 0 creditor, < 0 debtor
}

export interface PairwiseDebt {
  user_a: string;
  user_a_name: string;
  user_b: string;
  user_b_name: string;
  net_debt: number; // >0 means UserB owes UserA; <0 means UserA owes UserB
  explanation: string;
}

export interface RecommendedTransfer {
  from_user: string;
  from_user_name: string;
  to_user: string;
  to_user_name: string;
  amount: number; // in paise
}

export interface Settlement {
  id: string;
  group_id: string;
  from_user: string;
  from_user_name: string;
  to_user: string;
  to_user_name: string;
  amount: number; // in paise
  status: 'PAYMENT_RECORDED' | 'CONFIRMED' | 'CANCELLED';
  recorded_by: string;
  confirmed_by?: string;
  cancelled_by?: string;
  created_at: string;
  confirmed_at?: string;
  cancelled_at?: string;
}

export interface ActivityItem {
  id: string;
  group_id: string;
  actor_id: string;
  actor_name: string;
  action: string;
  summary: string;
  metadata?: Record<string, unknown>;
  created_at: string;
}
