import React, { useState } from 'react';
import { useAuthStore } from '../store/authStore';
import { useUIStore } from '../store/uiStore';
import { RecommendedTransfer, Settlement } from '../types';
import { formatMoney } from '../utils/formatters';
import { apiRequest } from '../services/api';
import { ArrowRight, CheckCircle2, XCircle, Clock, Check } from 'lucide-react';

interface RecommendedSettlementsProps {
  groupId: string;
  currency: string;
  transfers?: RecommendedTransfer[];
  settlements?: Settlement[];
}

export const RecommendedSettlements: React.FC<RecommendedSettlementsProps> = ({
  groupId,
  currency,
  transfers = [],
  settlements = [],
}) => {
  const safeTransfers = transfers || [];
  const safeSettlements = settlements || [];
  const currentUserId = useAuthStore((state) => state.user?.id);
  const { setIsRecordSettlementOpen } = useUIStore();
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const pendingSettlements = safeSettlements.filter((s) => s.status === 'PAYMENT_RECORDED');

  const handleConfirm = async (settlementId: string) => {
    setActionLoading(settlementId);
    try {
      await apiRequest(`/groups/${groupId}/settlements/${settlementId}/confirm`, {
        method: 'POST',
        useIdempotency: true,
      });
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Confirmation failed');
    } finally {
      setActionLoading(null);
    }
  };

  const handleCancel = async (settlementId: string) => {
    setActionLoading(settlementId);
    try {
      await apiRequest(`/groups/${groupId}/settlements/${settlementId}/cancel`, {
        method: 'POST',
        useIdempotency: true,
      });
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Cancellation failed');
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <div className="mb-8">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="text-lg font-bold text-neutral-900 tracking-tight">
            Settlement Plan
          </h2>
          <p className="text-xs text-neutral-500">
            Automated minimum cash flow algorithm to balance all accounts
          </p>
        </div>
      </div>

      {/* Pending Confirmations Section */}
      {pendingSettlements.length > 0 && (
        <div className="mb-4 p-4 rounded-xl bg-amber-50/60 border border-amber-200">
          <div className="flex items-center gap-2 mb-3">
            <Clock className="w-4 h-4 text-amber-700" />
            <span className="text-xs font-semibold uppercase tracking-wider text-amber-900">
              Pending Confirmations ({pendingSettlements.length})
            </span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {pendingSettlements.map((s) => {
              const isReceiver = s.to_user === currentUserId;
              const isSender = s.from_user === currentUserId;

              return (
                <div
                  key={s.id}
                  className="p-3.5 rounded-lg bg-white border border-amber-200/80 flex items-center justify-between gap-3 shadow-2xs"
                >
                  <div>
                    <div className="text-xs font-medium text-neutral-800 flex items-center gap-1.5">
                      <span>{s.from_user_name || 'Member'}</span>
                      <ArrowRight className="w-3 h-3 text-neutral-400" />
                      <span>{s.to_user_name || 'Member'}</span>
                    </div>
                    <span className="text-sm font-bold text-neutral-900 mt-0.5 block">
                      {formatMoney(s.amount, currency)}
                    </span>
                  </div>

                  <div className="flex items-center gap-2">
                    {isReceiver && (
                      <button
                        onClick={() => handleConfirm(s.id)}
                        disabled={actionLoading === s.id}
                        className="px-3 py-1 rounded-full bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-medium flex items-center gap-1 shadow-2xs transition-all cursor-pointer disabled:opacity-50"
                      >
                        <Check className="w-3 h-3" />
                        <span>Confirm Receipt</span>
                      </button>
                    )}
                    {(isReceiver || isSender) && (
                      <button
                        onClick={() => handleCancel(s.id)}
                        disabled={actionLoading === s.id}
                        className="p-1 rounded-full text-neutral-400 hover:text-rose-600 hover:bg-neutral-100 transition-colors cursor-pointer"
                        title="Cancel or Reject"
                      >
                        <XCircle className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Recommended Transfers */}
      {safeTransfers.length === 0 ? (
        <div className="saas-card py-6 px-4 text-center">
          <CheckCircle2 className="w-6 h-6 text-emerald-500 mx-auto mb-2" />
          <h3 className="text-sm font-semibold text-neutral-800 mb-0.5">All Balances Settled</h3>
          <p className="text-xs text-neutral-400">
            There are currently no outstanding debts requiring transfer.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {safeTransfers.map((t, idx) => {
            const isMeDebtor = t.from_user === currentUserId;

            return (
              <div
                key={idx}
                className="saas-card p-4 flex items-center justify-between gap-3"
              >
                <div>
                  <div className="text-xs font-medium text-neutral-700 flex items-center gap-1.5">
                    <span className={isMeDebtor ? 'font-bold text-neutral-900' : ''}>
                      {t.from_user_name}
                      {isMeDebtor && ' (You)'}
                    </span>
                    <ArrowRight className="w-3 h-3 text-neutral-400" />
                    <span>{t.to_user_name}</span>
                  </div>
                  <span className="text-base font-bold text-neutral-900 mt-1 block">
                    {formatMoney(t.amount, currency)}
                  </span>
                </div>

                {isMeDebtor && (
                  <button
                    onClick={() => setIsRecordSettlementOpen(true)}
                    className="px-4 py-1.5 rounded-full bg-sky-500 hover:bg-sky-600 text-white text-xs font-medium shadow-sm shadow-sky-500/20 transition-all cursor-pointer"
                  >
                    Pay
                  </button>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
