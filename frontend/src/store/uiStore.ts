import { create } from 'zustand';
import { Expense } from '../types';

interface UIState {
  activeGroupId: string | null;
  setActiveGroupId: (id: string | null) => void;
  isAddExpenseOpen: boolean;
  setIsAddExpenseOpen: (open: boolean) => void;
  isRecordSettlementOpen: boolean;
  setIsRecordSettlementOpen: (open: boolean, prefill?: { toUserId: string; amount: number } | null) => void;
  settlementPreFill: { toUserId: string; amount: number } | null;
  isCreateGroupOpen: boolean;
  setIsCreateGroupOpen: (open: boolean) => void;
  isJoinGroupOpen: boolean;
  setIsJoinGroupOpen: (open: boolean) => void;
  isGroupSettingsOpen: boolean;
  setIsGroupSettingsOpen: (open: boolean) => void;
  selectedPairwiseUser: { id: string; name: string } | null;
  setSelectedPairwiseUser: (user: { id: string; name: string } | null) => void;
  currentTab: 'group' | 'individual';
  setCurrentTab: (tab: 'group' | 'individual') => void;
  selectedExpenseForDetails: Expense | null;
  setSelectedExpenseForDetails: (expense: Expense | null) => void;
  smartTransactionPrompt: {
    amount: number;
    merchant: string;
    rawText: string;
    accountEnding?: string;
  } | null;
  setSmartTransactionPrompt: (prompt: {
    amount: number;
    merchant: string;
    rawText: string;
    accountEnding?: string;
  } | null) => void;
}

export const useUIStore = create<UIState>((set) => ({
  currentTab: 'group',
  setCurrentTab: (tab) => set({ currentTab: tab }),
  activeGroupId: localStorage.getItem('active_group_id') || null,
  setActiveGroupId: (id) => {
    set((state) => {
      if (state.activeGroupId === id) return state;
      if (id) {
        localStorage.setItem('active_group_id', id);
      } else {
        localStorage.removeItem('active_group_id');
      }
      return { activeGroupId: id };
    });
  },
  isAddExpenseOpen: false,
  setIsAddExpenseOpen: (open) => set({ isAddExpenseOpen: open }),
  isRecordSettlementOpen: false,
  settlementPreFill: null,
  setIsRecordSettlementOpen: (open, prefill = null) =>
    set({ isRecordSettlementOpen: open, settlementPreFill: prefill }),
  isCreateGroupOpen: false,
  setIsCreateGroupOpen: (open) => set({ isCreateGroupOpen: open }),
  isJoinGroupOpen: false,
  setIsJoinGroupOpen: (open) => set({ isJoinGroupOpen: open }),
  isGroupSettingsOpen: false,
  setIsGroupSettingsOpen: (open) => set({ isGroupSettingsOpen: open }),
  selectedPairwiseUser: null,
  setSelectedPairwiseUser: (user) => set({ selectedPairwiseUser: user }),
  selectedExpenseForDetails: null,
  setSelectedExpenseForDetails: (expense) => set({ selectedExpenseForDetails: expense }),
  smartTransactionPrompt: null,
  setSmartTransactionPrompt: (prompt) => set({ smartTransactionPrompt: prompt }),
}));
