import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { useUIStore } from '../store/uiStore';
import { useAuthStore } from '../store/authStore';
import { Group } from '../types';
import { formatMoney } from '../utils/formatters';
import { apiRequest } from '../services/api';
import { useQueryClient } from '@tanstack/react-query';
import confetti from 'canvas-confetti';
import { localDB, LocalPersonalExpense } from '../db/localDB';
import { 
  X, 
  CreditCard, 
  Users, 
  User, 
  Sparkles, 
  ChevronRight, 
  ChevronDown, 
  Check, 
  ArrowRight,
  ShieldAlert
} from 'lucide-react';
import { CustomSelect } from './ui/CustomSelect';

interface SmartSpendPopupProps {
  groups: Group[];
}

const PERSONAL_CATEGORIES = [
  { value: 'FOOD', label: 'Food & Groceries' },
  { value: 'TRANSPORT', label: 'Transport & Fuel' },
  { value: 'HOUSING', label: 'Housing & Utilities' },
  { value: 'ENTERTAINMENT', label: 'Entertainment' },
  { value: 'SHOPPING', label: 'Shopping & Personal' },
  { value: 'GENERAL', label: 'General / Other' },
];

const detectCategory = (merchantName: string): string => {
  const m = merchantName.toLowerCase();
  if (m.includes('uber') || m.includes('ola') || m.includes('rapido') || m.includes('metro') || m.includes('cab') || m.includes('ride') || m.includes('fuel') || m.includes('petrol') || m.includes('transport') || m.includes('auto')) {
    return 'TRANSPORT';
  }
  if (m.includes('zomato') || m.includes('swiggy') || m.includes('food') || m.includes('eat') || m.includes('cafe') || m.includes('coffee') || m.includes('tea') || m.includes('bistro') || m.includes('restaurant') || m.includes('starbucks') || m.includes('instamart') || m.includes('blinkit') || m.includes('zepto') || m.includes('grocery')) {
    return 'FOOD';
  }
  if (m.includes('amazon') || m.includes('flipkart') || m.includes('myntra') || m.includes('shopping') || m.includes('cloth') || m.includes('store') || m.includes('mart') || m.includes('zara') || m.includes('h&m')) {
    return 'SHOPPING';
  }
  if (m.includes('rent') || m.includes('electricity') || m.includes('water') || m.includes('wifi') || m.includes('broadband') || m.includes('utility') || m.includes('maintenance')) {
    return 'HOUSING';
  }
  if (m.includes('movie') || m.includes('cinema') || m.includes('pvr') || m.includes('netflix') || m.includes('hotstar') || m.includes('prime') || m.includes('spotify') || m.includes('concert')) {
    return 'ENTERTAINMENT';
  }
  return 'FOOD';
};

