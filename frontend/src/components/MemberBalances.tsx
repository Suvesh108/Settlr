import React from 'react';
import { useAuthStore } from '../store/authStore';
import { useUIStore } from '../store/uiStore';
import { UserBalance } from '../types';
import { formatMoney } from '../utils/formatters';
import { ArrowRightLeft } from 'lucide-react';

interface MemberBalancesProps {
  balances?: UserBalance[];
  currency: string;
}

export const MemberBalances: React.FC<MemberBalancesProps> = ({ balances = [], currency }) => {
  const safeBalances = balances || [];
  const currentUserId = useAuthStore((state) => state.user?.id);
  const setSelectedPairwiseUser = useUIStore((state) => state.setSelectedPairwiseUser);

  return (
    <div className="mb-8">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1 mb-4">
        <div>
          <h2 className="text-lg font-bold text-neutral-900 tracking-tight">
            Member Balances
          </h2>
          <p className="text-xs text-neutral-500">
            Current standing across all active group expenses
          </p>
        </div>
        <span className="text-[11px] sm:text-xs text-neutral-400">
          Click member for pairwise breakdown
        </span>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5">
        {safeBalances.map((m) => {
          const isMe = m.user_id === currentUserId;
          const isCreditor = m.net_balance > 0;
          const isDebtor = m.net_balance < 0;

          return (
            <div
              key={m.user_id}
              onClick={() => {
                if (!isMe) {
                  setSelectedPairwiseUser({ id: m.user_id, name: m.name });
                }
              }}
              className={`saas-card p-4 flex flex-col justify-between ${
                !isMe ? 'cursor-pointer hover:border-neutral-400' : ''
              }`}
            >
              <div className="flex items-start justify-between gap-2 mb-3">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-full bg-neutral-100 border border-neutral-200 text-neutral-700 font-semibold text-xs flex items-center justify-center">
                    {m.name.slice(0, 2).toUpperCase()}
                  </div>
                  <div>
                    <h3 className="text-sm font-semibold text-neutral-900 flex items-center gap-1.5">
                      <span>{m.name}</span>
                      {isMe && (
                        <span className="text-[10px] font-medium px-1.5 py-0.2 rounded bg-neutral-100 text-neutral-600 border border-neutral-200">
                          You
                        </span>
                      )}
                    </h3>
                  </div>
                </div>

                {!isMe && (
                  <ArrowRightLeft className="w-3.5 h-3.5 text-neutral-400 hover:text-neutral-700 transition-colors mt-1" />
                )}
              </div>

              <div className="pt-2.5 border-t border-neutral-100 flex items-baseline justify-between text-xs">
                <span className="text-neutral-500 font-normal">
                  {isCreditor ? 'Gets back' : isDebtor ? 'Owes' : 'Settled'}
                </span>
                <span
                  className={`font-bold ${
                    isCreditor
                      ? 'text-emerald-600'
                      : isDebtor
                      ? 'text-rose-600'
                      : 'text-neutral-500'
                  }`}
                >
                  {formatMoney(m.net_balance, currency)}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
