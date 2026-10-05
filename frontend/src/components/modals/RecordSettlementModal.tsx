import React, { useState } from 'react';
import { motion } from 'motion/react';
import { useAuthStore } from '../../store/authStore';
import { useUIStore } from '../../store/uiStore';
import { GroupMember, PairwiseDebt } from '../../types';
import { apiRequest } from '../../services/api';
import { formatMoney } from '../../utils/formatters';
import { X, AlertCircle } from 'lucide-react';
import { CustomSelect } from '../ui/CustomSelect';
import { AnimatedModal } from '../ui/AnimatedModal';

interface RecordSettlementModalProps {
  groupId: string;
  currency: string;
  members: GroupMember[];
  pairwise: PairwiseDebt[];
}

export const RecordSettlementModal: React.FC<RecordSettlementModalProps> = ({
  groupId,
  currency,
  members,
  pairwise,
}) => {
  const currentUserId = useAuthStore((state) => state.user?.id);
  const { isRecordSettlementOpen, setIsRecordSettlementOpen, settlementPreFill } = useUIStore();

  const [toUser, setToUser] = useState(settlementPreFill?.toUserId || '');
  const [amountInput, setAmountInput] = useState(
    settlementPreFill?.amount ? (settlementPreFill.amount / 100).toFixed(2) : ''
  );
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  React.useEffect(() => {
    if (settlementPreFill) {
      if (settlementPreFill.toUserId) setToUser(settlementPreFill.toUserId);
      if (settlementPreFill.amount) setAmountInput((settlementPreFill.amount / 100).toFixed(2));
    }
  }, [settlementPreFill, isRecordSettlementOpen]);

  const creditors = members.filter((m) => m.user_id !== currentUserId && m.status === 'ACTIVE');

  let currentDebtToSelected = 0;
  if (toUser) {
    const record = pairwise.find(
      (p) =>
        (p.user_a === toUser && p.user_b === currentUserId) ||
        (p.user_b === toUser && p.user_a === currentUserId)
    );
    if (record) {
      if (record.user_a === toUser) {
        currentDebtToSelected = record.net_debt;
      } else {
        currentDebtToSelected = -record.net_debt;
      }
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    const amountPaise = Math.round((parseFloat(amountInput) || 0) * 100);
    if (!toUser || amountPaise <= 0) {
      setError('Please select a recipient and enter a valid positive payment amount.');
      return;
    }

    setLoading(true);
    try {
      await apiRequest(`/groups/${groupId}/settlements`, {
        method: 'POST',
        useIdempotency: true,
        body: JSON.stringify({
          to_user: toUser,
          amount: amountPaise,
        }),
      });

      setAmountInput('');
      setToUser('');
      setIsRecordSettlementOpen(false);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to record settlement');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AnimatedModal
      isOpen={isRecordSettlementOpen}
      onClose={() => setIsRecordSettlementOpen(false)}
      maxWidth="max-w-md"
    >
      <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
        <div>
          <h3 className="font-bold text-base text-neutral-900">Record Settlement</h3>
          <p className="text-xs text-neutral-500">Log an off-platform payment between members</p>
        </div>
        <motion.button
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.92 }}
          type="button"
          onClick={() => setIsRecordSettlementOpen(false)}
          className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer rounded-lg hover:bg-neutral-100"
        >
          <X className="w-4 h-4" />
        </motion.button>
      </div>

      {error && (
        <div className="mt-4 p-3 rounded-lg bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2 font-medium">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <form onSubmit={handleSubmit} className="mt-4 space-y-4">
        <div>
          <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
            Recipient
          </label>
          <CustomSelect
            value={toUser}
            onChange={(val) => {
              setToUser(val);
              setError(null);
            }}
            placeholder="Select a member to pay..."
            options={creditors.map((m) => ({
              value: m.user_id,
              label: m.name,
            }))}
          />
        </div>

        {toUser && (
          <div className="p-3 rounded-lg bg-neutral-50 border border-neutral-200 text-xs text-neutral-600 flex justify-between items-center">
            <span>Direct debt position:</span>
            <strong className="text-neutral-900 font-bold">
              {currentDebtToSelected > 0
                ? formatMoney(currentDebtToSelected, currency)
                : `${currency} 0.00 (No current debt)`}
            </strong>
          </div>
        )}

        <div>
          <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
            Amount Paid ({currency})
          </label>
          <input
            type="number"
            step="0.01"
            min="0.01"
            required
            value={amountInput}
            onChange={(e) => setAmountInput(e.target.value)}
            placeholder="0.00"
            className="w-full px-3.5 py-2 rounded-lg border border-neutral-300 text-neutral-900 font-bold text-base focus:outline-none focus:border-neutral-900 transition-colors"
          />
        </div>

        <div className="p-3 rounded-lg bg-amber-50 border border-amber-200 text-xs text-amber-800 leading-relaxed">
          Marked as Recorded until the recipient confirms receipt.
        </div>

        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.96 }}
          type="submit"
          disabled={loading}
          className="w-full mt-2 py-2.5 px-4 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white font-semibold text-xs shadow-sm transition-all cursor-pointer disabled:opacity-50"
        >
          {loading ? 'Recording Payment...' : 'Record Payment Claim'}
        </motion.button>
      </form>
    </AnimatedModal>
  );
};
