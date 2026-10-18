import React, { useState } from 'react';
import { motion } from 'motion/react';
import { useUIStore } from '../../store/uiStore';
import { Expense, GroupMember, UserBalance } from '../../types';
import { formatMoney } from '../../utils/formatters';
import { AnimatedModal } from '../ui/AnimatedModal';
import { 
  BarChart3, 
  X, 
  TrendingUp, 
  PieChart, 
  Layers, 
  Sparkles, 
  Receipt, 
  ArrowUpRight,
  UserCheck
} from 'lucide-react';

interface SpendingAnalyticsModalProps {
  groupId: string;
  currency: string;
  expenses: Expense[];
  members: GroupMember[];
  balances: UserBalance[];
}

const CATEGORY_COLORS: Record<string, { bg: string; bar: string; text: string }> = {
  FOOD: { bg: 'bg-amber-50', bar: 'bg-amber-500', text: 'text-amber-700' },
  TRANSPORT: { bg: 'bg-sky-50', bar: 'bg-sky-500', text: 'text-sky-700' },
  HOUSING: { bg: 'bg-purple-50', bar: 'bg-purple-500', text: 'text-purple-700' },
  ENTERTAINMENT: { bg: 'bg-pink-50', bar: 'bg-pink-500', text: 'text-pink-700' },
  SHOPPING: { bg: 'bg-indigo-50', bar: 'bg-indigo-500', text: 'text-indigo-700' },
  GROCERIES: { bg: 'bg-emerald-50', bar: 'bg-emerald-500', text: 'text-emerald-700' },
  RENT: { bg: 'bg-blue-50', bar: 'bg-blue-500', text: 'text-blue-700' },
  TRAVEL: { bg: 'bg-teal-50', bar: 'bg-teal-500', text: 'text-teal-700' },
  GENERAL: { bg: 'bg-neutral-100', bar: 'bg-neutral-600', text: 'text-neutral-700' },
};

