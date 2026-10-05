import React, { useState } from 'react';
import { useUIStore } from '../store/uiStore';
import { Group, UserBalance, RecommendedTransfer } from '../types';
import { formatMoney } from '../utils/formatters';
import { 
  Plus, 
  CreditCard, 
  Users, 
  Settings, 
  LayoutDashboard, 
  Receipt, 
  Activity, 
  ArrowUpRight, 
  ArrowDownLeft, 
  CheckCircle2, 
  ChevronUp,
  X
} from 'lucide-react';

interface MobileLayoutProps {
  activeGroup?: Group;
  balances?: UserBalance[];
  transfers?: RecommendedTransfer[];
  myBalance: number;
  activeTab: 'overview' | 'expenses' | 'settlements' | 'activity';
  setActiveTab: (tab: 'overview' | 'expenses' | 'settlements' | 'activity') => void;
}

export const MobileHeader: React.FC<{
  group?: Group;
  myBalance: number;
  onOpenSettings: () => void;
}> = ({ group, myBalance, onOpenSettings }) => {
  const isCreditor = myBalance > 0.009;
  const isDebtor = myBalance < -0.009;

  return (
    <div className="md:hidden bg-white border-b border-neutral-200 px-4 py-3 sticky top-16 z-20">
      <div className="flex items-center justify-between">
        <div className="min-w-0">
          <h2 className="text-sm font-bold text-neutral-900 truncate">
            {group?.name || 'My Group'}
          </h2>
          <div className="flex items-center gap-1.5 mt-0.5">
            <span
              className={`text-xs font-semibold ${
                isCreditor ? 'text-emerald-600' : isDebtor ? 'text-rose-600' : 'text-neutral-500'
              }`}
            >
              {isCreditor && `+${formatMoney(myBalance, group?.currency || 'INR')}`}
              {isDebtor && `-${formatMoney(Math.abs(myBalance), group?.currency || 'INR')}`}
              {!isCreditor && !isDebtor && 'Settled up'}
            </span>
            <span className="text-[10px] text-neutral-400">· v{group?.ledger_version || 1}</span>
          </div>
        </div>

        <button
          onClick={onOpenSettings}
          className="p-2 rounded-full bg-neutral-50 hover:bg-neutral-100 border border-neutral-200 text-neutral-600 transition-colors"
          title="Group settings"
        >
          <Settings className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
};

export const MobileBottomNavigation: React.FC<{
  activeTab: 'overview' | 'expenses' | 'settlements' | 'activity';
  setActiveTab: (tab: 'overview' | 'expenses' | 'settlements' | 'activity') => void;
  onAddExpense: () => void;
}> = ({ activeTab, setActiveTab, onAddExpense }) => {
  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-md border-t border-neutral-200 px-2 py-1.5 safe-area-pb">
      <div className="flex items-center justify-around max-w-md mx-auto relative">
        {/* Tab 1: Overview */}
        <button
          onClick={() => setActiveTab('overview')}
          className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition-colors cursor-pointer ${
            activeTab === 'overview' ? 'text-sky-600 font-semibold' : 'text-neutral-400 hover:text-neutral-600'
          }`}
        >
          <LayoutDashboard className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Overview</span>
        </button>

        {/* Tab 2: Expenses */}
        <button
          onClick={() => setActiveTab('expenses')}
          className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition-colors cursor-pointer ${
            activeTab === 'expenses' ? 'text-sky-600 font-semibold' : 'text-neutral-400 hover:text-neutral-600'
          }`}
        >
          <Receipt className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Expenses</span>
        </button>

        {/* Center Floating Plus CTA */}
        <div className="relative -top-4 flex items-center justify-center">
          <button
            onClick={onAddExpense}
            className="w-12 h-12 rounded-full bg-sky-500 hover:bg-sky-600 active:scale-95 text-white flex items-center justify-center shadow-lg shadow-sky-500/35 border-2 border-white transition-all cursor-pointer"
            title="Add Expense"
          >
            <Plus className="w-6 h-6 stroke-[2.5]" />
          </button>
        </div>

        {/* Tab 3: Settlements */}
        <button
          onClick={() => setActiveTab('settlements')}
          className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition-colors cursor-pointer ${
            activeTab === 'settlements' ? 'text-sky-600 font-semibold' : 'text-neutral-400 hover:text-neutral-600'
          }`}
        >
          <CreditCard className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Settle</span>
        </button>

        {/* Tab 4: Activity */}
        <button
          onClick={() => setActiveTab('activity')}
          className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition-colors cursor-pointer ${
            activeTab === 'activity' ? 'text-sky-600 font-semibold' : 'text-neutral-400 hover:text-neutral-600'
          }`}
        >
          <Activity className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Activity</span>
        </button>
      </div>
    </nav>
  );
};

export const MobileQuickActionsDrawer: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  currency: string;
  myBalance: number;
  onAddExpense: () => void;
  onSettleUp: () => void;
  onInvite: () => void;
}> = ({ isOpen, onClose, currency, myBalance, onAddExpense, onSettleUp, onInvite }) => {
  if (!isOpen) return null;

  return (
    <div className="md:hidden fixed inset-0 z-50 bg-neutral-900/40 backdrop-blur-xs flex flex-col justify-end">
      <div className="bg-white rounded-t-3xl p-5 border-t border-neutral-200 shadow-2xl animate-in slide-in-from-bottom duration-200">
        <div className="w-10 h-1 bg-neutral-200 rounded-full mx-auto mb-4" />
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-bold text-neutral-900">Quick Actions</h3>
          <button onClick={onClose} className="p-1 text-neutral-400 hover:text-neutral-700">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="grid grid-cols-2 gap-3 mb-4">
          <button
            onClick={() => {
              onClose();
              onAddExpense();
            }}
            className="flex flex-col items-center p-4 rounded-2xl bg-sky-50 text-sky-700 border border-sky-100 font-medium text-xs gap-2 active:bg-sky-100"
          >
            <div className="w-10 h-10 rounded-full bg-sky-500 text-white flex items-center justify-center shadow-xs">
              <Plus className="w-5 h-5" />
            </div>
            <span>Add Expense</span>
          </button>

          <button
            onClick={() => {
              onClose();
              onSettleUp();
            }}
            className="flex flex-col items-center p-4 rounded-2xl bg-neutral-50 text-neutral-700 border border-neutral-200 font-medium text-xs gap-2 active:bg-neutral-100"
          >
            <div className="w-10 h-10 rounded-full bg-white border border-neutral-200 text-neutral-700 flex items-center justify-center shadow-xs">
              <CreditCard className="w-5 h-5 text-neutral-600" />
            </div>
            <span>Record Settlement</span>
          </button>
        </div>

        <button
          onClick={() => {
            onClose();
            onInvite();
          }}
          className="w-full py-2.5 px-4 rounded-xl border border-neutral-200 bg-white hover:bg-neutral-50 text-neutral-700 text-xs font-medium flex items-center justify-center gap-2"
        >
          <Users className="w-4 h-4 text-neutral-500" />
          <span>Invite Members with Code</span>
        </button>
      </div>
    </div>
  );
};
