import React, { useState } from 'react';
import { motion } from 'motion/react';
import { useAuthStore } from '../../store/authStore';
import { useUIStore } from '../../store/uiStore';
import { UserBalance, RecommendedTransfer, Settlement } from '../../types';
import { formatMoney } from '../../utils/formatters';
import { apiRequest } from '../../services/api';
import { 
  ArrowRight, 
  Check, 
  Clock, 
  Send
} from 'lucide-react';

interface BilateralDebtMatrixProps {
  groupId: string;
  currency: string;
  creatorId?: string;
  balances: UserBalance[];
  transfers: RecommendedTransfer[];
  settlements: Settlement[];
}

export const BilateralDebtMatrix: React.FC<BilateralDebtMatrixProps> = ({
  groupId,
  currency,
  creatorId,
  balances = [],
  transfers = [],
  settlements = [],
}) => {
  const currentUserId = useAuthStore((state) => state.user?.id);
  const { setSelectedPairwiseUser, setIsRecordSettlementOpen } = useUIStore();
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const pendingSettlements = settlements.filter((s) => s.status === 'PAYMENT_RECORDED');

  const handleConfirm = async (settlementId: string) => {
    setActionLoading(settlementId);
    try {
      await apiRequest(`/groups/${groupId}/settlements/${settlementId}/confirm`, {
        method: 'POST',
        useIdempotency: true,
      });
      window.location.reload();
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Confirmation failed');
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <div className="space-y-6">
      {/* Pending Confirmations if any */}
      {pendingSettlements.length > 0 && (
        <div className="p-4 rounded-2xl bg-amber-50/70 border border-amber-200/80">
          <div className="flex items-center gap-2 mb-3">
            <Clock className="w-4 h-4 text-amber-700" />
            <span className="text-xs font-bold text-amber-900 uppercase tracking-wider">
              Pending Settlements ({pendingSettlements.length})
            </span>
          </div>

          <div className="space-y-2">
            {pendingSettlements.map((s) => {
              const isReceiver = s.to_user === currentUserId;
              return (
                <div 
                  key={s.id}
                  className="flex items-center justify-between p-3 rounded-xl bg-white border border-amber-200/60 shadow-2xs"
                >
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-semibold text-neutral-800">
                      {s.from_user_name || 'Member'} paid {formatMoney(s.amount, currency)} to {s.to_user_name || 'Member'}
                    </span>
                  </div>

                  {isReceiver && (
                    <button
                      type="button"
                      disabled={actionLoading === s.id}
                      onClick={() => handleConfirm(s.id)}
                      className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold shadow-2xs cursor-pointer"
                    >
                      <Check className="w-3.5 h-3.5" />
                      <span>Confirm Received</span>
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Recommended Minimum Cashflow Transfers */}
      <div className="settlr-panel p-5 sm:p-6 bg-white">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-base font-bold text-neutral-900 tracking-tight">
              Settlement Plan
            </h2>
            <p className="text-xs text-neutral-500">
              Minimum cashflow transfers to balance all accounts to zero
            </p>
          </div>
        </div>

        {transfers.length === 0 ? (
          <div className="p-6 text-center rounded-xl bg-neutral-50/60 border border-neutral-100">
            <Check className="w-5 h-5 text-emerald-600 mx-auto mb-1.5" />
            <span className="text-xs font-semibold text-neutral-700">All accounts are settled</span>
            <p className="text-[11px] text-neutral-400 mt-0.5">No transfers are needed between group members.</p>
          </div>
        ) : (
          <div className="space-y-2.5">
            {transfers.map((t, idx) => {
              const isSender = t.from_user === currentUserId;
              const isReceiver = t.to_user === currentUserId;

              return (
                <div
                  key={idx}
                  className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-3.5 rounded-xl bg-neutral-50 hover:bg-neutral-100/70 border border-neutral-200/60 transition-all"
                >
                  <div className="flex items-center gap-2.5">
                    <div className="w-7 h-7 rounded-full bg-neutral-200 text-neutral-800 font-bold text-xs flex items-center justify-center">
                      {t.from_user_name?.slice(0, 2).toUpperCase() || 'FR'}
                    </div>

                    <span className="text-xs font-semibold text-neutral-900">
                      {t.from_user_name} {isSender ? '(You)' : ''}
                    </span>

                    <ArrowRight className="w-3.5 h-3.5 text-neutral-400" />

                    <div className="w-7 h-7 rounded-full bg-neutral-200 text-neutral-800 font-bold text-xs flex items-center justify-center">
                      {t.to_user_name?.slice(0, 2).toUpperCase() || 'TO'}
                    </div>

                    <span className="text-xs font-semibold text-neutral-900">
                      {t.to_user_name} {isReceiver ? '(You)' : ''}
                    </span>
                  </div>

                  <div className="flex items-center justify-between sm:justify-end gap-3 border-t sm:border-t-0 pt-2 sm:pt-0 border-neutral-200/50">
                    <span className="text-sm font-bold text-neutral-900 num-tabular">
                      {formatMoney(t.amount, currency)}
                    </span>

                    {isSender && (
                      <motion.button
                        whileHover={{ scale: 1.03 }}
                        whileTap={{ scale: 0.95 }}
                        type="button"
                        onClick={() => setIsRecordSettlementOpen(true, { toUserId: t.to_user, amount: t.amount })}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-neutral-900 hover:bg-neutral-800 text-white text-xs font-semibold transition-all cursor-pointer shadow-2xs"
                      >
                        <Send className="w-3 h-3" />
                        <span>Pay {t.to_user_name}</span>
                      </motion.button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Member Standings List */}
      <div className="settlr-panel p-5 sm:p-6 bg-white">
        <div className="mb-4">
          <h2 className="text-base font-bold text-neutral-900 tracking-tight">
            Member Standings
          </h2>
          <p className="text-xs text-neutral-500">
            Click any member to inspect mutual expenses & bilateral history
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {balances.map((m) => {
            const isMe = m.user_id === currentUserId;
            const isCreditor = m.net_balance > 0;
            const isDebtor = m.net_balance < 0;

            return (
              <motion.div
                key={m.user_id}
                whileHover={!isMe ? { y: -2, scale: 1.01 } : undefined}
                whileTap={!isMe ? { scale: 0.98 } : undefined}
                transition={{ duration: 0.16 }}
                onClick={() => {
                  if (!isMe) {
                    setSelectedPairwiseUser({ id: m.user_id, name: m.name });
                  }
                }}
                className={`p-3.5 rounded-xl border border-neutral-200/70 bg-neutral-50/60 hover:bg-white hover:border-neutral-300 transition-all ${
                  !isMe ? 'cursor-pointer hover:shadow-2xs' : ''
                }`}
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <div className="w-7 h-7 rounded-full bg-neutral-900 text-white font-bold text-xs flex items-center justify-center">
                      {m.name.slice(0, 2).toUpperCase()}
                    </div>
                    <span className="text-xs font-bold text-neutral-900 flex items-center gap-1">
                      <span>{m.name}</span>
                      {creatorId === m.user_id && (
                        <span 
                          title="Group Creator" 
                          className="text-amber-500 font-black text-sm select-none leading-none"
                        >
                          *
                        </span>
                      )}
                      {isMe && <span className="font-normal text-neutral-500 text-[11px]">(You)</span>}
                    </span>
                  </div>
                </div>

                <div className="flex items-baseline justify-between pt-1 border-t border-neutral-200/50">
                  <span className="text-[11px] text-neutral-500">Balance</span>
                  <span className={`text-xs font-bold num-tabular ${
                    isCreditor ? 'text-emerald-600' : isDebtor ? 'text-rose-600' : 'text-neutral-500'
                  }`}>
                    {isCreditor && '+'}
                    {isDebtor && '-'}
                    {formatMoney(Math.abs(m.net_balance), currency)}
                  </span>
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