export const SmartSpendPopup: React.FC<SmartSpendPopupProps> = ({ groups }) => {
  const { smartTransactionPrompt, setSmartTransactionPrompt, setActiveGroupId, setCurrentTab } = useUIStore();
  const currentUserId = useAuthStore((state) => state.user?.id);
  const queryClient = useQueryClient();

  const [destination, setDestination] = useState<'group' | 'personal'>('group');
  const [personalCategory, setPersonalCategory] = useState<string>('FOOD');
  const [selectedGroupId, setSelectedGroupId] = useState<string>(
    groups.length > 0 ? groups[0].id : ''
  );
  const [isSaving, setIsSaving] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);

  useEffect(() => {
    if (smartTransactionPrompt?.merchant) {
      setPersonalCategory(detectCategory(smartTransactionPrompt.merchant));
    }
  }, [smartTransactionPrompt]);

  const amount = smartTransactionPrompt?.amount || 0;
  const merchant = smartTransactionPrompt?.merchant || '';
  const accountEnding = smartTransactionPrompt?.accountEnding || '';
  const currentGroup = groups.find((g) => g.id === selectedGroupId) || groups[0];

  const handleConfirm = async () => {
    setIsSaving(true);
    try {
      if (destination === 'personal') {
        const cat = personalCategory || detectCategory(merchant);
        const newRecord: LocalPersonalExpense = {
          id: 'pers_' + Date.now().toString(36) + Math.random().toString(36).substring(2, 6),
          description: merchant,
          amount: Math.round(amount * 100),
          category: cat,
          date: new Date().toISOString().split('T')[0],
          createdAt: Date.now(),
        };

        // 1. Save directly to Dexie localDB (powers PersonalStream via useLiveQuery)
        await localDB.personalExpenses.add(newRecord);

        // 2. Keep localStorage in sync for backward compatibility
        const storageKey = `personal_expenses_${currentUserId || 'default'}`;
        try {
          const raw = localStorage.getItem(storageKey);
          const existing = raw ? JSON.parse(raw) : [];
          localStorage.setItem(storageKey, JSON.stringify([newRecord, ...existing]));
        } catch (e) {
          console.warn('LocalStorage backup failed', e);
        }

        // 3. Switch to personal tab so the user sees their new entry immediately
        setCurrentTab('individual');
      } else if (currentGroup) {
        // Save to strict group with automatic debt netting
        const members = currentGroup.members || [];
        const activeMembers = members.filter((m) => m.status === 'ACTIVE');
        const participantCount = activeMembers.length || 1;
        const totalMinor = Math.round(amount * 100);
        const baseShare = Math.floor(totalMinor / participantCount);
        let remainder = totalMinor % participantCount;

        const participants = activeMembers.map((m) => {
          const share = baseShare + (remainder > 0 ? 1 : 0);
          if (remainder > 0) remainder--;
          return {
            user_id: m.user_id,
            share_amount: share,
          };
        });

        await apiRequest(`/groups/${currentGroup.id}/expenses`, {
          method: 'POST',
          useIdempotency: true,
          body: JSON.stringify({
            amount: totalMinor,
            description: merchant,
            category: detectCategory(merchant),
            paid_by: currentUserId,
            split_type: 'EQUAL',
            participants,
          }),
        });

        queryClient.invalidateQueries({ queryKey: ['expenses', currentGroup.id] });
        queryClient.invalidateQueries({ queryKey: ['balances', currentGroup.id] });
        queryClient.invalidateQueries({ queryKey: ['pairwise', currentGroup.id] });
        queryClient.invalidateQueries({ queryKey: ['recommended', currentGroup.id] });
        setActiveGroupId(currentGroup.id);
        setCurrentTab('group');
      }

      setSavedSuccess(true);
      confetti({
        particleCount: 60,
        spread: 60,
        origin: { y: 0.8 },
        colors: ['#0ea5e9', '#10b981', '#f59e0b'],
      });
      setTimeout(() => {
        setSavedSuccess(false);
        setSmartTransactionPrompt(null);
      }, 1400);
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Failed to record transaction');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <AnimatePresence>
      {smartTransactionPrompt && (
        <div className="fixed inset-0 z-50 pointer-events-none flex items-end sm:items-center justify-center p-0 sm:p-4">
          {/* Backdrop Blur */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={() => setSmartTransactionPrompt(null)}
            className="fixed inset-0 bg-neutral-900/40 backdrop-blur-xs pointer-events-auto cursor-pointer"
          />

          {/* Apple AirPods / Dynamic Island Bouncy Card */}
          <motion.div
            initial={{ opacity: 0, y: 70, scale: 0.93 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 50, scale: 0.95 }}
            transition={{ type: 'spring', damping: 25, stiffness: 360, mass: 0.9 }}
            className="pointer-events-auto w-full max-w-sm bg-white/95 backdrop-blur-xl border border-neutral-200/90 shadow-2xl rounded-t-[32px] sm:rounded-[32px] p-6 sm:p-7 relative z-10"
          >
            {/* Dismiss Pill handle */}
            <div className="w-12 h-1.5 bg-neutral-200 rounded-full mx-auto mb-4 sm:hidden" />

            {/* Close Button */}
            <motion.button
              whileHover={{ scale: 1.1 }}
              whileTap={{ scale: 0.92 }}
              onClick={() => setSmartTransactionPrompt(null)}
              className="absolute top-5 right-5 w-7 h-7 rounded-full bg-neutral-100 hover:bg-neutral-200 flex items-center justify-center text-neutral-500 transition-colors cursor-pointer"
            >
              <X className="w-4 h-4" />
            </motion.button>

            {/* Card Header & Detected Badge */}
            <div className="text-center pt-1 mb-5">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-sky-50 border border-sky-100 text-sky-700 text-[11px] font-semibold mb-3 shadow-2xs">
                <Sparkles className="w-3.5 h-3.5 text-sky-500 animate-pulse" />
                <span>SMS Payment Detected</span>
              </div>

              <h3 className="text-2xl sm:text-3xl font-extrabold text-neutral-900 tracking-tight num-tabular">
                {formatMoney(Math.round(amount * 100), currentGroup?.currency || 'INR')}
              </h3>
              <p className="text-xs text-neutral-500 font-medium mt-1 truncate px-4">
                {merchant} {accountEnding ? `(A/c ····${accountEnding})` : ''}
              </p>
            </div>

            {/* Destination Selection: Personal vs Group */}
            <div className="space-y-3 mb-5">
              <span className="block text-[11px] font-bold text-neutral-400 uppercase tracking-wider text-center">
                Where to allocate this spending?
              </span>

              <div className="grid grid-cols-2 gap-2.5 p-1 bg-neutral-100/80 rounded-2xl border border-neutral-200/60">
                {/* Option 1: Group Split */}
                <motion.button
                  whileTap={{ scale: 0.95 }}
                  type="button"
                  onClick={() => setDestination('group')}
                  className={`flex flex-col items-center justify-center p-3 rounded-xl transition-all cursor-pointer ${
                    destination === 'group'
                      ? 'bg-white text-neutral-900 shadow-sm border border-neutral-200/80 font-bold'
                      : 'text-neutral-500 hover:text-neutral-900 font-medium'
                  }`}
                >
                  <Users className={`w-5 h-5 mb-1 ${destination === 'group' ? 'text-sky-500' : 'text-neutral-400'}`} />
                  <span className="text-xs">Group</span>
                  <span className="text-[10px] text-neutral-400 font-normal">Auto-net debts</span>
                </motion.button>

                {/* Option 2: Personal Spend */}
                <motion.button
                  whileTap={{ scale: 0.95 }}
                  type="button"
                  onClick={() => setDestination('personal')}
                  className={`flex flex-col items-center justify-center p-3 rounded-xl transition-all cursor-pointer ${
                    destination === 'personal'
                      ? 'bg-white text-neutral-900 shadow-sm border border-neutral-200/80 font-bold'
                      : 'text-neutral-500 hover:text-neutral-900 font-medium'
                  }`}
                >
                  <User className={`w-5 h-5 mb-1 ${destination === 'personal' ? 'text-emerald-500' : 'text-neutral-400'}`} />
                  <span className="text-xs">Personal</span>
                  <span className="text-[10px] text-neutral-400 font-normal">100% mine</span>
                </motion.button>
              </div>

              {/* If Group chosen, choose which group with custom clean dropdown UI */}
              {destination === 'group' && groups.length > 0 && (
                <div className="p-3.5 rounded-2xl bg-white border border-neutral-200/90 shadow-2xs">
                  <label className="block text-[10px] font-bold text-neutral-400 uppercase tracking-wider mb-1.5">
                    Select Active Group
                  </label>
                  <CustomSelect
                    value={selectedGroupId}
                    onChange={setSelectedGroupId}
                    options={groups.map((g) => ({
                      value: g.id,
                      label: g.name,
                      sublabel: `${g.members?.length || 0} members`,
                    }))}
                  />
                </div>
              )}

              {/* If Personal chosen, allow selecting or confirming category */}
              {destination === 'personal' && (
                <div className="p-3.5 rounded-2xl bg-white border border-neutral-200/90 shadow-2xs">
                  <label className="block text-[10px] font-bold text-neutral-400 uppercase tracking-wider mb-1.5">
                    Expense Category
                  </label>
                  <CustomSelect
                    value={personalCategory}
                    onChange={setPersonalCategory}
                    options={PERSONAL_CATEGORIES}
                  />
                </div>
              )}
            </div>

            {/* Action Confirm Button */}
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.96 }}
              onClick={handleConfirm}
              disabled={isSaving || savedSuccess}
              className={`w-full py-3.5 px-4 rounded-full font-bold text-sm shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer ${
                savedSuccess
                  ? 'bg-emerald-500 text-white'
                  : 'bg-neutral-900 hover:bg-neutral-800 text-white shadow-neutral-900/20'
              }`}
            >
              {savedSuccess ? (
                <>
                  <Check className="w-4 h-4" />
                  <span>Logged & Synced!</span>
                </>
              ) : isSaving ? (
                <span>Logging...</span>
              ) : (
                <>
                  <span>Log {destination === 'group' ? 'to Group' : 'to Personal'}</span>
                  <ArrowRight className="w-4 h-4 opacity-75" />
                </>
              )}
            </motion.button>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};
