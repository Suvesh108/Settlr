import React, { useState, useEffect } from 'react';
import { useAuthStore } from '../../store/authStore';
import { useUIStore } from '../../store/uiStore';
import { GroupMember, SplitType } from '../../types';
import { apiRequest } from '../../services/api';
import { pushEncryptedEvent } from '../../services/syncMailbox';
import { X, Check, AlertCircle, ChevronDown } from 'lucide-react';
import { CustomSelect } from '../ui/CustomSelect';
import { AnimatedModal } from '../ui/AnimatedModal';
import { motion } from 'motion/react';

interface AddExpenseModalProps {
  groupId: string;
  currency: string;
  members: GroupMember[];
}

export const AddExpenseModal: React.FC<AddExpenseModalProps> = ({ groupId, currency, members }) => {
  const currentUserId = useAuthStore((state) => state.user?.id);
  const { isAddExpenseOpen, setIsAddExpenseOpen } = useUIStore();

  const [description, setDescription] = useState('');
  const [amountInput, setAmountInput] = useState('');
  const [category, setCategory] = useState('FOOD');
  const [paidBy, setPaidBy] = useState(currentUserId || '');
  const [splitType, setSplitType] = useState<SplitType>('EQUAL');

  const [selectedUsers, setSelectedUsers] = useState<string[]>([]);
  const [exactAmounts, setExactAmounts] = useState<Record<string, string>>({});
  const [percentages, setPercentages] = useState<Record<string, string>>({});
  const [shares, setShares] = useState<Record<string, string>>({});

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const activeMembers = members.filter((m) => m.status === 'ACTIVE');
  const availableMembers = activeMembers.length > 0 
    ? activeMembers 
    : (currentUserId ? [{ user_id: currentUserId, name: 'You', email: '', role: 'OWNER' as const, status: 'ACTIVE' as const, joined_at: '' }] : []);

  useEffect(() => {
    if (availableMembers.length > 0) {
      const activeMemberIds = availableMembers.map((m) => m.user_id);
      setSelectedUsers(activeMemberIds);
      if (!paidBy || !availableMembers.some((m) => m.user_id === paidBy)) {
        setPaidBy(currentUserId || activeMemberIds[0] || '');
      }
    }
  }, [members, currentUserId, isAddExpenseOpen]);

  const totalPaise = Math.round((parseFloat(amountInput) || 0) * 100);

  // When switching split type or total amount, pre-populate default split values if empty
  useEffect(() => {
    if (splitType === 'EXACT' && totalPaise > 0 && selectedUsers.length > 0) {
      const perPerson = ((totalPaise / selectedUsers.length) / 100).toFixed(2);
      const newExacts: Record<string, string> = { ...exactAmounts };
      let changed = false;
      selectedUsers.forEach((uid) => {
        if (!newExacts[uid]) {
          newExacts[uid] = perPerson;
          changed = true;
        }
      });
      if (changed) setExactAmounts(newExacts);
    } else if (splitType === 'PERCENTAGE' && selectedUsers.length > 0) {
      const perPersonPct = (100 / selectedUsers.length).toFixed(1);
      const newPcts: Record<string, string> = { ...percentages };
      let changed = false;
      selectedUsers.forEach((uid) => {
        if (!newPcts[uid]) {
          newPcts[uid] = perPersonPct;
          changed = true;
        }
      });
      if (changed) setPercentages(newPcts);
    } else if (splitType === 'SHARES' && selectedUsers.length > 0) {
      const newShares: Record<string, string> = { ...shares };
      let changed = false;
      selectedUsers.forEach((uid) => {
        if (!newShares[uid]) {
          newShares[uid] = '1';
          changed = true;
        }
      });
      if (changed) setShares(newShares);
    }
  }, [splitType, totalPaise, selectedUsers]);

  if (!isAddExpenseOpen) return null;

  const toggleUser = (userId: string) => {
    if (selectedUsers.includes(userId)) {
      if (selectedUsers.length > 1) {
        setSelectedUsers(selectedUsers.filter((id) => id !== userId));
      }
    } else {
      setSelectedUsers([...selectedUsers, userId]);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!description.trim() || totalPaise <= 0) {
      setError('Please provide a valid description and positive amount.');
      return;
    }

    if (selectedUsers.length === 0) {
      setError('Select at least one participant.');
      return;
    }

    let participantPayload = [];

    if (splitType === 'EQUAL') {
      participantPayload = selectedUsers.map((uid) => ({ user_id: uid }));
    } else if (splitType === 'EXACT') {
      let sum = 0;
      for (const uid of selectedUsers) {
        const amt = Math.round((parseFloat(exactAmounts[uid]) || 0) * 100);
        if (amt <= 0) {
          setError('Each participant must have a positive exact share.');
          return;
        }
        sum += amt;
        participantPayload.push({ user_id: uid, share_amount: amt });
      }
      if (sum !== totalPaise) {
        setError(`Exact shares sum (${currency} ${(sum / 100).toFixed(2)}) must match total (${currency} ${(totalPaise / 100).toFixed(2)}).`);
        return;
      }
    } else if (splitType === 'PERCENTAGE') {
      let bpsSum = 0;
      for (const uid of selectedUsers) {
        const pct = parseFloat(percentages[uid]) || 0;
        const bps = Math.round(pct * 100);
        if (bps <= 0) {
          setError('Each participant must have a positive percentage.');
          return;
        }
        bpsSum += bps;
        participantPayload.push({ user_id: uid, basis_points: bps });
      }
      if (bpsSum !== 10000) {
        setError(`Percentages must total exactly 100% (currently ${(bpsSum / 100).toFixed(2)}%).`);
        return;
      }
    } else if (splitType === 'SHARES') {
      for (const uid of selectedUsers) {
        const sh = parseInt(shares[uid], 10) || 1;
        if (sh <= 0) {
          setError('Shares must be positive integers.');
          return;
        }
        participantPayload.push({ user_id: uid, shares: sh });
      }
    }

    setLoading(true);
    try {
      const expenseBody = {
        description: description.trim(),
        amount: totalPaise,
        category,
        paid_by: paidBy,
        split_type: splitType,
        participants: participantPayload,
      };

      await apiRequest(`/groups/${groupId}/expenses`, {
        method: 'POST',
        useIdempotency: true,
        body: JSON.stringify(expenseBody),
      });

      // Push encrypted zero-knowledge envelope to the group sync mailbox
      pushEncryptedEvent(groupId, {
        type: 'EXPENSE_CREATED',
        data: expenseBody,
        timestamp: Date.now(),
      }).catch(() => {});

      setDescription('');
      setAmountInput('');
      setIsAddExpenseOpen(false);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create expense');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AnimatedModal
      isOpen={isAddExpenseOpen}
      onClose={() => setIsAddExpenseOpen(false)}
      maxWidth="max-w-lg"
    >
      <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
        <div>
          <h3 className="font-bold text-base text-neutral-900">Add Expense</h3>
          <p className="text-xs text-neutral-500">Record a new group transaction</p>
        </div>
        <motion.button
          whileHover={{ scale: 1.1, rotate: 90 }}
          whileTap={{ scale: 0.9 }}
          onClick={() => setIsAddExpenseOpen(false)}
          className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer rounded-full"
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
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-neutral-700 mb-1">
                Amount ({currency})
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
            <div>
              <label className="block text-xs font-semibold text-neutral-700 mb-1">
                Category
              </label>
              <CustomSelect
                value={category}
                onChange={setCategory}
                options={[
                  { value: 'FOOD', label: 'Food & Dining' },
                  { value: 'GROCERIES', label: 'Groceries' },
                  { value: 'RENT', label: 'Rent & Housing' },
                  { value: 'UTILITIES', label: 'Utilities & Wifi' },
                  { value: 'TRAVEL', label: 'Travel & Transport' },
                  { value: 'ENTERTAINMENT', label: 'Entertainment' },
                  { value: 'SHOPPING', label: 'Shopping' },
                  { value: 'GENERAL', label: 'General' },
                ]}
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-neutral-700 mb-1">
              Description
            </label>
            <input
              type="text"
              required
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="e.g. Team lunch"
              className="w-full px-3.5 py-2 rounded-xl border border-neutral-200 bg-neutral-50 hover:bg-neutral-100 text-neutral-900 text-sm focus:outline-none focus:bg-white focus:ring-2 focus:ring-neutral-900/10 transition-all"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-neutral-700 mb-1">
              Paid by
            </label>
            <CustomSelect
              value={paidBy}
              onChange={setPaidBy}
              options={availableMembers.map((m) => ({
                value: m.user_id,
                label: `${m.name}${m.user_id === currentUserId ? ' (You)' : ''}`,
              }))}
            />
          </div>

          {/* Participant checklist */}
          <div>
            <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
              Split between ({selectedUsers.length} selected)
            </label>
            <div className="flex flex-wrap gap-1.5">
              {availableMembers.map((m) => {
                const isSelected = selectedUsers.includes(m.user_id);
                return (
                  <button
                    type="button"
                    key={m.user_id}
                    onClick={() => toggleUser(m.user_id)}
                    className={`px-3 py-1 rounded-full text-xs font-medium flex items-center gap-1 transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-neutral-900 text-white shadow-2xs'
                        : 'bg-neutral-100 border border-neutral-200 text-neutral-600 hover:text-neutral-900'
                    }`}
                  >
                    {isSelected && <Check className="w-3 h-3 stroke-[2.5]" />}
                    <span>{m.name}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Split Mode Selector */}
          <div>
            <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
              Split method
            </label>
            <div className="grid grid-cols-4 gap-1 p-1 rounded-lg bg-neutral-100 border border-neutral-200">
              {(['EQUAL', 'EXACT', 'PERCENTAGE', 'SHARES'] as SplitType[]).map((mode) => (
                <button
                  type="button"
                  key={mode}
                  onClick={() => setSplitType(mode)}
                  className={`py-1 text-xs font-medium rounded-md transition-all cursor-pointer ${
                    splitType === mode
                      ? 'bg-white text-neutral-900 shadow-2xs font-semibold'
                      : 'text-neutral-500 hover:text-neutral-800'
                  }`}
                >
                  {mode.charAt(0) + mode.slice(1).toLowerCase()}
                </button>
              ))}
            </div>
          </div>

          {/* Dynamic Split Inputs */}
          {splitType === 'EQUAL' && (
            <div className="p-3 rounded-xl bg-neutral-50 border border-neutral-200/80 text-xs text-neutral-600 flex justify-between items-center">
              <span>Per person share ({selectedUsers.length} people):</span>
              <strong className="font-mono text-neutral-900 font-bold">
                {currency} {selectedUsers.length > 0 ? (((totalPaise / selectedUsers.length) || 0) / 100).toFixed(2) : '0.00'}
              </strong>
            </div>
          )}

          {splitType === 'EXACT' && (
            <div className="p-3 rounded-xl bg-neutral-50 border border-neutral-200/80 space-y-2.5">
              <div className="flex items-center justify-between text-xs pb-1 border-b border-neutral-200/60">
                <span className="font-semibold text-neutral-700">Specify exact amounts</span>
                <span className="font-mono text-[11px] text-neutral-500">
                  Total: {currency} {(totalPaise / 100).toFixed(2)}
                </span>
              </div>
              <div className="space-y-2 max-h-40 overflow-y-auto pr-1">
                {selectedUsers.map((uid) => {
                  const member = availableMembers.find((m) => m.user_id === uid);
                  return (
                    <div key={uid} className="flex items-center justify-between gap-3 text-xs">
                      <span className="text-neutral-700 font-medium truncate">{member?.name || 'User'}:</span>
                      <div className="flex items-center gap-1.5 shrink-0">
                        <span className="text-neutral-400 font-mono">{currency}</span>
                        <input
                          type="number"
                          step="0.01"
                          min="0"
                          value={exactAmounts[uid] || ''}
                          onChange={(e) => setExactAmounts({ ...exactAmounts, [uid]: e.target.value })}
                          placeholder="0.00"
                          className="w-24 px-2.5 py-1 rounded-lg border border-neutral-200 bg-white text-right text-neutral-900 font-medium focus:outline-none focus:border-neutral-900 focus:ring-1 focus:ring-neutral-900"
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {splitType === 'PERCENTAGE' && (
            <div className="p-3 rounded-xl bg-neutral-50 border border-neutral-200/80 space-y-2.5">
              <div className="flex items-center justify-between text-xs pb-1 border-b border-neutral-200/60">
                <span className="font-semibold text-neutral-700">Specify percentages</span>
                <span className="font-mono text-[11px] text-neutral-500">
                  Target: 100%
                </span>
              </div>
              <div className="space-y-2 max-h-40 overflow-y-auto pr-1">
                {selectedUsers.map((uid) => {
                  const member = availableMembers.find((m) => m.user_id === uid);
                  return (
                    <div key={uid} className="flex items-center justify-between gap-3 text-xs">
                      <span className="text-neutral-700 font-medium truncate">{member?.name || 'User'}:</span>
                      <div className="flex items-center gap-1 shrink-0">
                        <input
                          type="number"
                          step="0.1"
                          min="0"
                          max="100"
                          value={percentages[uid] || ''}
                          onChange={(e) => setPercentages({ ...percentages, [uid]: e.target.value })}
                          placeholder="0.0"
                          className="w-20 px-2 py-1 rounded-lg border border-neutral-200 bg-white text-right text-neutral-900 font-medium focus:outline-none focus:border-neutral-900 focus:ring-1 focus:ring-neutral-900"
                        />
                        <span className="text-neutral-500 font-mono">%</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {splitType === 'SHARES' && (
            <div className="p-3 rounded-xl bg-neutral-50 border border-neutral-200/80 space-y-2.5">
              <div className="flex items-center justify-between text-xs pb-1 border-b border-neutral-200/60">
                <span className="font-semibold text-neutral-700">Specify share weights</span>
                <span className="font-mono text-[11px] text-neutral-500">
                  e.g. 1, 2, 3 shares
                </span>
              </div>
              <div className="space-y-2 max-h-40 overflow-y-auto pr-1">
                {selectedUsers.map((uid) => {
                  const member = availableMembers.find((m) => m.user_id === uid);
                  return (
                    <div key={uid} className="flex items-center justify-between gap-3 text-xs">
                      <span className="text-neutral-700 font-medium truncate">{member?.name || 'User'}:</span>
                      <div className="flex items-center gap-1 shrink-0">
                        <input
                          type="number"
                          min="1"
                          value={shares[uid] || '1'}
                          onChange={(e) => setShares({ ...shares, [uid]: e.target.value })}
                          className="w-16 px-2 py-1 rounded-lg border border-neutral-200 bg-white text-right text-neutral-900 font-medium focus:outline-none focus:border-neutral-900 focus:ring-1 focus:ring-neutral-900"
                        />
                        <span className="text-neutral-400 text-[11px]">pts</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          <motion.button
            whileHover={{ scale: 1.01 }}
            whileTap={{ scale: 0.98 }}
            type="submit"
            disabled={loading}
            className="w-full mt-2 py-2.5 px-4 rounded-full bg-sky-500 hover:bg-sky-600 text-white font-medium text-sm shadow-sm shadow-sky-500/25 transition-all cursor-pointer disabled:opacity-50"
          >
            {loading ? 'Recording...' : 'Add Expense'}
          </motion.button>
        </form>
    </AnimatedModal>
  );
};
