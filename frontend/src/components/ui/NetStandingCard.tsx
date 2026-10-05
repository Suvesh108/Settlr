import React from 'react';
import { motion } from 'motion/react';
import { useAuthStore } from '../../store/authStore';
import { useUIStore } from '../../store/uiStore';
import { Group, UserBalance } from '../../types';
import { formatMoney } from '../../utils/formatters';
import { 
  CheckCircle2, 
  ArrowUpRight, 
  ArrowDownLeft, 
  Settings, 
  CreditCard,
  Plus
} from 'lucide-react';

interface NetStandingCardProps {
  group: Group;
  balances: UserBalance[];
  totalSpending: number;
}

export const NetStandingCard: React.FC<NetStandingCardProps> = ({
  group,
  balances,
  totalSpending,
}) => {
  const user = useAuthStore((state) => state.user);
  const { setIsAddExpenseOpen, setIsRecordSettlementOpen, setIsGroupSettingsOpen } = useUIStore();

  const myBalance = balances.find((b) => b.user_id === user?.id)?.net_balance || 0;
  const isCreditor = myBalance > 0.009;
  const isDebtor = myBalance < -0.009;
  const isSettled = !isCreditor && !isDebtor;

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.24, ease: [0.16, 1, 0.3, 1] }}
      className="settlr-panel p-6 sm:p-7 relative overflow-hidden bg-white"
    >
      {/* Top Row: Group Title & Actions */}
      <div className="flex items-start justify-between gap-4 mb-6">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-neutral-900">
              {group.name}
            </h1>
            <span className="text-[11px] font-medium px-2 py-0.5 rounded-full bg-neutral-100 text-neutral-600 border border-neutral-200/60">
              v{group.ledger_version}
            </span>
          </div>
          <p className="text-xs text-neutral-500 mt-0.5 max-w-md">
            {group.description || 'Automated bilateral settlement and shared expense ledger.'}
          </p>
        </div>

        <div className="flex items-center gap-2 shrink-0">
          <motion.button
            whileHover={{ scale: 1.08 }}
            whileTap={{ scale: 0.92 }}
            type="button"
            onClick={() => setIsGroupSettingsOpen(true)}
            title="Group settings & members"
            className="p-2 rounded-xl bg-neutral-50 hover:bg-neutral-100 text-neutral-600 border border-neutral-200/70 transition-all cursor-pointer"
          >
            <Settings className="w-4 h-4" />
          </motion.button>
        </div>
      </div>

      {/* Centerpiece: Fluid Standing Display */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 p-5 rounded-2xl bg-neutral-50/80 border border-neutral-200/60">
        
        {/* Metric 1: My Standing */}
        <div className="md:col-span-2 flex flex-col justify-between">
          <span className="text-xs font-semibold text-neutral-500">
            Your Balance in this Group
          </span>

          <div className="flex items-baseline gap-3 my-2">
            <span className={`text-3xl sm:text-4xl font-extrabold num-tabular tracking-tight ${
              isCreditor ? 'text-emerald-600' : isDebtor ? 'text-rose-600' : 'text-neutral-900'
            }`}>
              {isCreditor && '+'}
              {isDebtor && '-'}
              {formatMoney(Math.abs(myBalance), group.currency)}
            </span>

            <span className={`inline-flex items-center gap-1 text-xs font-medium px-2.5 py-0.5 rounded-full border ${
              isSettled
                ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                : isCreditor
                ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                : 'bg-rose-50 text-rose-700 border-rose-200'
            }`}>
              {isSettled ? (
                <>
                  <CheckCircle2 className="w-3.5 h-3.5" />
                  <span>All settled up</span>
                </>
              ) : isCreditor ? (
                <>
                  <ArrowUpRight className="w-3.5 h-3.5" />
                  <span>You are owed</span>
                </>
              ) : (
                <>
                  <ArrowDownLeft className="w-3.5 h-3.5" />
                  <span>You owe money</span>
                </>
              )}
            </span>
          </div>

          <p className="text-xs text-neutral-500">
            {isSettled && 'Zero pending dues. All your group expenses are fully squared.'}
            {isCreditor && 'Members with pending balances will transfer funds to zero out accounts.'}
            {isDebtor && 'Use Settle Up to transfer your dues and square your accounts.'}
          </p>
        </div>

        {/* Quick Actions & Group Total */}
        <div className="flex flex-col justify-between md:border-l md:border-neutral-200/80 md:pl-5 pt-3 md:pt-0 border-t md:border-t-0 border-neutral-200/60">
          <div>
            <span className="text-[11px] font-medium text-neutral-400">Total Group Spending</span>
            <div className="text-xl font-bold text-neutral-900 num-tabular mt-0.5">
              {formatMoney(totalSpending, group.currency)}
            </div>
            <span className="text-[11px] text-neutral-500">
              {group.members?.length || 0} active members
            </span>
          </div>

          <div className="flex items-center gap-2 mt-4">
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.96 }}
              type="button"
              onClick={() => setIsAddExpenseOpen(true)}
              className="flex-1 inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white font-semibold text-xs shadow-sm transition-all cursor-pointer"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Add Expense</span>
            </motion.button>

            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.96 }}
              type="button"
              onClick={() => setIsRecordSettlementOpen(true)}
              className="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-white hover:bg-neutral-50 text-neutral-700 font-semibold text-xs border border-neutral-200/80 shadow-2xs transition-all cursor-pointer"
            >
              <CreditCard className="w-3.5 h-3.5 text-neutral-500" />
              <span>Settle Up</span>
            </motion.button>
          </div>
        </div>

      </div>
    </motion.div>
  );
};
