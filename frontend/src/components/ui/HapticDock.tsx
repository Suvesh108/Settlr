import React from 'react';
import { motion } from 'motion/react';
import { 
  LayoutDashboard, 
  Receipt, 
  CreditCard, 
  Activity, 
  Plus 
} from 'lucide-react';

interface HapticDockProps {
  activeTab: 'overview' | 'expenses' | 'settlements' | 'activity';
  setActiveTab: (tab: 'overview' | 'expenses' | 'settlements' | 'activity') => void;
  onAddExpense: () => void;
}

const DOCK_ITEMS = [
  { id: 'overview' as const, label: 'Overview', icon: LayoutDashboard },
  { id: 'expenses' as const, label: 'Expenses', icon: Receipt },
  { id: 'settlements' as const, label: 'Settle', icon: CreditCard },
  { id: 'activity' as const, label: 'Activity', icon: Activity },
];

export const HapticDock: React.FC<HapticDockProps> = ({
  activeTab,
  setActiveTab,
  onAddExpense,
}) => {
  return (
    <>
      {/* Floating Action Box Pill in bottom-right above navbar */}
      <div className="md:hidden fixed bottom-18 right-4 z-40">
        <motion.button
          whileHover={{ scale: 1.05, y: -2 }}
          whileTap={{ scale: 0.93 }}
          type="button"
          onClick={onAddExpense}
          className="flex items-center gap-2 px-4 py-2.5 rounded-2xl bg-neutral-900 text-white font-semibold text-xs shadow-xl shadow-neutral-900/30 border border-neutral-700/60 transition-all cursor-pointer backdrop-blur-md"
        >
          <div className="w-5 h-5 rounded-full bg-white/20 flex items-center justify-center">
            <Plus className="w-3.5 h-3.5 text-white stroke-[2.5]" />
          </div>
          <span>Add Expense</span>
        </motion.button>
      </div>

      {/* Clean Bottom Navigation Bar with fluid gliding indicator */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-xl border-t border-neutral-200/80 px-3 py-1.5 safe-area-pb shadow-lg shadow-black/5">
        <div className="grid grid-cols-4 max-w-sm mx-auto relative">
          {DOCK_ITEMS.map((item) => {
            const isActive = activeTab === item.id;
            const Icon = item.icon;
            return (
              <motion.button
                key={item.id}
                whileTap={{ scale: 0.90 }}
                type="button"
                onClick={() => setActiveTab(item.id)}
                className={`relative flex flex-col items-center justify-center py-1.5 rounded-xl transition-colors cursor-pointer ${
                  isActive ? 'text-neutral-900 font-bold' : 'text-neutral-400 hover:text-neutral-600 font-medium'
                }`}
              >
                {isActive && (
                  <motion.div
                    layoutId="dock-active-pill"
                    className="absolute inset-0 bg-neutral-100 rounded-xl"
                    transition={{ type: 'spring', stiffness: 500, damping: 35 }}
                  />
                )}
                <Icon className="relative z-10 w-5 h-5 mb-0.5" />
                <span className="relative z-10 text-[10px]">{item.label}</span>
              </motion.button>
            );
          })}
        </div>
      </nav>
    </>
  );
};
