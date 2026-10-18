import React, { useState, useId } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { useAuthStore } from '../../store/authStore';
import { useUIStore } from '../../store/uiStore';
import { GroupMember } from '../../types';
import { apiRequest } from '../../services/api';
import { formatMoney } from '../../utils/formatters';
import { useQueryClient } from '@tanstack/react-query';
import { AnimatedModal } from '../ui/AnimatedModal';
import { CustomSelect } from '../ui/CustomSelect';
import { 
  Receipt, 
  Plus, 
  Trash2, 
  X, 
  Check, 
  AlertCircle, 
  Sparkles, 
  Divide, 
  Percent, 
  Users,
  FileText
} from 'lucide-react';

interface ReceiptItem {
  id: string;
  name: string;
  price: number; // in minor units (paise / cents)
  assignedUserIds: string[];
}

interface ReceiptItemizerModalProps {
  groupId: string;
  currency: string;
  members: GroupMember[];
}

const SAMPLE_BILLS: { label: string; items: { name: string; price: number }[]; tax: number; tip: number }[] = [
  {
    label: 'Restaurant Dinner (Food, Drinks, Tax & Tip)',
    items: [
      { name: 'Wood-fired Truffle Pizza', price: 65000 },
      { name: 'Creamy Penne Alfredo', price: 48000 },
      { name: 'Herb Garlic Bread with Dip', price: 22000 },
      { name: 'Artisanal Cold Brew (x2)', price: 36000 },
      { name: 'Belgian Chocolate Tiramisu', price: 32000 },
    ],
    tax: 10150, // 5% GST
    tip: 15000,
  },
  {
    label: 'Apartment Grocery & Supplies Run',
    items: [
      { name: 'Organic Almond Milk & Oats', price: 34000 },
      { name: 'Fresh Fruits & Veggies Basket', price: 58000 },
      { name: 'Olive Oil & Kitchen Spices', price: 72000 },
      { name: 'Laundry Pods & Paper Towels', price: 45000 },
    ],
    tax: 10450,
    tip: 0,
  },
  {
    label: 'Road Trip Snacks & Fuel',
    items: [
      { name: 'Highway Toll Fee', price: 28500 },
      { name: 'Energy Drinks & Protein Bars', price: 42000 },
      { name: 'Car Refueling at Gas Station', price: 250000 },
    ],
    tax: 0,
    tip: 0,
  },
];

