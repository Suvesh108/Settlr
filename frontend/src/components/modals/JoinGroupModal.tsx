import React, { useState } from 'react';
import { motion } from 'motion/react';
import { useUIStore } from '../../store/uiStore';
import { apiRequest } from '../../services/api';
import { X, AlertCircle } from 'lucide-react';
import { useQueryClient } from '@tanstack/react-query';
import { AnimatedModal } from '../ui/AnimatedModal';

export const JoinGroupModal: React.FC = () => {
  const { isJoinGroupOpen, setIsJoinGroupOpen, setActiveGroupId } = useUIStore();
  const queryClient = useQueryClient();

  const [inviteCode, setInviteCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const res = await apiRequest<{ group_id: string }>('/groups/join', {
        method: 'POST',
        body: JSON.stringify({ invite_code: inviteCode.trim() }),
      });

      queryClient.invalidateQueries({ queryKey: ['groups'] });
      setActiveGroupId(res.group_id);
      setIsJoinGroupOpen(false);
      setInviteCode('');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Invalid invite code');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AnimatedModal
      isOpen={isJoinGroupOpen}
      onClose={() => setIsJoinGroupOpen(false)}
      maxWidth="max-w-md"
    >
      <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
        <div>
          <h3 className="font-bold text-base text-neutral-900">Join Group</h3>
          <p className="text-xs text-neutral-500">Enter invite code shared by a group member</p>
        </div>
        <motion.button
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.92 }}
          type="button"
          onClick={() => setIsJoinGroupOpen(false)}
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
            Group Invite Code
          </label>
          <input
            type="text"
            required
            value={inviteCode}
            onChange={(e) => setInviteCode(e.target.value)}
            placeholder="e.g. 8kP9z..."
            className="w-full px-3.5 py-2 text-sm rounded-lg border border-neutral-300 text-neutral-900 font-mono focus:outline-none focus:border-neutral-900 transition-colors uppercase tracking-wider"
          />
        </div>

        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.96 }}
          type="submit"
          disabled={loading}
          className="w-full mt-2 py-2.5 px-4 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white font-semibold text-xs shadow-sm transition-all cursor-pointer disabled:opacity-50"
        >
          {loading ? 'Joining...' : 'Join Group'}
        </motion.button>
      </form>
    </AnimatedModal>
  );
};
