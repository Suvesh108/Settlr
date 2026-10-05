import React, { useState } from 'react';
import { motion } from 'motion/react';
import { Expense } from '../../types';
import { formatMoney, formatDate } from '../../utils/formatters';
import { useAuthStore } from '../../store/authStore';
import { useUIStore } from '../../store/uiStore';
import { apiRequest } from '../../services/api';
import { 
  Receipt, 
  RotateCcw, 
  ChevronRight,
  Filter
} from 'lucide-react';

interface TransactionTableProps {
  groupId: string;
  currency: string;
  expenses: Expense[];
}

export const TransactionTable: React.FC<TransactionTableProps> = ({
  groupId,
  currency,
  expenses = [],
}) => {
  const currentUserId = useAuthStore((state) => state.user?.id);
  const { setSelectedExpenseForDetails } = useUIStore();
  const [filterCategory, setFilterCategory] = useState<string>('ALL');
  const [reversingId, setReversingId] = useState<string | null>(null);

  const activeExpenses = expenses.filter((e) => !e.is_reversed && !e.is_reversal);
  const filtered = filterCategory === 'ALL'
    ? activeExpenses
    : activeExpenses.filter((e) => e.category === filterCategory);

  const handleReverse = async (e: React.MouseEvent, expenseId: string) => {
    e.stopPropagation();
    if (!confirm('Are you sure you want to reverse this transaction?')) return;

    setReversingId(expenseId);
    try {
      await apiRequest(`/groups/${groupId}/expenses/${expenseId}/reverse`, {
        method: 'POST',
        useIdempotency: true,
      });
      window.location.reload();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Reversal failed');
    } finally {
      setReversingId(null);
    }
  };

  return (
    <div className="settlr-panel p-5 sm:p-6 bg-white">
      {/* Header & Filter */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-5">
        <div>
          <h2 className="text-base font-bold text-neutral-900 tracking-tight">
            Transaction Activity
          </h2>
          <p className="text-xs text-neutral-500">
            Immutable expense ledger entries with split breakdown
          </p>
        </div>

        {/* Category Pill Filters */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 relative">
          {['ALL', 'FOOD', 'GROCERIES', 'RENT', 'TRAVEL'].map((cat) => {
            const isActive = filterCategory === cat;
            return (
              <button
                key={cat}
                type="button"
                onClick={() => setFilterCategory(cat)}
                className={`relative text-xs px-2.5 py-1 rounded-lg font-medium transition-colors cursor-pointer ${
                  isActive ? 'text-white font-semibold' : 'text-neutral-600 hover:text-neutral-900'
                }`}
              >
                {isActive && (
                  <motion.div
                    layoutId="tx-filter-pill"
                    className="absolute inset-0 bg-neutral-900 rounded-lg shadow-2xs"
                    transition={{ type: 'spring', stiffness: 480, damping: 32 }}
                  />
                )}
                <span className="relative z-10">{cat === 'ALL' ? 'All' : cat}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* List */}
      {filtered.length === 0 ? (
        <div className="py-12 text-center rounded-xl bg-neutral-50/50 border border-neutral-100">
          <Receipt className="w-6 h-6 text-neutral-400 mx-auto mb-2" />
          <span className="text-xs font-semibold text-neutral-700">No transactions recorded</span>
          <p className="text-[11px] text-neutral-400 mt-0.5">Use Add Expense or Simulate SMS to log group payments.</p>
        </div>
      ) : (
        <div className="divide-y divide-neutral-100">
          {filtered.map((exp) => {
            const isPayer = exp.paid_by === currentUserId;
            const myShare = exp.participants.find((p) => p.user_id === currentUserId)?.share_amount || 0;

            return (
              <motion.div
                key={exp.id}
                layout
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.16 }}
                onClick={() => setSelectedExpenseForDetails(exp)}
                className="py-3 sm:py-3.5 flex items-center justify-between gap-3 hover:bg-neutral-50/80 -mx-3 px-3 rounded-xl transition-all cursor-pointer group"
              >
                {/* Left: Info */}
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-8 h-8 rounded-xl bg-neutral-100 border border-neutral-200/60 flex items-center justify-center shrink-0 text-neutral-700 font-semibold text-xs">
                    {exp.category?.slice(0, 1) || 'E'}
                  </div>

                  <div className="min-w-0">
                    <span className="text-xs sm:text-sm font-semibold text-neutral-900 truncate block">
                      {exp.description}
                    </span>
                    <span className="text-[11px] text-neutral-400 block truncate">
                      Paid by {isPayer ? 'You' : exp.payer_name || 'Member'} · {formatDate(exp.expense_date)}
                    </span>
                  </div>
                </div>

                {/* Right: Amounts & Quick Reversal */}
                <div className="flex items-center gap-3 shrink-0">
                  <div className="text-right">
                    <div className="text-xs sm:text-sm font-bold text-neutral-900 num-tabular">
                      {formatMoney(exp.amount, currency)}
                    </div>
                    {myShare > 0 && (
                      <span className="text-[10px] text-neutral-400">
                        Your share: {formatMoney(myShare, currency)}
                      </span>
                    )}
                  </div>

                  {isPayer && (
                    <button
                      type="button"
                      disabled={reversingId === exp.id}
                      onClick={(e) => handleReverse(e, exp.id)}
                      title="Reverse transaction"
                      className="opacity-0 group-hover:opacity-100 p-1.5 rounded-lg text-neutral-400 hover:text-rose-600 hover:bg-rose-50 transition-all cursor-pointer hidden sm:inline-flex"
                    >
                      <RotateCcw className="w-3.5 h-3.5" />
                    </button>
                  )}

                  <ChevronRight className="w-4 h-4 text-neutral-300 group-hover:text-neutral-500 transition-colors" />
                </div>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
};