export const ReceiptItemizerModal: React.FC<ReceiptItemizerModalProps> = ({
  groupId,
  currency,
  members,
}) => {
  const currentUserId = useAuthStore((state) => state.user?.id);
  const { isReceiptItemizerOpen, setIsReceiptItemizerOpen } = useUIStore();
  const queryClient = useQueryClient();

  const activeMembers = members.filter((m) => m.status === 'ACTIVE');
  const availableMembers = activeMembers.length > 0 
    ? activeMembers 
    : (currentUserId ? [{ user_id: currentUserId, name: 'You', email: '', role: 'OWNER' as const, status: 'ACTIVE' as const, joined_at: '' }] : []);

  const [billTitle, setBillTitle] = useState('Restaurant Bill Split');
  const [payerId, setPayerId] = useState(currentUserId || availableMembers[0]?.user_id || '');
  const [items, setItems] = useState<ReceiptItem[]>([
    { id: '1', name: 'Starter Platter', price: 45000, assignedUserIds: availableMembers.map((m) => m.user_id) },
    { id: '2', name: 'Main Course Specialties', price: 85000, assignedUserIds: availableMembers.map((m) => m.user_id) },
  ]);

  const [taxInput, setTaxInput] = useState('65.00'); // in major currency units
  const [tipInput, setTipInput] = useState('100.00');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // New item form state
  const [newItemName, setNewItemName] = useState('');
  const [newItemPrice, setNewItemPrice] = useState('');

  if (!isReceiptItemizerOpen) return null;

  const handleLoadSample = (index: number) => {
    const sample = SAMPLE_BILLS[index];
    if (!sample) return;

    const allMemberIds = availableMembers.map((m) => m.user_id);
    const newItems: ReceiptItem[] = sample.items.map((item, idx) => ({
      id: String(Date.now() + idx),
      name: item.name,
      price: item.price,
      assignedUserIds: allMemberIds,
    }));

    setItems(newItems);
    setTaxInput((sample.tax / 100).toFixed(2));
    setTipInput((sample.tip / 100).toFixed(2));
    setBillTitle(sample.label.split('(')[0].trim());
  };

  const handleAddItem = (e: React.FormEvent) => {
    e.preventDefault();
    const priceNum = parseFloat(newItemPrice);
    if (!newItemName.trim() || isNaN(priceNum) || priceNum <= 0) return;

    const newItem: ReceiptItem = {
      id: String(Date.now() + Math.random()),
      name: newItemName.trim(),
      price: Math.round(priceNum * 100),
      assignedUserIds: availableMembers.map((m) => m.user_id),
    };

    setItems([...items, newItem]);
    setNewItemName('');
    setNewItemPrice('');
  };

  const handleRemoveItem = (id: string) => {
    if (items.length <= 1) return;
    setItems(items.filter((i) => i.id !== id));
  };

  const toggleMemberOnItem = (itemId: string, userId: string) => {
    setItems(
      items.map((item) => {
        if (item.id !== itemId) return item;
        const exists = item.assignedUserIds.includes(userId);
        if (exists) {
          if (item.assignedUserIds.length === 1) return item; // At least one consumer
          return { ...item, assignedUserIds: item.assignedUserIds.filter((id) => id !== userId) };
        } else {
          return { ...item, assignedUserIds: [...item.assignedUserIds, userId] };
        }
      })
    );
  };

  // Proportional Tax & Tip Calculation Engine:
  // 1. Calculate raw item subtotal for each participant
  const rawSubtotals: Record<string, number> = {};
  availableMembers.forEach((m) => {
    rawSubtotals[m.user_id] = 0;
  });

  let itemsSubtotal = 0;
  items.forEach((item) => {
    itemsSubtotal += item.price;
    const splitCount = item.assignedUserIds.length;
    if (splitCount > 0) {
      const share = Math.floor(item.price / splitCount);
      const remainder = item.price % splitCount;
      item.assignedUserIds.forEach((uid, idx) => {
        const extra = idx < remainder ? 1 : 0;
        rawSubtotals[uid] = (rawSubtotals[uid] || 0) + share + extra;
      });
    }
  });

  const taxPaise = Math.max(0, Math.round((parseFloat(taxInput) || 0) * 100));
  const tipPaise = Math.max(0, Math.round((parseFloat(tipInput) || 0) * 100));
  const totalBillPaise = itemsSubtotal + taxPaise + tipPaise;

  // 2. Allocate tax & tip proportionally to each member based on their subtotal fraction
  const memberFinalShares: Record<string, number> = {};
  const memberTaxShares: Record<string, number> = {};
  const memberTipShares: Record<string, number> = {};

  if (itemsSubtotal > 0) {
    let allocatedTax = 0;
    let allocatedTip = 0;

    availableMembers.forEach((m, idx) => {
      const memberSub = rawSubtotals[m.user_id] || 0;
      if (idx === availableMembers.length - 1) {
        // Last member absorbs rounding remainder
        memberTaxShares[m.user_id] = taxPaise - allocatedTax;
        memberTipShares[m.user_id] = tipPaise - allocatedTip;
      } else {
        const mTax = Math.round((taxPaise * memberSub) / itemsSubtotal);
        const mTip = Math.round((tipPaise * memberSub) / itemsSubtotal);
        memberTaxShares[m.user_id] = mTax;
        memberTipShares[m.user_id] = mTip;
        allocatedTax += mTax;
        allocatedTip += mTip;
      }
      memberFinalShares[m.user_id] = memberSub + memberTaxShares[m.user_id] + memberTipShares[m.user_id];
    });
  } else {
    availableMembers.forEach((m) => {
      memberFinalShares[m.user_id] = 0;
    });
  }

  const handlePostExpense = async () => {
    setError(null);
    if (itemsSubtotal <= 0 || totalBillPaise <= 0) {
      setError('Please add at least one item with a valid price.');
      return;
    }

    const participants = availableMembers
      .map((m) => ({
        user_id: m.user_id,
        share_amount: memberFinalShares[m.user_id] || 0,
      }))
      .filter((p) => p.share_amount > 0);

    const shareSum = participants.reduce((sum, p) => sum + p.share_amount, 0);
    if (shareSum !== totalBillPaise) {
      setError(`Split shares sum (${formatMoney(shareSum, currency)}) does not match total bill (${formatMoney(totalBillPaise, currency)}).`);
      return;
    }

    setLoading(true);
    try {
      await apiRequest(`/groups/${groupId}/expenses`, {
        method: 'POST',
        useIdempotency: true,
        body: JSON.stringify({
          description: billTitle.trim() || 'Itemized Bill Split',
          amount: totalBillPaise,
          category: 'FOOD',
          paid_by: payerId,
          split_type: 'EXACT',
          participants,
        }),
      });

      queryClient.invalidateQueries({ queryKey: ['group', groupId] });
      queryClient.invalidateQueries({ queryKey: ['expenses', groupId] });
      queryClient.invalidateQueries({ queryKey: ['balances', groupId] });
      queryClient.invalidateQueries({ queryKey: ['pairwise', groupId] });
      queryClient.invalidateQueries({ queryKey: ['settlements', groupId] });
      queryClient.invalidateQueries({ queryKey: ['recommended', groupId] });
      queryClient.invalidateQueries({ queryKey: ['activity', groupId] });

      setIsReceiptItemizerOpen(false);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to post itemized expense');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AnimatedModal
      isOpen={isReceiptItemizerOpen}
      onClose={() => setIsReceiptItemizerOpen(false)}
      maxWidth="max-w-2xl"
    >
      <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl bg-neutral-900 text-white flex items-center justify-center shadow-2xs">
            <Receipt className="w-4 h-4" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="font-bold text-base text-neutral-900">Smart Receipt Itemizer</h3>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 uppercase tracking-wider">
                Splitwise Pro Tier
              </span>
            </div>
            <p className="text-xs text-neutral-500">
              Assign individual dishes & auto-distribute tax and tip proportionally
            </p>
          </div>
        </div>
        <motion.button
          whileHover={{ scale: 1.1, rotate: 90 }}
          whileTap={{ scale: 0.9 }}
          onClick={() => setIsReceiptItemizerOpen(false)}
          className="p-1 text-neutral-400 hover:text-neutral-700 transition-colors cursor-pointer rounded-full"
        >
          <X className="w-4 h-4" />
        </motion.button>
      </div>

      {error && (
        <div className="mt-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2 font-medium">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Preset Samples Selector */}
      <div className="mt-4 p-3 rounded-xl bg-neutral-50 border border-neutral-200/60 flex items-center justify-between gap-3">
        <span className="text-xs font-semibold text-neutral-600 flex items-center gap-1.5">
          <Sparkles className="w-3.5 h-3.5 text-amber-500" />
          <span>Quick Preset Template:</span>
        </span>
        <div className="flex items-center gap-1.5 overflow-x-auto">
          {SAMPLE_BILLS.map((sample, idx) => (
            <button
              key={idx}
              type="button"
              onClick={() => handleLoadSample(idx)}
              className="text-[11px] font-medium px-2.5 py-1 rounded-lg bg-white hover:bg-neutral-100 text-neutral-700 border border-neutral-200 shadow-2xs transition-all cursor-pointer whitespace-nowrap"
            >
              {sample.label.split('(')[0].trim()}
            </button>
          ))}
        </div>
      </div>

      {/* Bill Meta: Title & Payer */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-4">
        <div>
          <label className="block text-xs font-semibold text-neutral-700 mb-1">
            Bill Description
          </label>
          <input
            type="text"
            value={billTitle}
            onChange={(e) => setBillTitle(e.target.value)}
            className="w-full px-3 py-1.5 rounded-lg border border-neutral-300 text-xs font-semibold text-neutral-900 focus:outline-none focus:border-neutral-900"
            placeholder="e.g. Dinner at Olive Bistro"
          />
        </div>
        <div>
          <label className="block text-xs font-semibold text-neutral-700 mb-1">
            Paid By
          </label>
          <CustomSelect
            value={payerId}
            onChange={setPayerId}
            options={availableMembers.map((m) => ({
              value: m.user_id,
              label: m.user_id === currentUserId ? `${m.name} (You)` : m.name,
            }))}
          />
        </div>
      </div>

      {/* Item List */}
      <div className="mt-5">
        <div className="flex items-center justify-between mb-2">
          <label className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
            Line Items ({items.length})
          </label>
          <span className="text-[11px] text-neutral-400">
            Click names to toggle who shared each item
          </span>
        </div>

        <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
          {items.map((item) => (
            <div
              key={item.id}
              className="p-3 rounded-xl bg-white border border-neutral-200/80 shadow-2xs space-y-2"
            >
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-neutral-900">{item.name}</span>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-extrabold text-neutral-900 num-tabular">
                    {formatMoney(item.price, currency)}
                  </span>
                  {items.length > 1 && (
                    <button
                      type="button"
                      onClick={() => handleRemoveItem(item.id)}
                      className="text-neutral-400 hover:text-rose-600 transition-colors p-1"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
              </div>

              {/* Members who ate/shared this item */}
              <div className="flex items-center gap-1.5 flex-wrap">
                {availableMembers.map((m) => {
                  const isAssigned = item.assignedUserIds.includes(m.user_id);
                  return (
                    <button
                      key={m.user_id}
                      type="button"
                      onClick={() => toggleMemberOnItem(item.id, m.user_id)}
                      className={`text-[11px] px-2 py-0.5 rounded-md font-medium transition-all cursor-pointer border ${
                        isAssigned
                          ? 'bg-neutral-900 text-white border-neutral-900 shadow-2xs'
                          : 'bg-neutral-50 text-neutral-500 border-neutral-200 hover:border-neutral-300'
                      }`}
                    >
                      {m.name}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>

        {/* Add Item Form */}
        <form onSubmit={handleAddItem} className="mt-3 flex items-center gap-2">
          <input
            type="text"
            placeholder="Add dish or item..."
            value={newItemName}
            onChange={(e) => setNewItemName(e.target.value)}
            className="flex-1 px-3 py-1.5 rounded-lg border border-neutral-300 text-xs text-neutral-900 focus:outline-none focus:border-neutral-900"
          />
          <input
            type="number"
            step="0.01"
            placeholder="0.00"
            value={newItemPrice}
            onChange={(e) => setNewItemPrice(e.target.value)}
            className="w-24 px-3 py-1.5 rounded-lg border border-neutral-300 text-xs font-bold text-neutral-900 focus:outline-none focus:border-neutral-900"
          />
          <button
            type="submit"
            className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-neutral-900 hover:bg-neutral-800 text-white text-xs font-semibold cursor-pointer shadow-2xs"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Add</span>
          </button>
        </form>
      </div>

      {/* Tax & Tip Distribution Section */}
      <div className="mt-5 p-3.5 rounded-xl bg-neutral-50 border border-neutral-200/60">
        <div className="grid grid-cols-2 gap-3 mb-2">
          <div>
            <label className="block text-[11px] font-semibold text-neutral-600 mb-1">
              Taxes / GST ({currency})
            </label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={taxInput}
              onChange={(e) => setTaxInput(e.target.value)}
              className="w-full px-3 py-1.5 rounded-lg border border-neutral-300 text-xs font-bold text-neutral-900 focus:outline-none focus:border-neutral-900 bg-white"
            />
          </div>
          <div>
            <label className="block text-[11px] font-semibold text-neutral-600 mb-1">
              Tip / Service Charge ({currency})
            </label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={tipInput}
              onChange={(e) => setTipInput(e.target.value)}
              className="w-full px-3 py-1.5 rounded-lg border border-neutral-300 text-xs font-bold text-neutral-900 focus:outline-none focus:border-neutral-900 bg-white"
            />
          </div>
        </div>
        <p className="text-[10px] text-neutral-500">
          * Taxes and tips are distributed proportionally according to each member&apos;s subtotal fraction.
        </p>
      </div>

      {/* Final Per-Person Breakdown Preview */}
      <div className="mt-5 border-t border-neutral-100 pt-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
            Calculated Per-Member Final Dues
          </span>
          <span className="text-xs font-bold text-neutral-900">
            Total: {formatMoney(totalBillPaise, currency)}
          </span>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
          {availableMembers.map((m) => {
            const finalAmt = memberFinalShares[m.user_id] || 0;
            const sub = rawSubtotals[m.user_id] || 0;
            return (
              <div
                key={m.user_id}
                className="p-2.5 rounded-lg bg-neutral-100/70 border border-neutral-200/60"
              >
                <div className="text-[11px] font-semibold text-neutral-700 truncate">{m.name}</div>
                <div className="text-xs font-extrabold text-neutral-900 num-tabular mt-0.5">
                  {formatMoney(finalAmt, currency)}
                </div>
                <div className="text-[9px] text-neutral-500">
                  Items: {formatMoney(sub, currency)}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Action Footer */}
      <div className="mt-6 flex items-center justify-end gap-2.5 border-t border-neutral-100 pt-4">
        <button
          type="button"
          onClick={() => setIsReceiptItemizerOpen(false)}
          className="px-4 py-2 rounded-xl text-neutral-600 hover:bg-neutral-100 text-xs font-semibold cursor-pointer"
        >
          Cancel
        </button>
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.97 }}
          type="button"
          disabled={loading || totalBillPaise <= 0}
          onClick={handlePostExpense}
          className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white text-xs font-semibold shadow-sm transition-all cursor-pointer disabled:opacity-50"
        >
          <Check className="w-3.5 h-3.5" />
          <span>{loading ? 'Posting Ledger...' : 'Post to Group Ledger'}</span>
        </motion.button>
      </div>
    </AnimatedModal>
  );
};
