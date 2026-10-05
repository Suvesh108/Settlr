import React from 'react';
import { useAuthStore } from '../store/authStore';
import { useUIStore } from '../store/uiStore';
import { UserBalance, Group } from '../types';
import { formatMoney } from '../utils/formatters';
import { ArrowUpRight, ArrowDownLeft, CheckCircle2, Plus, CreditCard, ArrowRight, Settings, Sparkles, Send } from 'lucide-react';

interface HeroBannerProps {
  group: Group;
  balances: UserBalance[];
  totalSpending: number;
}

export const HeroBanner: React.FC<HeroBannerProps> = ({ group, balances, totalSpending }) => {
  const user = useAuthStore((state) => state.user);
  const { setIsAddExpenseOpen, setIsRecordSettlementOpen, setIsGroupSettingsOpen } = useUIStore();

  const myBalance = balances.find((b) => b.user_id === user?.id)?.net_balance || 0;
  const isCreditor = myBalance > 0.009;
  const isDebtor = myBalance < -0.009;
  const isSettled = !isCreditor && !isDebtor;

  // Compute what current user is owed vs owes
  const owedToMe = isCreditor ? myBalance : 0;
  const iOwe = isDebtor ? Math.abs(myBalance) : 0;

  return (
    <div className="mb-8">
      {/* Page Title & Meta Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-5">
        <div>
          <div className="flex items-center gap-2.5">
            <h1 className="text-2xl sm:text-3xl font-bold text-neutral-900 tracking-tight">
              {group.name}
            </h1>
            <span className="text-xs font-medium px-2.5 py-0.5 rounded-full bg-neutral-100 text-neutral-600 border border-neutral-200">
              v{group.ledger_version}
            </span>
            <span className="text-xs font-medium px-2.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
              Active
            </span>
          </div>
          <p className="text-sm text-neutral-500 mt-1 max-w-xl">
            {group.description || 'Shared expense tracking with automated zero-sum settlement simplification.'}
          </p>
        </div>

        {/* Header Action Buttons */}
        <div className="flex items-center gap-2 self-start sm:self-auto flex-wrap">
          <button
            onClick={() => setIsGroupSettingsOpen(true)}
            className="p-2 rounded-full bg-white hover:bg-neutral-50 border border-neutral-200 text-neutral-600 transition-all cursor-pointer shadow-2xs"
            title="Group Settings & Members"
          >
            <Settings className="w-4 h-4" />
          </button>

          <button
            onClick={() => setIsRecordSettlementOpen(true)}
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-white hover:bg-neutral-50 border border-neutral-200 text-neutral-700 font-medium text-xs sm:text-sm shadow-2xs transition-all cursor-pointer"
          >
            <CreditCard className="w-3.5 h-3.5 text-neutral-500" />
            <span>Settle Up</span>
          </button>
        </div>
      </div>

      {/* Non-Technical "In Plain English" Summary Banner */}
      <div className={`mb-6 p-4 rounded-2xl border transition-all ${
        isSettled
          ? 'bg-emerald-50/60 border-emerald-200 text-emerald-900'
          : isDebtor
          ? 'bg-rose-50/50 border-rose-200 text-rose-900'
          : 'bg-sky-50/50 border-sky-200 text-sky-900'
      }`}>
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="flex items-start sm:items-center gap-3">
            <div className={`p-2 rounded-xl shrink-0 ${
              isSettled
                ? 'bg-emerald-100 text-emerald-700'
                : isDebtor
                ? 'bg-rose-100 text-rose-700'
                : 'bg-sky-100 text-sky-700'
            }`}>
              {isSettled ? (
                <CheckCircle2 className="w-5 h-5" />
              ) : isDebtor ? (
                <Send className="w-5 h-5" />
              ) : (
                <Sparkles className="w-5 h-5" />
              )}
            </div>

            <div>
              <div className="font-semibold text-sm sm:text-base tracking-tight">
                {isSettled && "You're completely settled up!"}
                {isDebtor && `You owe ${formatMoney(iOwe, group.currency)} to the group`}
                {isCreditor && `You are owed ${formatMoney(owedToMe, group.currency)} in total`}
              </div>
              <p className="text-xs opacity-85 mt-0.5 max-w-xl">
                {isSettled && "You don't owe any money to anyone, and nobody owes you. Everything is square."}
                {isDebtor && "Click 'Settle Up' below to record a direct payment and zero out your balance."}
                {isCreditor && "Other members will pay you according to the recommended settlement steps below."}
              </p>
            </div>
          </div>

          {isDebtor && (
            <button
              onClick={() => setIsRecordSettlementOpen(true)}
              className="self-start sm:self-auto px-4 py-1.5 rounded-full bg-rose-600 hover:bg-rose-700 text-white font-medium text-xs shadow-sm transition-all cursor-pointer whitespace-nowrap"
            >
              Pay Now
            </button>
          )}
        </div>
      </div>

      {/* SaaS Interface Clean Metric Cards Grid */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        {/* Metric 1: Group Spending */}
        <div className="saas-card p-3.5 sm:p-5">
          <div className="flex items-center justify-between text-[10px] sm:text-xs font-semibold text-neutral-500 uppercase tracking-wider mb-1.5 sm:mb-2">
            <span>Group Spending</span>
            <span className="text-[10px] font-normal text-neutral-400 lowercase hidden sm:inline">total</span>
          </div>
          <div className="text-lg sm:text-2xl lg:text-3xl font-bold text-neutral-900 tracking-tight">
            {formatMoney(totalSpending, group.currency)}
          </div>
          <div className="mt-1.5 sm:mt-2.5 text-[11px] sm:text-xs text-neutral-500">
            {group.members?.length || 0} participants
          </div>
        </div>

        {/* Metric 2: You are Owed */}
        <div className="saas-card p-3.5 sm:p-5">
          <div className="flex items-center justify-between text-[10px] sm:text-xs font-semibold text-neutral-500 uppercase tracking-wider mb-1.5 sm:mb-2">
            <span>You Are Owed</span>
            {owedToMe > 0 && (
              <span className="inline-flex items-center gap-0.5 text-[10px] font-semibold text-emerald-700 bg-emerald-50 px-1.5 py-0.2 rounded-full border border-emerald-200">
                <ArrowUpRight className="w-2.5 h-2.5 text-emerald-600" />
                credit
              </span>
            )}
          </div>
          <div className="text-lg sm:text-2xl lg:text-3xl font-bold text-emerald-600 tracking-tight">
            {formatMoney(owedToMe, group.currency)}
          </div>
          <div className="mt-1.5 sm:mt-2.5 text-[11px] sm:text-xs text-neutral-500 truncate">
            {owedToMe > 0 ? 'To receive' : 'No dues'}
          </div>
        </div>

        {/* Metric 3: You Owe */}
        <div className="saas-card p-3.5 sm:p-5">
          <div className="flex items-center justify-between text-[10px] sm:text-xs font-semibold text-neutral-500 uppercase tracking-wider mb-1.5 sm:mb-2">
            <span>You Owe</span>
            {iOwe > 0 && (
              <span className="inline-flex items-center gap-0.5 text-[10px] font-semibold text-rose-700 bg-rose-50 px-1.5 py-0.2 rounded-full border border-rose-200">
                <ArrowDownLeft className="w-2.5 h-2.5 text-rose-600" />
                debt
              </span>
            )}
          </div>
          <div className="text-lg sm:text-2xl lg:text-3xl font-bold text-rose-600 tracking-tight">
            {formatMoney(iOwe, group.currency)}
          </div>
          <div className="mt-1.5 sm:mt-2.5 text-[11px] sm:text-xs text-neutral-500 truncate">
            {iOwe > 0 ? 'To pay' : 'No debts'}
          </div>
        </div>

        {/* Metric 4: Net Balance */}
        <div className="saas-card p-3.5 sm:p-5">
          <div className="flex items-center justify-between text-[10px] sm:text-xs font-semibold text-neutral-500 uppercase tracking-wider mb-1.5 sm:mb-2">
            <span>Net Balance</span>
            <span className="text-[10px] font-normal text-neutral-400 lowercase hidden sm:inline">{group.currency}</span>
          </div>
          <div className="flex items-center gap-2">
            <span
              className={`text-lg sm:text-2xl lg:text-3xl font-bold tracking-tight ${
                isCreditor ? 'text-emerald-600' : isDebtor ? 'text-rose-600' : 'text-neutral-900'
              }`}
            >
              {isSettled ? 'Settled Up' : formatMoney(myBalance, group.currency)}
            </span>
          </div>
          <div className="mt-1.5 sm:mt-2.5 text-[11px] sm:text-xs text-neutral-500 flex items-center gap-1 truncate">
            {isSettled ? (
              <>
                <CheckCircle2 className="w-3 h-3 text-emerald-600 shrink-0" />
                <span>Zero pending</span>
              </>
            ) : isCreditor ? (
              <span>Net positive</span>
            ) : (
              <span>Net negative</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
