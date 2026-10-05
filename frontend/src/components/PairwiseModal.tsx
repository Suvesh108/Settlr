import React from 'react';
import { useAuthStore } from '../store/authStore';
import { useUIStore } from '../store/uiStore';
import { PairwiseDebt, Expense, Settlement } from '../types';
import { formatMoney, formatDate } from '../utils/formatters';
import { X, CreditCard, ArrowRight, ArrowDownLeft, ArrowUpRight, HelpCircle } from 'lucide-react';
import { AnimatedModal } from './ui/AnimatedModal';
import { motion } from 'motion/react';

interface PairwiseModalProps {
  pairwise?: PairwiseDebt[];
  currency: string;
  expenses?: Expense[];
  settlements?: Settlement[];
}

export const PairwiseModal: React.FC<PairwiseModalProps> = ({
  pairwise = [],
  currency,
  expenses = [],
  settlements = [],
}) => {
  const safePairwise = pairwise || [];
  const safeExpenses = expenses || [];
  const safeSettlements = settlements || [];

  const currentUserId = useAuthStore((state) => state.user?.id);
  const { selectedPairwiseUser, setSelectedPairwiseUser, setIsRecordSettlementOpen } = useUIStore();

  if (!selectedPairwiseUser || !currentUserId) return null;

  const otherId = selectedPairwiseUser.id;

  // 1. Find pairwise record between current user and selected user
  const record = safePairwise.find(
    (p) =>
      (p.user_a === currentUserId && p.user_b === otherId) ||
      (p.user_b === currentUserId && p.user_a === otherId)
  );

  let netDebtOwedToMe = 0;
  if (record) {
    if (record.user_a === currentUserId) {
      netDebtOwedToMe = record.net_debt; // >0 means other owes me
    } else {
      netDebtOwedToMe = -record.net_debt; // <0 means other owes me -> so -(-net) is positive
    }
  }

  const theyOweMe = netDebtOwedToMe > 0;
  const iOweThem = netDebtOwedToMe < 0;
  const isSettled = netDebtOwedToMe === 0;

  // 2. Compute bilateral breakdown from expenses
  // Case A: Other paid, current user participated
  let theyPaidForMe = 0;
  const expensesTheyPaid: { desc: string; date: string; myShare: number }[] = [];

  // Case B: Current user paid, other participated
  let iPaidForThem = 0;
  const expensesIPaid: { desc: string; date: string; theirShare: number }[] = [];

  for (const exp of safeExpenses) {
    if (exp.is_reversed || exp.is_reversal) continue;

    if (exp.paid_by === otherId) {
      const myPart = exp.participants?.find((p) => p.user_id === currentUserId);
      if (myPart) {
        theyPaidForMe += myPart.share_amount;
        expensesTheyPaid.push({
          desc: exp.description,
          date: exp.expense_date || exp.created_at,
          myShare: myPart.share_amount,
        });
      }
    } else if (exp.paid_by === currentUserId) {
      const theirPart = exp.participants?.find((p) => p.user_id === otherId);
      if (theirPart) {
        iPaidForThem += theirPart.share_amount;
        expensesIPaid.push({
          desc: exp.description,
          date: exp.expense_date || exp.created_at,
          theirShare: theirPart.share_amount,
        });
      }
    }
  }

  // Case C: Confirmed direct settlements
  let iPaidThemDirectly = 0;
  let theyPaidMeDirectly = 0;

  for (const s of safeSettlements) {
    if (s.status !== 'CONFIRMED') continue;
    if (s.from_user === currentUserId && s.to_user === otherId) {
      iPaidThemDirectly += s.amount;
    } else if (s.from_user === otherId && s.to_user === currentUserId) {
      theyPaidMeDirectly += s.amount;
    }
  }

  return (
    <AnimatedModal
      isOpen={!!selectedPairwiseUser}
      onClose={() => setSelectedPairwiseUser(null)}
      maxWidth="max-w-lg"
    >
      <div>
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
          <div>
            <h3 className="font-bold text-base text-neutral-900">
              You ↔ {selectedPairwiseUser.name}
            </h3>
            <p className="text-xs text-neutral-500">
              Transparent bilateral calculation breakdown
            </p>
          </div>
          <motion.button
            whileHover={{ scale: 1.1, rotate: 90 }}
            whileTap={{ scale: 0.9 }}
            onClick={() => setSelectedPairwiseUser(null)}
            className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer rounded-full"
          >
            <X className="w-4 h-4" />
          </motion.button>
        </div>

        {/* Net Standing Card */}
        <div className="my-5 text-center p-4 rounded-xl bg-neutral-50 border border-neutral-200">
          <span className="text-[11px] font-semibold text-neutral-500 uppercase tracking-wider block mb-1">
            Current Net Balance
          </span>
          <div
            className={`text-2xl font-bold tracking-tight ${
              theyOweMe ? 'text-emerald-600' : iOweThem ? 'text-rose-600' : 'text-neutral-800'
            }`}
          >
            {isSettled
              ? 'All Settled Up (₹0.00)'
              : theyOweMe
              ? `${selectedPairwiseUser.name} owes you ${formatMoney(netDebtOwedToMe, currency)}`
              : `You owe ${selectedPairwiseUser.name} ${formatMoney(Math.abs(netDebtOwedToMe), currency)}`}
          </div>
          <p className="text-xs text-neutral-400 mt-1">
            Continuous netting cancels opposite obligations automatically.
          </p>
        </div>

        {/* Detailed Explanation Grid */}
        <div className="grid grid-cols-2 gap-3 mb-5 text-xs">
          <div className="p-3 rounded-lg border border-neutral-200 bg-white">
            <span className="text-neutral-500 block mb-0.5">They covered for you:</span>
            <span className="font-bold text-neutral-900 text-sm">
              {formatMoney(theyPaidForMe, currency)}
            </span>
            {iPaidThemDirectly > 0 && (
              <span className="text-[11px] text-emerald-600 block mt-1">
                - {formatMoney(iPaidThemDirectly, currency)} direct paid
              </span>
            )}
          </div>
          <div className="p-3 rounded-lg border border-neutral-200 bg-white">
            <span className="text-neutral-500 block mb-0.5">You covered for them:</span>
            <span className="font-bold text-neutral-900 text-sm">
              {formatMoney(iPaidForThem, currency)}
            </span>
            {theyPaidMeDirectly > 0 && (
              <span className="text-[11px] text-emerald-600 block mt-1">
                - {formatMoney(theyPaidMeDirectly, currency)} direct paid
              </span>
            )}
          </div>
        </div>

        {/* Mutual Shared Expenses List */}
        <div className="mb-5 max-h-48 overflow-y-auto divide-y divide-neutral-100 border border-neutral-200 rounded-xl">
          {expensesTheyPaid.length === 0 && expensesIPaid.length === 0 ? (
            <div className="p-4 text-center text-xs text-neutral-400">
              No mutual shared expenses found between you two.
            </div>
          ) : (
            <>
              {expensesTheyPaid.map((item, i) => (
                <div key={`they-${i}`} className="p-2.5 flex items-center justify-between text-xs">
                  <div>
                    <span className="font-medium text-neutral-800 block truncate max-w-[200px]">
                      {item.desc}
                    </span>
                    <span className="text-[10px] text-neutral-400">
                      {selectedPairwiseUser.name} paid • {formatDate(item.date)}
                    </span>
                  </div>
                  <span className="font-semibold text-rose-600">
                    + You owe {formatMoney(item.myShare, currency)}
                  </span>
                </div>
              ))}
              {expensesIPaid.map((item, i) => (
                <div key={`i-${i}`} className="p-2.5 flex items-center justify-between text-xs">
                  <div>
                    <span className="font-medium text-neutral-800 block truncate max-w-[200px]">
                      {item.desc}
                    </span>
                    <span className="text-[10px] text-neutral-400">
                      You paid • {formatDate(item.date)}
                    </span>
                  </div>
                  <span className="font-semibold text-emerald-600">
                    + They owe {formatMoney(item.theirShare, currency)}
                  </span>
                </div>
              ))}
            </>
          )}
        </div>

        {/* Action Button */}
        {iOweThem && (
          <motion.button
            whileHover={{ scale: 1.01 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => {
              const amountOwed = Math.abs(netDebtOwedToMe);
              setSelectedPairwiseUser(null);
              setIsRecordSettlementOpen(true, {
                toUserId: selectedPairwiseUser.id,
                amount: amountOwed,
              });
            }}
            className="w-full py-2.5 px-4 rounded-full bg-sky-500 hover:bg-sky-600 text-white font-medium text-sm flex items-center justify-center gap-1.5 shadow-sm shadow-sky-500/25 transition-all cursor-pointer"
          >
            <CreditCard className="w-4 h-4" />
            <span>Pay {selectedPairwiseUser.name} {formatMoney(Math.abs(netDebtOwedToMe), currency)}</span>
          </motion.button>
        )}
      </div>
    </AnimatedModal>
  );
};