export const SpendingAnalyticsModal: React.FC<SpendingAnalyticsModalProps> = ({
  groupId,
  currency,
  expenses = [],
  members = [],
  balances = [],
}) => {
  const { isSpendingAnalyticsOpen, setIsSpendingAnalyticsOpen } = useUIStore();
  const [timeFilter, setTimeFilter] = useState<'ALL' | '30D' | '7D'>('ALL');

  if (!isSpendingAnalyticsOpen) return null;

  const activeExpenses = expenses.filter((e) => !e.is_reversed && !e.is_reversal);

  // Time filtering
  const now = Date.now();
  const filteredExpenses = activeExpenses.filter((e) => {
    if (timeFilter === 'ALL') return true;
    const expTime = new Date(e.created_at || e.expense_date).getTime();
    if (timeFilter === '7D') return now - expTime <= 7 * 86400 * 1000;
    if (timeFilter === '30D') return now - expTime <= 30 * 86400 * 1000;
    return true;
  });

  const totalSpent = filteredExpenses.reduce((sum, e) => sum + e.amount, 0);
  const expenseCount = filteredExpenses.length;
  const avgExpense = expenseCount > 0 ? Math.round(totalSpent / expenseCount) : 0;
  const largestExpense = filteredExpenses.reduce((max, e) => (e.amount > max ? e.amount : max), 0);

  // Category Aggregation
  const categoryTotals: Record<string, { total: number; count: number }> = {};
  filteredExpenses.forEach((e) => {
    const cat = e.category?.toUpperCase() || 'GENERAL';
    if (!categoryTotals[cat]) {
      categoryTotals[cat] = { total: 0, count: 0 };
    }
    categoryTotals[cat].total += e.amount;
    categoryTotals[cat].count += 1;
  });

  const sortedCategories = Object.entries(categoryTotals).sort(
    ([, a], [, b]) => b.total - a.total
  );

  // Member Total Paid Breakdown
  const memberPaidTotals: Record<string, number> = {};
  filteredExpenses.forEach((e) => {
    memberPaidTotals[e.paid_by] = (memberPaidTotals[e.paid_by] || 0) + e.amount;
  });

  const topPayerEntry = Object.entries(memberPaidTotals).sort(([, a], [, b]) => b - a)[0];
  const topPayerName = topPayerEntry
    ? members.find((m) => m.user_id === topPayerEntry[0])?.name || 'Member'
    : 'None';

  return (
    <AnimatedModal
      isOpen={isSpendingAnalyticsOpen}
      onClose={() => setIsSpendingAnalyticsOpen(false)}
      maxWidth="max-w-2xl"
    >
      {/* Header */}
      <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl bg-neutral-900 text-white flex items-center justify-center shadow-2xs">
            <BarChart3 className="w-4 h-4" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="font-bold text-base text-neutral-900">Spending Intelligence</h3>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-sky-50 text-sky-700 border border-sky-200 uppercase tracking-wider">
                Splitwise Pro
              </span>
            </div>
            <p className="text-xs text-neutral-500">
              Category breakdowns, spend velocity & member contributions
            </p>
          </div>
        </div>
        <motion.button
          whileHover={{ scale: 1.1, rotate: 90 }}
          whileTap={{ scale: 0.9 }}
          onClick={() => setIsSpendingAnalyticsOpen(false)}
          className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer rounded-full"
        >
          <X className="w-4 h-4" />
        </motion.button>
      </div>

      {/* Time Filter Tabs */}
      <div className="mt-4 flex items-center justify-between">
        <span className="text-xs font-semibold text-neutral-500 uppercase tracking-wider">
          Filter Horizon
        </span>
        <div className="flex items-center p-0.5 bg-neutral-100 rounded-lg border border-neutral-200/60">
          {(['ALL', '30D', '7D'] as const).map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setTimeFilter(t)}
              className={`px-3 py-1 rounded-md text-xs font-semibold transition-all cursor-pointer ${
                timeFilter === t
                  ? 'bg-white text-neutral-900 shadow-2xs'
                  : 'text-neutral-500 hover:text-neutral-900'
              }`}
            >
              {t === 'ALL' ? 'All-Time' : t === '30D' ? 'Last 30 Days' : 'Last 7 Days'}
            </button>
          ))}
        </div>
      </div>

      {/* Core Financial Metrics Grid */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-4">
        <div className="p-3.5 rounded-xl bg-neutral-50 border border-neutral-200/70">
          <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">
            Total Spend
          </span>
          <span className="text-base font-extrabold text-neutral-900 num-tabular mt-1 block">
            {formatMoney(totalSpent, currency)}
          </span>
          <span className="text-[10px] text-neutral-500">{expenseCount} transactions</span>
        </div>

        <div className="p-3.5 rounded-xl bg-neutral-50 border border-neutral-200/70">
          <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">
            Average Bill
          </span>
          <span className="text-base font-extrabold text-neutral-900 num-tabular mt-1 block">
            {formatMoney(avgExpense, currency)}
          </span>
          <span className="text-[10px] text-neutral-500">per transaction</span>
        </div>

        <div className="p-3.5 rounded-xl bg-neutral-50 border border-neutral-200/70">
          <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">
            Peak Expense
          </span>
          <span className="text-base font-extrabold text-neutral-900 num-tabular mt-1 block">
            {formatMoney(largestExpense, currency)}
          </span>
          <span className="text-[10px] text-neutral-500">single purchase</span>
        </div>

        <div className="p-3.5 rounded-xl bg-neutral-50 border border-neutral-200/70">
          <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">
            Top Payer
          </span>
          <span className="text-base font-extrabold text-neutral-900 truncate mt-1 block">
            {topPayerName}
          </span>
          <span className="text-[10px] text-neutral-500">
            {topPayerEntry ? formatMoney(topPayerEntry[1], currency) : '₹0'}
          </span>
        </div>
      </div>

      {/* Category Breakdown Bars */}
      <div className="mt-5">
        <h4 className="text-xs font-bold text-neutral-900 uppercase tracking-wider mb-3">
          Spending by Category
        </h4>

        {sortedCategories.length === 0 ? (
          <div className="p-6 text-center rounded-xl bg-neutral-50 border border-neutral-100 text-xs text-neutral-400">
            No expenses recorded in this period.
          </div>
        ) : (
          <div className="space-y-3">
            {sortedCategories.map(([cat, data]) => {
              const pct = totalSpent > 0 ? Math.round((data.total / totalSpent) * 100) : 0;
              const color = CATEGORY_COLORS[cat] || CATEGORY_COLORS['GENERAL'];

              return (
                <div key={cat} className="space-y-1.5">
                  <div className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2">
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md ${color.bg} ${color.text}`}>
                        {cat}
                      </span>
                      <span className="text-neutral-500 text-[11px]">({data.count} items)</span>
                    </div>
                    <div className="flex items-center gap-2 font-bold num-tabular">
                      <span>{formatMoney(data.total, currency)}</span>
                      <span className="text-neutral-400 text-[11px] font-normal w-10 text-right">
                        {pct}%
                      </span>
                    </div>
                  </div>

                  {/* Visual Progress Bar */}
                  <div className="w-full h-2 rounded-full bg-neutral-100 overflow-hidden">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${pct}%` }}
                      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                      className={`h-full rounded-full ${color.bar}`}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Member Spending Distribution */}
      <div className="mt-6 border-t border-neutral-100 pt-4">
        <h4 className="text-xs font-bold text-neutral-900 uppercase tracking-wider mb-3">
          Member Funding Contributions
        </h4>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
          {members.map((m) => {
            const paid = memberPaidTotals[m.user_id] || 0;
            const paidPct = totalSpent > 0 ? Math.round((paid / totalSpent) * 100) : 0;

            return (
              <div
                key={m.user_id}
                className="p-3 rounded-xl bg-neutral-50/70 border border-neutral-200/60 flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <div className="w-6 h-6 rounded-full bg-neutral-900 text-white font-bold text-[10px] flex items-center justify-center">
                    {m.name.slice(0, 2).toUpperCase()}
                  </div>
                  <div>
                    <span className="text-xs font-semibold text-neutral-900 block leading-tight">
                      {m.name}
                    </span>
                    <span className="text-[10px] text-neutral-400">{paidPct}% of group total</span>
                  </div>
                </div>
                <span className="text-xs font-bold text-neutral-900 num-tabular">
                  {formatMoney(paid, currency)}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      <div className="mt-6 flex items-center justify-end border-t border-neutral-100 pt-4">
        <button
          type="button"
          onClick={() => setIsSpendingAnalyticsOpen(false)}
          className="px-4 py-2 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white text-xs font-semibold shadow-2xs transition-all cursor-pointer"
        >
          Close Analytics
        </button>
      </div>
    </AnimatedModal>
  );
};
