import React, { useState, useEffect } from 'react';
import { useAuthStore } from '../store/authStore';
import { formatMoney, formatDate } from '../utils/formatters';
import { 
  Plus, 
  Trash2, 
  TrendingUp, 
  Receipt, 
  Coffee, 
  Plane, 
  Home, 
  Film, 
  ShoppingBag, 
  Tag, 
  Calendar,
  X,
  CreditCard,
  PieChart,
  ChevronDown
} from 'lucide-react';

interface PersonalExpense {
  id: string;
  description: string;
  amount: number; // In paise / minor units
  category: string;
  date: string;
  notes?: string;
}

const CATEGORIES = [
  { id: 'FOOD', label: 'Food & Dining', icon: Coffee },
  { id: 'GROCERIES', label: 'Groceries', icon: ShoppingBag },
  { id: 'TRAVEL', label: 'Travel & Transport', icon: Plane },
  { id: 'HOUSING', label: 'Housing & Utilities', icon: Home },
  { id: 'ENTERTAINMENT', label: 'Entertainment', icon: Film },
  { id: 'OTHER', label: 'Other', icon: Tag },
];

export const IndividualSpendingView: React.FC = () => {
  const user = useAuthStore((state) => state.user);
  const currency = user?.default_currency || 'INR';

  // Local storage persistence for personal solitary expenses
  const storageKey = `personal_expenses_${user?.id || 'default'}`;
  const [expenses, setExpenses] = useState<PersonalExpense[]>(() => {
    try {
      const saved = localStorage.getItem(storageKey);
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });

  const [isAddOpen, setIsAddOpen] = useState(false);
  const [description, setDescription] = useState('');
  const [amountInput, setAmountInput] = useState('');
  const [category, setCategory] = useState('FOOD');
  const [expenseDate, setExpenseDate] = useState(new Date().toISOString().split('T')[0]);
  const [filterCategory, setFilterCategory] = useState('ALL');

  useEffect(() => {
    localStorage.setItem(storageKey, JSON.stringify(expenses));
  }, [expenses, storageKey]);

  const handleAddExpense = (e: React.FormEvent) => {
    e.preventDefault();
    const amountVal = parseFloat(amountInput);
    if (!description.trim() || isNaN(amountVal) || amountVal <= 0) return;

    const newExp: PersonalExpense = {
      id: 'pexp_' + Date.now().toString(36),
      description: description.trim(),
      amount: Math.round(amountVal * 100),
      category,
      date: expenseDate,
    };

    setExpenses([newExp, ...expenses]);
    setDescription('');
    setAmountInput('');
    setIsAddOpen(false);
  };

  const handleDelete = (id: string) => {
    if (confirm('Delete this personal expense record?')) {
      setExpenses(expenses.filter((e) => e.id !== id));
    }
  };

  const totalSpent = expenses.reduce((sum, e) => sum + e.amount, 0);

  // Category breakdown calculations
  const categoryTotals: Record<string, number> = {};
  for (const exp of expenses) {
    categoryTotals[exp.category] = (categoryTotals[exp.category] || 0) + exp.amount;
  }

  const filteredExpenses = filterCategory === 'ALL'
    ? expenses
    : expenses.filter((e) => e.category === filterCategory);

  const getCategoryIcon = (cat: string) => {
    const found = CATEGORIES.find((c) => c.id === cat);
    if (!found) return Tag;
    return found.icon;
  };

  return (
    <div className="space-y-6 animate-in fade-in">
      {/* Header & Main Stats */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl sm:text-3xl font-bold text-neutral-900 tracking-tight">
              Personal Spending
            </h1>
            <span className="text-xs font-semibold px-2.5 py-0.5 rounded-full bg-sky-50 text-sky-700 border border-sky-200">
              Solo Spender
            </span>
          </div>
          <p className="text-xs sm:text-sm text-neutral-500 mt-1 max-w-xl">
            Track your solitary daily expenses, groceries, and personal purchases privately without group debt calculations.
          </p>
        </div>

        <button
          onClick={() => setIsAddOpen(true)}
          className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-sky-500 hover:bg-sky-600 text-white font-medium text-xs sm:text-sm shadow-sm shadow-sky-500/25 transition-all cursor-pointer self-start sm:self-auto"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>Add Personal Expense</span>
        </button>
      </div>

      {/* Metric Cards Grid */}
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-3 sm:gap-4">
        <div className="saas-card p-4 sm:p-5">
          <div className="flex items-center justify-between text-[10px] sm:text-xs font-semibold text-neutral-500 uppercase tracking-wider mb-1.5 sm:mb-2">
            <span>Total Solitary Spend</span>
            <TrendingUp className="w-3.5 h-3.5 text-neutral-400" />
          </div>
          <div className="text-xl sm:text-3xl font-bold text-neutral-900 tracking-tight">
            {formatMoney(totalSpent, currency)}
          </div>
          <div className="mt-1.5 text-[11px] sm:text-xs text-neutral-500">
            Across {expenses.length} personal entries
          </div>
        </div>

        <div className="saas-card p-4 sm:p-5">
          <div className="flex items-center justify-between text-[10px] sm:text-xs font-semibold text-neutral-500 uppercase tracking-wider mb-1.5 sm:mb-2">
            <span>Top Category</span>
            <PieChart className="w-3.5 h-3.5 text-neutral-400" />
          </div>
          <div className="text-xl sm:text-3xl font-bold text-neutral-900 tracking-tight truncate">
            {Object.keys(categoryTotals).length > 0
              ? Object.entries(categoryTotals).sort((a, b) => b[1] - a[1])[0][0]
              : 'None'}
          </div>
          <div className="mt-1.5 text-[11px] sm:text-xs text-neutral-500">
            Highest spending category
          </div>
        </div>

        <div className="saas-card p-4 sm:p-5 col-span-2 lg:col-span-1">
          <div className="flex items-center justify-between text-[10px] sm:text-xs font-semibold text-neutral-500 uppercase tracking-wider mb-1.5 sm:mb-2">
            <span>Solo Mode</span>
            <Receipt className="w-3.5 h-3.5 text-neutral-400" />
          </div>
          <div className="text-xl sm:text-3xl font-bold text-neutral-900 tracking-tight">
            100% Mine
          </div>
          <div className="mt-1.5 text-[11px] sm:text-xs text-neutral-500">
            Zero debts or settlements involved
          </div>
        </div>
      </div>

      {/* Category Pills Filter */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
        <button
          onClick={() => setFilterCategory('ALL')}
          className={`text-xs px-3 py-1.5 rounded-full font-medium transition-colors cursor-pointer shrink-0 ${
            filterCategory === 'ALL'
              ? 'bg-neutral-900 text-white'
              : 'bg-white hover:bg-neutral-100 text-neutral-600 border border-neutral-200'
          }`}
        >
          All Categories
        </button>
        {CATEGORIES.map((c) => (
          <button
            key={c.id}
            onClick={() => setFilterCategory(c.id)}
            className={`text-xs px-3 py-1.5 rounded-full font-medium transition-colors cursor-pointer shrink-0 flex items-center gap-1.5 ${
              filterCategory === c.id
                ? 'bg-neutral-900 text-white'
                : 'bg-white hover:bg-neutral-100 text-neutral-600 border border-neutral-200'
            }`}
          >
            <c.icon className="w-3 h-3" />
            <span>{c.label}</span>
          </button>
        ))}
      </div>

      {/* Expense Ledger Table */}
      <div className="saas-card overflow-hidden">
        <div className="p-4 sm:p-5 border-b border-neutral-100 flex items-center justify-between">
          <h3 className="font-bold text-sm sm:text-base text-neutral-900 tracking-tight">
            Personal Expense Ledger
          </h3>
          <span className="text-xs text-neutral-400">
            {filteredExpenses.length} records
          </span>
        </div>

        {filteredExpenses.length === 0 ? (
          <div className="p-10 text-center">
            <Receipt className="w-8 h-8 text-neutral-300 mx-auto mb-2" />
            <p className="text-xs text-neutral-500 font-medium">No personal expenses recorded yet</p>
            <p className="text-[11px] text-neutral-400 mt-0.5">Click "Add Personal Expense" above to record solitary costs.</p>
          </div>
        ) : (
          <div className="divide-y divide-neutral-100">
            {filteredExpenses.map((exp) => {
              const IconComp = getCategoryIcon(exp.category);
              return (
                <div
                  key={exp.id}
                  className="p-3.5 sm:p-4 flex items-center justify-between hover:bg-neutral-50/70 transition-colors"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="w-9 h-9 rounded-xl bg-neutral-100 border border-neutral-200 flex items-center justify-center shrink-0 text-neutral-600">
                      <IconComp className="w-4 h-4" />
                    </div>
                    <div className="min-w-0">
                      <h4 className="text-xs sm:text-sm font-semibold text-neutral-900 truncate">
                        {exp.description}
                      </h4>
                      <div className="flex items-center gap-2 text-[11px] text-neutral-400 mt-0.5">
                        <span className="font-medium text-neutral-500">{exp.category}</span>
                        <span>·</span>
                        <span>{formatDate(exp.date)}</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-3 shrink-0">
                    <span className="text-xs sm:text-sm font-bold text-neutral-900">
                      {formatMoney(exp.amount, currency)}
                    </span>
                    <button
                      onClick={() => handleDelete(exp.id)}
                      className="p-1.5 text-neutral-400 hover:text-rose-600 rounded-lg hover:bg-rose-50 transition-colors cursor-pointer"
                      title="Delete expense"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Add Personal Expense Modal */}
      {isAddOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-neutral-900/40 backdrop-blur-xs">
          <div className="bg-white w-full max-w-md rounded-2xl p-6 sm:p-7 border border-neutral-200 shadow-xl relative animate-in fade-in">
            <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
              <div>
                <h3 className="font-bold text-base text-neutral-900">Add Personal Expense</h3>
                <p className="text-xs text-neutral-500">Record a non-shared purchase</p>
              </div>
              <button
                onClick={() => setIsAddOpen(false)}
                className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleAddExpense} className="mt-5 space-y-4">
              <div>
                <label className="block text-xs font-semibold text-neutral-700 uppercase tracking-wider mb-1.5">
                  Description
                </label>
                <input
                  type="text"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="e.g. Solo Lunch, Books, Shoes..."
                  className="w-full px-3.5 py-2 text-sm bg-neutral-50 border border-neutral-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500 transition-all"
                  autoFocus
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-neutral-700 uppercase tracking-wider mb-1.5">
                  Amount ({currency})
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0.01"
                  value={amountInput}
                  onChange={(e) => setAmountInput(e.target.value)}
                  placeholder="0.00"
                  className="w-full px-3.5 py-2 text-sm font-semibold bg-neutral-50 border border-neutral-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500 transition-all"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-neutral-700 uppercase tracking-wider mb-1.5">
                    Category
                  </label>
                  <div className="relative flex items-center">
                    <select
                      value={category}
                      onChange={(e) => setCategory(e.target.value)}
                      className="w-full px-3 py-2 pr-8 text-xs bg-neutral-50 hover:bg-neutral-100 border border-neutral-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-neutral-900/10 cursor-pointer appearance-none transition-all"
                    >
                      {CATEGORIES.map((c) => (
                        <option key={c.id} value={c.id} className="bg-white text-neutral-900">
                          {c.label}
                        </option>
                      ))}
                    </select>
                    <ChevronDown className="w-3.5 h-3.5 text-neutral-400 absolute right-2.5 pointer-events-none" />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-neutral-700 uppercase tracking-wider mb-1.5">
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

              <div className="pt-2 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsAddOpen(false)}
                  className="px-3.5 py-2 text-xs font-medium text-neutral-600 hover:text-neutral-900 cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={!description.trim() || !amountInput}
                  className="px-4 py-2 rounded-full bg-sky-500 hover:bg-sky-600 text-white font-medium text-xs shadow-sm shadow-sky-500/25 transition-all cursor-pointer disabled:opacity-50"
                >
                  Save Expense
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
