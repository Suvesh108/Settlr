import React from 'react';
import { ActivityItem } from '../types';
import { formatDate } from '../utils/formatters';

interface ActivityFeedProps {
  activity?: ActivityItem[];
}

export const ActivityFeed: React.FC<ActivityFeedProps> = ({ activity = [] }) => {
  const safeActivity = activity || [];

  return (
    <div className="saas-card p-5">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-base font-bold text-neutral-900 tracking-tight">
          Audit Activity
        </h2>
        <span className="flex items-center gap-1.5 text-[11px] font-medium text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
          Live
        </span>
      </div>

      {safeActivity.length === 0 ? (
        <div className="py-8 text-center text-xs text-neutral-400">
          No ledger activities recorded yet.
        </div>
      ) : (
        <div className="space-y-3.5">
          {safeActivity.slice(0, 10).map((item) => (
            <div key={item.id} className="text-xs">
              <p className="text-neutral-700 leading-relaxed">
                <span className="font-semibold text-neutral-900">{item.actor_name}</span>{' '}
                {item.summary}
              </p>
              <span className="text-[11px] text-neutral-400 block mt-0.5">
                {formatDate(item.created_at)}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
