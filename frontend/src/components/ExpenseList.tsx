import React, { useState, useMemo } from 'react';
import { useAuthStore } from '../store/authStore';
import { useUIStore } from '../store/uiStore';
import { Expense } from '../types';
import { formatMoney, formatDate } from '../utils/formatters';
import { apiRequest } from '../services/api';
import { 
  Receipt, 
  RotateCcw, 
  Tag, 
  Search, 
  Coffee, 
  Plane, 
  Home, 
  Film, 
  ShoppingBag,
  SlidersHorizontal
} from 'lucide-react';

interface ExpenseListProps {
  groupId: string;
  currency: string;
  expenses?: Expense[];
}

export const ExpenseList: React.FC<ExpenseListProps> = ({ groupId, currency, expenses = [] }) => {
  const safeExpenses = expenses || [];
  const currentUserId = useAuthStore((state) => state.user?.id);
  const setSelectedExpenseForDetails = useUIStore((state) => state.setSelectedExpenseForDetails);
  const [reversingId, setReversingId] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState<'ALL' | 'ACTIVE' | 'REVERSED'>('ALL');

  const getCategoryIcon = (category: string) => {
    switch (category?.toUpperCase()) {
      case 'FOOD':
        return <Coffee className="w-3.5 h-3.5 text-neutral-700" />;
      case 'TRAVEL':
      case 'TRANSPORT':
        return <Plane className="w-3.5 h-3.5 text-neutral-700" />;
      case 'RENT':
      case 'HOUSING':
        return <Home className="w-3.5 h-3.5 text-neutral-700" />;
      case 'ENTERTAINMENT':
        return <Film className="w-3.5 h-3.5 text-neutral-700" />;
      case 'SHOPPING':
        return <ShoppingBag className="w-3.5 h-3.5 text-neutral-700" />;
      default:
        return <Receipt className="w-3.5 h-3.5 text-neutral-700" />;
    }
  };

  const filteredExpenses = useMemo(() => {
    return safeExpenses.filter((exp) => {
      if (filterType === 'ACTIVE' && (exp.is_reversed || exp.is_reversal)) return false;
      if (filterType === 'REVERSED' && (!exp.is_reversed && !exp.is_reversal)) return false;

      if (!searchQuery.trim()) return true;
      const q = searchQuery.toLowerCase();
      return (
        exp.description.toLowerCase().includes(q) ||
        (exp.payer_name && exp.payer_name.toLowerCase().includes(q)) ||
        (exp.category && exp.category.toLowerCase().includes(q))
      );
    });
  }, [safeExpenses, filterType, searchQuery]);

  const handleReverse = async (expenseId: string) => {
    if (!confirm('Are you sure you want to reverse this expense? This creates an immutable reversal record.')) {
      return;
    }

    setReversingId(expenseId);
    try {
      await apiRequest(`/groups/${groupId}/expenses/${expenseId}/reverse`, {
        method: 'POST',
        useIdempotency: true,
      });
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Reversal failed');
    } finally {
      setReversingId(null);
    }
  };

  return (
    <div className="saas-card overflow-hidden">
      {/* Table Header / Filter Bar */}
      <div className="p-4 sm:p-5 border-b border-neutral-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h2 className="text-base font-bold text-neutral-900 tracking-tight">
            Transaction Ledger
          </h2>
          <p className="text-xs text-neutral-500">
            {filteredExpenses.length} total entries recorded
          </p>
        </div>

        <div className="flex items-center gap-2">
          {/* Search Bar */}
          <div className="relative">
            <Search className="w-3.5 h-3.5 text-neutral-400 absolute left-2.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search..."
              className="pl-8 pr-3 py-1.5 text-xs rounded-lg bg-neutral-50 border border-neutral-200 text-neutral-900 placeholder-neutral-400 focus:outline-none focus:border-neutral-900 transition-colors w-36 sm:w-48"
            />
          </div>

          {/* Filter Tabs */}
          <div className="flex items-center p-0.5 rounded-lg bg-neutral-100 border border-neutral-200">
            <button
              onClick={() => setFilterType('ALL')}
              className={`px-2.5 py-1 text-xs font-medium rounded-md transition-all cursor-pointer ${
                filterType === 'ALL'
                  ? 'bg-white text-neutral-900 shadow-2xs font-semibold'
                  : 'text-neutral-500 hover:text-neutral-800'
              }`}
            >
              All
            </button>
            <button
              onClick={() => setFilterType('ACTIVE')}
              className={`px-2.5 py-1 text-xs font-medium rounded-md transition-all cursor-pointer ${
                filterType === 'ACTIVE'
                  ? 'bg-white text-neutral-900 shadow-2xs font-semibold'
                  : 'text-neutral-500 hover:text-neutral-800'
              }`}
            >
              Active
            </button>
            <button
              onClick={() => setFilterType('REVERSED')}
              className={`px-2.5 py-1 text-xs font-medium rounded-md transition-all cursor-pointer ${
                filterType === 'REVERSED'
                  ? 'bg-white text-neutral-900 shadow-2xs font-semibold'
                  : 'text-neutral-500 hover:text-neutral-800'
              }`}
            >
              Reversed
            </button>
          </div>
        </div>
      </div>

      {/* List items */}
      {filteredExpenses.length === 0 ? (
        <div className="py-12 px-4 text-center">
          <Receipt className="w-8 h-8 text-neutral-300 mx-auto mb-2" />
          <h3 className="text-sm font-semibold text-neutral-700">No transactions recorded</h3>
          <p className="text-xs text-neutral-400 mt-0.5">
            {searchQuery ? 'No expenses match your search query.' : 'Click "Add Expense" to start.'}
          </p>
        </div>
      ) : (
        <div className="divide-y divide-neutral-100">
          {filteredExpenses.map((exp) => {
            const canReverse =
              !exp.is_reversal &&
              !exp.is_reversed &&
              (exp.paid_by === currentUserId || exp.created_by === currentUserId);

            const isReversedOrReversal = exp.is_reversed || exp.is_reversal;

            return (
              <div
                key={exp.id}
                onClick={() => setSelectedExpenseForDetails(exp)}
                className={`p-4 flex items-center justify-between gap-4 transition-colors cursor-pointer ${
                  isReversedOrReversal
                    ? 'bg-neutral-50/50 opacity-60'
                    : 'hover:bg-neutral-50/70'
                }`}
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-9 h-9 rounded-lg bg-neutral-100 border border-neutral-200/80 flex items-center justify-center shrink-0">
                    {getCategoryIcon(exp.category)}
                  </div>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-semibold text-neutral-900 truncate">
                        {exp.description}
                      </span>
                      {exp.is_reversed && (
                        <span className="text-[10px] font-medium px-2 py-0.2 rounded-full bg-rose-50 text-rose-700 border border-rose-200">
                          Reversed
                        </span>
                      )}
                      {exp.is_reversal && (
                        <span className="text-[10px] font-medium px-2 py-0.2 rounded-full bg-purple-50 text-purple-700 border border-purple-200">
                          Reversal Event
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-2 mt-0.5 text-xs text-neutral-500">
                      <span>Paid by <strong>{exp.payer_name || 'Member'}</strong></span>
                      <span>•</span>
                      <span>{formatDate(exp.expense_date || exp.created_at)}</span>
                      <span>•</span>
                      <span className="inline-flex items-center gap-1 text-[11px] font-medium px-1.5 py-0.2 rounded bg-neutral-100 text-neutral-600">
                        {exp.category}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-3 shrink-0">
                  <div className="text-right">
                    <span className="text-sm sm:text-base font-bold text-neutral-900 block">
                      {formatMoney(exp.amount, currency)}
                    </span>
                    <span className="text-[11px] text-neutral-400">
                      {exp.split_type} ({exp.participants?.length || 0})
                    </span>
                  </div>

                  {canReverse && (
                    <button
                      onClick={() => handleReverse(exp.id)}
                      disabled={reversingId === exp.id}
                      title="Reverse Expense"
                      className="p-1.5 text-neutral-400 hover:text-rose-600 hover:bg-neutral-100 rounded-lg transition-colors cursor-pointer"
                    >
                      <RotateCcw className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
