import React, { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { useAuthStore } from '../../store/authStore';
import { formatMoney, formatDate } from '../../utils/formatters';
import { 
  Plus, 
  Trash2, 
  Receipt, 
  Tag, 
  Calendar,
  X,
  CreditCard,
  ChevronDown
} from 'lucide-react';
import { CustomSelect } from './CustomSelect';
import { AnimatedModal } from './AnimatedModal';
import { localDB, LocalPersonalExpense } from '../../db/localDB';
import { useLiveQuery } from 'dexie-react-hooks';

const CATEGORIES = [
  { id: 'FOOD', label: 'Food & Groceries' },
  { id: 'TRANSPORT', label: 'Transport & Fuel' },
  { id: 'HOUSING', label: 'Housing & Utilities' },
  { id: 'ENTERTAINMENT', label: 'Entertainment' },
  { id: 'SHOPPING', label: 'Shopping & Personal' },
  { id: 'GENERAL', label: 'General / Other' },
];

export const PersonalStream: React.FC = () => {
  const user = useAuthStore((state) => state.user);
  const currency = user?.default_currency || 'INR';

  // Live query from Dexie local IndexedDB
  const liveExpenses = useLiveQuery(
    async () => {
      const all = await localDB.personalExpenses.toArray();
      return all.sort((a, b) => {
        const timeA = a.createdAt || (a.date ? new Date(a.date).getTime() : 0);
        const timeB = b.createdAt || (b.date ? new Date(b.date).getTime() : 0);
        return timeB - timeA;
      });
    },
    []
  );

  // Automatically migrate any previous solitary expenses stored in localStorage into Dexie
  React.useEffect(() => {
    const migrateLegacyStorage = async () => {
      try {
        const storageKey = `personal_expenses_${user?.id || 'default'}`;
        const raw = localStorage.getItem(storageKey);
        if (raw) {
          const legacyItems = JSON.parse(raw);
          if (Array.isArray(legacyItems) && legacyItems.length > 0) {
            for (const item of legacyItems) {
              const existing = await localDB.personalExpenses.get(item.id);
              if (!existing) {
                await localDB.personalExpenses.add({
                  id: item.id || ('pers_' + Math.random().toString(36).substring(2, 9)),
                  description: item.description || 'Personal Spend',
                  amount: Number(item.amount) || 0,
                  category: item.category || 'FOOD',
                  date: item.date || new Date().toISOString().split('T')[0],
                  createdAt: item.createdAt || Date.now(),
                });
              }
            }
          }
        }
      } catch (err) {
        console.warn('Legacy expense migration failed:', err);
      }
    };
    migrateLegacyStorage();
  }, [user?.id]);

  const expenses = (liveExpenses || []).map((e) => ({
    id: e.id,
    description: e.description,
    amount: e.amount,
    category: e.category,
    expense_date: e.date,
  }));

  const [filterCategory, setFilterCategory] = useState<string>('ALL');
  const [isAddOpen, setIsAddOpen] = useState(false);

  const [desc, setDesc] = useState('');
  const [amountStr, setAmountStr] = useState('');
  const [category, setCategory] = useState('FOOD');
  const [expenseDate, setExpenseDate] = useState(new Date().toISOString().split('T')[0]);

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    const val = parseFloat(amountStr);
    if (!desc.trim() || isNaN(val) || val <= 0) return;

    const newExpense: LocalPersonalExpense = {
      id: 'pers_' + Math.random().toString(36).substring(2, 9),
      description: desc.trim(),
      amount: Math.round(val * 100),
      category,
      date: expenseDate,
      createdAt: Date.now(),
    };

    await localDB.personalExpenses.add(newExpense);

    // Sync to localStorage as backup
    const storageKey = `personal_expenses_${user?.id || 'default'}`;
    try {
      const raw = localStorage.getItem(storageKey);
      const existing = raw ? JSON.parse(raw) : [];
      localStorage.setItem(storageKey, JSON.stringify([newExpense, ...existing]));
    } catch {}

    setDesc('');
    setAmountStr('');
    setIsAddOpen(false);
  };

  const handleDelete = async (id: string) => {
    await localDB.personalExpenses.delete(id);
    const storageKey = `personal_expenses_${user?.id || 'default'}`;
    try {
      const raw = localStorage.getItem(storageKey);
      if (raw) {
        const existing = JSON.parse(raw);
        localStorage.setItem(storageKey, JSON.stringify(existing.filter((e: any) => e.id !== id)));
      }
    } catch {}
  };

  const totalSpent = expenses.reduce((sum, e) => sum + e.amount, 0);
  const filtered = filterCategory === 'ALL'
    ? expenses
    : expenses.filter((e) => e.category === filterCategory);

  return (
    <div className="space-y-6">
      {/* Header Statement */}
      <div className="settlr-panel p-6 sm:p-7 bg-white">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-neutral-900">
                Personal Ledger
              </h1>
              <span className="text-xs font-semibold px-2.5 py-0.5 rounded-full bg-neutral-100 text-neutral-600 border border-neutral-200/60">
                Private
              </span>
            </div>
            <p className="text-xs text-neutral-500 mt-0.5 max-w-lg">
              Solitary daily expenses, coffee, transport, and personal purchases kept private from groups.
            </p>
          </div>

          <motion.button
            whileHover={{ scale: 1.03 }}
            whileTap={{ scale: 0.95 }}
            type="button"
            onClick={() => setIsAddOpen(true)}
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white font-semibold text-xs shadow-sm transition-all cursor-pointer self-start sm:self-auto"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Add Personal Expense</span>
          </motion.button>
        </div>

        {/* Total Spend */}
        <div className="mt-5 pt-4 border-t border-neutral-100 flex items-baseline justify-between">
          <span className="text-xs font-medium text-neutral-500">Total Solitary Spend</span>
          <div className="text-2xl font-extrabold text-neutral-900 num-tabular">
            {formatMoney(totalSpent, currency)}
          </div>
        </div>
      </div>

      {/* Add Modal with Spring Physics */}
      <AnimatedModal isOpen={isAddOpen} onClose={() => setIsAddOpen(false)} maxWidth="max-w-sm" className="p-6">
        <div className="flex items-center justify-between pb-3 border-b border-neutral-100">
          <h3 className="font-bold text-base text-neutral-900">New Personal Expense</h3>
          <motion.button
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.92 }}
            type="button"
            onClick={() => setIsAddOpen(false)}
            className="w-7 h-7 rounded-full bg-neutral-100 hover:bg-neutral-200 flex items-center justify-center text-neutral-500 transition-colors cursor-pointer"
          >
            <X className="w-4 h-4" />
          </motion.button>
        </div>

        <form onSubmit={handleAdd} className="mt-4 space-y-3.5">
          <div>
            <label className="block text-[11px] font-bold text-neutral-400 uppercase tracking-wider mb-1">
              Description
            </label>
            <input
              type="text"
              required
              value={desc}
              onChange={(e) => setDesc(e.target.value)}
              placeholder="e.g. Coffee, Metro recharge"
              className="w-full px-3.5 py-2 text-sm bg-neutral-50 border border-neutral-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500/20 font-medium"
            />
          </div>

          <div>
            <label className="block text-[11px] font-bold text-neutral-400 uppercase tracking-wider mb-1">
              Amount ({currency})
            </label>
            <input
              type="number"
              step="0.01"
              required
              value={amountStr}
              onChange={(e) => setAmountStr(e.target.value)}
              placeholder="0.00"
              className="w-full px-3.5 py-2 text-sm bg-neutral-50 border border-neutral-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500/20 font-bold"
            />
          </div>

          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="block text-[11px] font-bold text-neutral-400 uppercase tracking-wider mb-1">
                Category
              </label>
              <CustomSelect
                value={category}
                onChange={setCategory}
                options={CATEGORIES.map((c) => ({ value: c.id, label: c.label }))}
              />
            </div>

            <div>
              <label className="block text-[11px] font-bold text-neutral-400 uppercase tracking-wider mb-1">
                Date
              </label>
              <input
                type="date"
                value={expenseDate}
                onChange={(e) => setExpenseDate(e.target.value)}
                className="w-full px-3 py-2 text-xs bg-neutral-50 border border-neutral-200 rounded-xl focus:bg-white focus:outline-none"
              />
            </div>
          </div>

          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.96 }}
            type="submit"
            className="w-full py-2.5 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white font-semibold text-xs shadow-sm transition-all cursor-pointer mt-2"
          >
            Log Expense
          </motion.button>
        </form>
      </AnimatedModal>

      {/* Expense Stream List */}
      <div className="settlr-panel p-5 sm:p-6 bg-white">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
          <h2 className="text-base font-bold text-neutral-900 tracking-tight">
            Personal History
          </h2>

          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 relative">
            {['ALL', 'FOOD', 'TRANSPORT', 'HOUSING', 'ENTERTAINMENT', 'SHOPPING', 'GENERAL'].map((cat) => {
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
                      layoutId="personal-filter-pill"
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

        {filtered.length === 0 ? (
          <div className="py-12 text-center rounded-xl bg-neutral-50/50 border border-neutral-100">
            <Receipt className="w-6 h-6 text-neutral-400 mx-auto mb-2" />
            <span className="text-xs font-semibold text-neutral-700">No personal entries</span>
            <p className="text-[11px] text-neutral-400 mt-0.5">Click Add Personal Expense to log private purchases.</p>
          </div>
        ) : (
          <div className="divide-y divide-neutral-100">
            {filtered.map((e) => (
              <motion.div
                key={e.id}
                layout
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
                transition={{ duration: 0.18 }}
                className="py-3 flex items-center justify-between gap-3 hover:bg-neutral-50/80 -mx-3 px-3 rounded-xl transition-all group"
              >
                <div className="min-w-0">
                  <span className="text-xs sm:text-sm font-semibold text-neutral-900 truncate block">
                    {e.description}
                  </span>
                  <span className="text-[11px] text-neutral-400 block truncate">
                    {formatDate(e.expense_date)} · {e.category}
                  </span>
                </div>

                <div className="flex items-center gap-3 shrink-0">
                  <span className="text-xs sm:text-sm font-bold text-neutral-900 num-tabular">
                    {formatMoney(e.amount, currency)}
                  </span>

                  <button
                    type="button"
                    onClick={() => handleDelete(e.id)}
                    title="Delete expense"
                    className="opacity-0 group-hover:opacity-100 p-1.5 rounded-lg text-neutral-400 hover:text-rose-600 hover:bg-rose-50 transition-all cursor-pointer"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </motion.div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
