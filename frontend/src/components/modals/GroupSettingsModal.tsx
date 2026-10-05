import React, { useState } from 'react';
import { useAuthStore } from '../../store/authStore';
import { useUIStore } from '../../store/uiStore';
import { Group, UserBalance } from '../../types';
import { apiRequest } from '../../services/api';
import { X, Copy, Check, LogOut, Shield, Users, Info, AlertCircle, Trash2 } from 'lucide-react';
import { AnimatedModal } from '../ui/AnimatedModal';
import { motion } from 'motion/react';

interface GroupSettingsModalProps {
  group: Group;
  balances: UserBalance[];
}

export const GroupSettingsModal: React.FC<GroupSettingsModalProps> = ({ group, balances }) => {
  const currentUserId = useAuthStore((state) => state.user?.id);
  const { isGroupSettingsOpen, setIsGroupSettingsOpen, setActiveGroupId } = useUIStore();
  const [copied, setCopied] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  if (!isGroupSettingsOpen) return null;

  // Creator check
  const isCreator = group.created_by === currentUserId;

  // Determine current user's balance
  const myBalance = balances.find((b) => b.user_id === currentUserId)?.net_balance || 0;
  const isSettled = Math.abs(myBalance) < 0.001;

  const handleCopyCode = () => {
    if (group.invite_code) {
      navigator.clipboard.writeText(group.invite_code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleDeleteGroup = async () => {
    if (!isCreator) {
      setErrorMsg('Only the person who created this group can delete it.');
      return;
    }

    if (!confirm(`Are you sure you want to permanently delete "${group.name}"? This will erase the group and its ledger for all members.`)) {
      return;
    }

    setDeleting(true);
    setErrorMsg(null);
    try {
      await apiRequest(`/groups/${group.id}`, {
        method: 'DELETE',
      });
      setIsGroupSettingsOpen(false);
      setActiveGroupId(null);
      window.location.reload();
    } catch (e: unknown) {
      setErrorMsg(e instanceof Error ? e.message : 'Failed to delete group');
    } finally {
      setDeleting(false);
    }
  };

  const handleLeaveGroup = async () => {
    if (!isSettled) {
      setErrorMsg('You cannot leave this group until your balance is completely settled (₹0.00).');
      return;
    }

    if (isCreator) {
      setErrorMsg('As the group creator, you cannot leave the group. You can delete the group once all settlements are complete.');
      return;
    }

    if (!confirm(`Are you sure you want to leave "${group.name}"? Your past transactions and settlement records will remain intact for the group.`)) {
      return;
    }

    setLeaving(true);
    setErrorMsg(null);
    try {
      await apiRequest(`/groups/${group.id}/leave`, {
        method: 'POST',
      });
      setIsGroupSettingsOpen(false);
      setActiveGroupId(null);
      window.location.reload();
    } catch (e: unknown) {
      setErrorMsg(e instanceof Error ? e.message : 'Failed to leave group');
    } finally {
      setLeaving(false);
    }
  };

  const members = group.members || [];

  return (
    <AnimatedModal
      isOpen={isGroupSettingsOpen}
      onClose={() => {
        setIsGroupSettingsOpen(false);
        setErrorMsg(null);
      }}
      maxWidth="max-w-lg"
    >
      <div>
        {/* Header */}
        <div className="flex items-start justify-between pb-4 border-b border-neutral-100">
          <div>
            <h3 className="font-bold text-lg text-neutral-900 tracking-tight">
              Group Settings & Members
            </h3>
            <p className="text-xs text-neutral-500 mt-0.5">
              Manage {group.name} members and preferences
            </p>
          </div>
          <motion.button
            whileHover={{ scale: 1.1, rotate: 90 }}
            whileTap={{ scale: 0.9 }}
            onClick={() => {
              setIsGroupSettingsOpen(false);
              setErrorMsg(null);
            }}
            className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer rounded-full"
          >
            <X className="w-4 h-4" />
          </motion.button>
        </div>

        {errorMsg && (
          <div className="mt-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0 text-rose-500" />
            <span>{errorMsg}</span>
          </div>
        )}

        <div className="my-5 space-y-5">
          {/* Group Details: Invite Code - Only accessible & shareable by group creator */}
          {isCreator ? (
            <div className="p-4 rounded-xl bg-neutral-50 border border-neutral-200/80">
              <div className="flex items-center justify-between">
                <div>
                  <span className="text-xs font-semibold text-neutral-500 uppercase tracking-wider block">
                    Invite Code (Creator Only)
                  </span>
                  <span className="font-mono text-base font-bold text-neutral-900 mt-0.5 block">
                    {group.invite_code}
                  </span>
                </div>
                <button
                  type="button"
                  onClick={handleCopyCode}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white border border-neutral-200 hover:bg-neutral-100 text-xs font-medium text-neutral-700 transition-all cursor-pointer shadow-2xs"
                >
                  {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5 text-neutral-500" />}
                  <span>{copied ? 'Copied' : 'Share Code'}</span>
                </button>
              </div>
              <p className="text-[11px] text-neutral-400 mt-2">
                As the group creator, share this code with friends or roommates to invite them.
              </p>
            </div>
          ) : (
            <div className="p-3.5 rounded-xl bg-neutral-50/60 border border-neutral-200/60 text-xs text-neutral-500 flex items-center gap-2">
              <Shield className="w-4 h-4 text-neutral-400 shrink-0" />
              <span>Only the creator of this group can view and distribute the join code.</span>
            </div>
          )}

          {/* Members List */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-neutral-700 uppercase tracking-wider flex items-center gap-1.5">
                <Users className="w-3.5 h-3.5 text-neutral-500" />
                Members ({members.length})
              </span>
              <span className="text-[11px] text-neutral-400">
                Ledger v{group.ledger_version}
              </span>
            </div>
            <div className="border border-neutral-200/80 rounded-xl divide-y divide-neutral-100 max-h-56 overflow-y-auto">
              {members.map((m) => {
                const isMe = m.user_id === currentUserId;
                const isMemberCreator = m.user_id === group.created_by;
                const memberBal = balances.find((b) => b.user_id === m.user_id)?.net_balance || 0;
                return (
                  <div key={m.user_id} className="p-3 flex items-center justify-between hover:bg-neutral-50/50 transition-colors">
                    <div className="flex items-center gap-2.5">
                      <div className="w-7 h-7 rounded-full bg-neutral-100 border border-neutral-200 text-neutral-700 flex items-center justify-center font-bold text-[10px]">
                        {m.name.slice(0, 2).toUpperCase()}
                      </div>
                      <div>
                        <div className="text-xs font-semibold text-neutral-900 flex items-center gap-1.5">
                          <span>{m.name}</span>
                          {isMemberCreator && (
                            <span 
                              title="Group Creator" 
                              className="text-amber-500 font-black text-sm select-none leading-none -ml-0.5"
                            >
                              *
                            </span>
                          )}
                          {isMe && (
                            <span className="text-[10px] font-medium bg-neutral-100 text-neutral-600 px-1.5 py-0.2 rounded">
                              You
                            </span>
                          )}
                          {isMemberCreator && (
                            <span className="text-[9px] font-medium bg-amber-50 text-amber-700 border border-amber-200/70 px-1.5 py-0.2 rounded">
                              Creator
                            </span>
                          )}
                        </div>
                        <span className="text-[11px] text-neutral-400 font-mono">
                          {isMemberCreator ? 'OWNER' : (m.role || 'MEMBER')}
                        </span>
                      </div>
                    </div>

                    <div className="text-right">
                      <span
                        className={`text-xs font-semibold block ${
                          memberBal > 0
                            ? 'text-emerald-600'
                            : memberBal < 0
                            ? 'text-rose-600'
                            : 'text-neutral-400'
                        }`}
                      >
                        {memberBal > 0
                          ? `+₹${memberBal.toFixed(2)}`
                          : memberBal < 0
                          ? `-₹${Math.abs(memberBal).toFixed(2)}`
                          : 'Settled'}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Group Exit / Delete Actions */}
          <div className="pt-4 border-t border-neutral-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="text-[11px] text-neutral-500 flex items-start gap-1.5 max-w-xs">
              <Info className="w-3.5 h-3.5 text-neutral-400 shrink-0 mt-0.5" />
              <span>
                {isCreator
                  ? 'As the creator, you can delete this entire group when all members are settled.'
                  : isSettled
                  ? 'Your balance is zero. Leaving the group preserves all previous transactions and settlement records.'
                  : 'You have outstanding debts or credits. Settle all balances before leaving.'}
              </span>
            </div>

            <div className="flex items-center gap-2">
              {isCreator ? (
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.97 }}
                  type="button"
                  onClick={handleDeleteGroup}
                  disabled={deleting}
                  className="inline-flex items-center justify-center gap-1.5 px-4 py-2 rounded-lg text-xs font-semibold bg-rose-600 hover:bg-rose-700 text-white transition-all cursor-pointer shadow-xs disabled:opacity-50"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  <span>{deleting ? 'Deleting...' : 'Delete Group'}</span>
                </motion.button>
              ) : (
                <motion.button
                  whileHover={{ scale: isSettled && !leaving ? 1.02 : 1 }}
                  whileTap={{ scale: isSettled && !leaving ? 0.97 : 1 }}
                  type="button"
                  onClick={handleLeaveGroup}
                  disabled={!isSettled || leaving}
                  className={`inline-flex items-center justify-center gap-1.5 px-4 py-2 rounded-lg text-xs font-medium transition-all ${
                    isSettled && !leaving
                      ? 'bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200 cursor-pointer'
                      : 'bg-neutral-100 text-neutral-400 border border-neutral-200 cursor-not-allowed opacity-60'
                  }`}
                >
                  <LogOut className="w-3.5 h-3.5" />
                  <span>{leaving ? 'Leaving...' : 'Leave Group'}</span>
                </motion.button>
              )}
            </div>
          </div>
        </div>
      </div>
    </AnimatedModal>
  );
};
