import Dexie, { type Table } from 'dexie';
import { Group, Expense, Settlement, ActivityItem, User } from '../types';

export interface LocalPersonalExpense {
  id: string;
  amount: number;
  category: string;
  description: string;
  date: string;
  createdAt: number;
}

export interface GroupKeyStore {
  group_id: string;
  key_hex: string;
  created_at: number;
}

export interface SyncStateStore {
  group_id: string;
  last_seq: number;
  last_synced_at: number;
}

export class SettlrLocalDatabase extends Dexie {
  groups!: Table<Group, string>;
  expenses!: Table<Expense, string>;
  settlements!: Table<Settlement, string>;
  activities!: Table<ActivityItem, string>;
  personalExpenses!: Table<LocalPersonalExpense, string>;
  currentUser!: Table<User, string>;
  groupKeys!: Table<GroupKeyStore, string>;
  syncState!: Table<SyncStateStore, string>;

  constructor() {
    super('SettlrDB');
    this.version(1).stores({
      groups: 'id, created_by, created_at',
      expenses: 'id, group_id, paid_by, expense_date, created_at',
      settlements: 'id, group_id, from_user, to_user, status, created_at',
      activities: 'id, group_id, actor_id, created_at',
      personalExpenses: 'id, date, createdAt',
      currentUser: 'id, email',
      groupKeys: 'group_id',
      syncState: 'group_id',
    });
  }
}

export const localDB = new SettlrLocalDatabase();
