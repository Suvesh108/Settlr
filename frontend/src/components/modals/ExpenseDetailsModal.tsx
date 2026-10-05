import React, { useState } from 'react';
import { useAuthStore } from '../../store/authStore';
import { useUIStore } from '../../store/uiStore';
import { GroupMember } from '../../types';
import { formatMoney, formatDate } from '../../utils/formatters';
import { apiRequest } from '../../services/api';
import { X, RotateCcw, AlertTriangle, ShieldCheck, Tag, Calendar, User } from 'lucide-react';
import { AnimatedModal } from '../ui/AnimatedModal';
import { motion } from 'motion/react';

interface ExpenseDetailsModalProps {
  groupId: string;
  currency: string;
  members: GroupMember[];
}

export const ExpenseDetailsModal: React.FC<ExpenseDetailsModalProps> = ({
  groupId,
  currency,
  members,
}) => {
  const currentUserId = useAuthStore((state) => state.user?.id);
  const { selectedExpenseForDetails, setSelectedExpenseForDetails } = useUIStore();
  const [reversing, setReversing] = useState(false);

  if (!selectedExpenseForDetails) return null;

  const exp = selectedExpenseForDetails;
  const canReverse =
    !exp.is_reversal &&
    !exp.is_reversed &&
    (exp.paid_by === currentUserId || exp.created_by === currentUserId);

  const handleReverse = async () => {
    if (!confirm('Are you sure you want to reverse this expense? A ledger reversal entry will be created to balance the books.')) {
      return;
    }

    setReversing(true);
    try {
      await apiRequest(`/groups/${groupId}/expenses/${exp.id}/reverse`, {
        method: 'POST',
        useIdempotency: true,
      });
      setSelectedExpenseForDetails(null);
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Reversal failed');
    } finally {
      setReversing(false);
    }
  };

  const getMemberName = (userId: string) => {
    const m = members.find((mem) => mem.user_id === userId);
    return m ? m.name : 'Member';
  };

  return (
    <AnimatedModal
      isOpen={!!selectedExpenseForDetails}
      onClose={() => setSelectedExpenseForDetails(null)}
      maxWidth="max-w-md"
    >
      <div>
        {/* Header */}
        <div className="flex items-start justify-between pb-4 border-b border-neutral-100">
          <div>
            <div className="flex items-center gap-2">
              <h3 className="font-bold text-lg text-neutral-900 tracking-tight">
                {exp.description}
              </h3>
              {exp.is_reversed && (
                <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-rose-50 text-rose-700 border border-rose-200">
                  Reversed
                </span>
              )}
              {exp.is_reversal && (
                <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-purple-50 text-purple-700 border border-purple-200">
                  Reversal
                </span>
              )}
            </div>
            <p className="text-xs text-neutral-500 mt-0.5">
              Expense details & participant share breakdown
            </p>
          </div>
          <motion.button
            whileHover={{ scale: 1.1, rotate: 90 }}
            whileTap={{ scale: 0.9 }}
            onClick={() => setSelectedExpenseForDetails(null)}
            className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer rounded-full"
          >
            <X className="w-4 h-4" />
          </motion.button>
        </div>

        {/* Amount & Key Metrics */}
        <div className="my-5 p-4 rounded-xl bg-neutral-50 border border-neutral-200/80 flex items-baseline justify-between">
          <div>
            <span className="text-xs text-neutral-500 font-medium block">Total Paid</span>
            <span className="text-2xl font-bold text-neutral-900 tracking-tight">
              {formatMoney(exp.amount, currency)}
            </span>
          </div>
          <div className="text-right">
            <span className="text-xs text-neutral-500 font-medium block">Paid by</span>
            <span className="text-sm font-semibold text-neutral-800">
              {exp.payer_name || getMemberName(exp.paid_by)}
              {exp.paid_by === currentUserId && ' (You)'}
            </span>
          </div>
        </div>

        {/* Metadata info */}
        <div className="grid grid-cols-2 gap-2 text-xs text-neutral-600 mb-5">
          <div className="flex items-center gap-1.5 p-2 rounded-lg bg-neutral-50">
            <Calendar className="w-3.5 h-3.5 text-neutral-400" />
            <span>{formatDate(exp.expense_date || exp.created_at)}</span>
          </div>
          <div className="flex items-center gap-1.5 p-2 rounded-lg bg-neutral-50">
            <Tag className="w-3.5 h-3.5 text-neutral-400" />
            <span className="capitalize">{exp.category?.toLowerCase() || 'General'}</span>
          </div>
        </div>

        {/* Participant Share Breakdown */}
        <div className="mb-5">
          <div className="flex items-center justify-between text-xs font-semibold text-neutral-700 mb-2.5">
            <span>Participant Breakdown ({exp.participants?.length || 0})</span>
            <span className="text-neutral-400 font-normal">{exp.split_type} split</span>
          </div>

          <div className="divide-y divide-neutral-100 border border-neutral-200 rounded-xl overflow-hidden">
            {exp.participants?.map((p) => {
              const isCurrentUser = p.user_id === currentUserId;
              const name = getMemberName(p.user_id);

              return (
                <div
                  key={p.user_id}
                  className={`p-2.5 flex items-center justify-between text-xs ${
                    isCurrentUser ? 'bg-sky-50/50' : 'bg-white'
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <div className="w-6 h-6 rounded-full bg-neutral-100 border border-neutral-200 text-neutral-700 flex items-center justify-center font-bold text-[10px]">
                      {name.slice(0, 2).toUpperCase()}
                    </div>
                    <span className="font-medium text-neutral-800">
                      {name} {isCurrentUser && <strong className="text-sky-600">(You)</strong>}
                    </span>
                  </div>

                  <span className="font-semibold text-neutral-900">
                    {formatMoney(p.share_amount, currency)}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Reversal action or note */}
        {canReverse && (
          <motion.button
            whileHover={{ scale: 1.01 }}
            whileTap={{ scale: 0.98 }}
            onClick={handleReverse}
            disabled={reversing}
            className="w-full py-2.5 px-4 rounded-full bg-white hover:bg-rose-50 text-rose-600 border border-rose-200 font-medium text-xs flex items-center justify-center gap-1.5 transition-colors cursor-pointer disabled:opacity-50"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>{reversing ? 'Reversing...' : 'Reverse Expense (Undo)'}</span>
          </motion.button>
        )}

        {exp.is_reversed && (
          <div className="p-3 rounded-lg bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 shrink-0" />
            <span>This expense has been reversed. It remains in audit history with zero net balance effect.</span>
          </div>
        )}
      </div>
    </AnimatedModal>
  );
};
