import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { QueryClient, QueryClientProvider, useQuery } from '@tanstack/react-query';
import { useAuthStore } from './store/authStore';
import { useUIStore } from './store/uiStore';
import { apiRequest } from './services/api';
import { Group, Expense, UserBalance, PairwiseDebt, RecommendedTransfer, Settlement, ActivityItem } from './types';
import { useGroupSync } from './hooks/useGroupSync';

import { OnboardingScreen } from './components/OnboardingScreen';
import { IslandHeader } from './components/ui/IslandHeader';
import { NetStandingCard } from './components/ui/NetStandingCard';
import { BilateralDebtMatrix } from './components/ui/BilateralDebtMatrix';
import { TransactionTable } from './components/ui/TransactionTable';
import { PersonalStream } from './components/ui/PersonalStream';
import { HapticDock } from './components/ui/HapticDock';
import { ActivityFeed } from './components/ActivityFeed';
import { PairwiseModal } from './components/PairwiseModal';

import { AddExpenseModal } from './components/modals/AddExpenseModal';
import { RecordSettlementModal } from './components/modals/RecordSettlementModal';
import { CreateGroupModal } from './components/modals/CreateGroupModal';
import { JoinGroupModal } from './components/modals/JoinGroupModal';
import { ExpenseDetailsModal } from './components/modals/ExpenseDetailsModal';
import { GroupSettingsModal } from './components/modals/GroupSettingsModal';
import { SmartSpendPopup } from './components/SmartSpendPopup';
import { Plus, UserPlus, ArrowRight } from 'lucide-react';
import logoImg from './assets/logo.png';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 30, // 30 seconds fresh cache
      refetchOnWindowFocus: true, // Auto-refresh when user switches back to app
      refetchOnReconnect: true,   // Catch up immediately when device reconnects to internet
      retry: 2,
    },
  },
});

const Dashboard: React.FC = () => {
  const token = useAuthStore((state) => state.token);
  const { 
    currentTab, 
    activeGroupId, 
    setActiveGroupId, 
    setIsCreateGroupOpen, 
    setIsJoinGroupOpen,
    setIsAddExpenseOpen
  } = useUIStore();

  // 1. Fetch user's active groups
  const { data: rawGroups } = useQuery<Group[]>({
    queryKey: ['groups'],
    queryFn: () => apiRequest<Group[]>('/groups'),
    enabled: !!token,
  });
  const groups = rawGroups || [];

  // Ensure activeGroupId is valid
  useEffect(() => {
    if (groups.length > 0) {
      const exists = groups.some((g) => g.id === activeGroupId);
      if (!activeGroupId || !exists) {
        setActiveGroupId(groups[0].id);
      }
    } else {
      setActiveGroupId(null);
    }
  }, [groups, activeGroupId, setActiveGroupId]);

  // 1b. Fetch active group details with members
  const { data: activeGroupDetails } = useQuery<Group>({
    queryKey: ['group', activeGroupId],
    queryFn: () => apiRequest<Group>(`/groups/${activeGroupId}`),
    enabled: !!activeGroupId,
  });

  const activeGroup = activeGroupDetails || groups.find((g) => g.id === activeGroupId);

  // 2. Real-time SSE Sync for collaborative ledger changes
  useGroupSync(activeGroupId);

  // 3. Fetch balances
  const { data: balancesData } = useQuery<{ balances: UserBalance[] }>({
    queryKey: ['balances', activeGroupId],
    queryFn: () => apiRequest<{ balances: UserBalance[] }>(`/groups/${activeGroupId}/balances`),
    enabled: !!activeGroupId,
  });

  // 4. Fetch pairwise debts
  const { data: pairwiseData } = useQuery<{ pairwise: PairwiseDebt[] }>({
    queryKey: ['pairwise', activeGroupId],
    queryFn: () => apiRequest<{ pairwise: PairwiseDebt[] }>(`/groups/${activeGroupId}/balances/pairwise`),
    enabled: !!activeGroupId,
  });

  // 5. Fetch recommended settlements
  const { data: recommendedData } = useQuery<{ transfers: RecommendedTransfer[] }>({
    queryKey: ['recommended', activeGroupId],
    queryFn: () => apiRequest<{ transfers: RecommendedTransfer[] }>(`/groups/${activeGroupId}/settlements/recommended`),
    enabled: !!activeGroupId,
  });

  // 6. Fetch expenses
  const { data: rawExpenses } = useQuery<Expense[]>({
    queryKey: ['expenses', activeGroupId],
    queryFn: () => apiRequest<Expense[]>(`/groups/${activeGroupId}/expenses`),
    enabled: !!activeGroupId,
  });
  const expenses = rawExpenses || [];

  // 7. Fetch settlements
  const { data: rawSettlements } = useQuery<Settlement[]>({
    queryKey: ['settlements', activeGroupId],
    queryFn: () => apiRequest<Settlement[]>(`/groups/${activeGroupId}/settlements`),
    enabled: !!activeGroupId,
  });
  const settlements = rawSettlements || [];

  // 8. Fetch activity
  const { data: rawActivity } = useQuery<ActivityItem[]>({
    queryKey: ['activity', activeGroupId],
    queryFn: () => apiRequest<ActivityItem[]>(`/groups/${activeGroupId}/activity`),
    enabled: !!activeGroupId,
  });
  const activity = rawActivity || [];

  const balances = balancesData?.balances || [];
  const pairwise = pairwiseData?.pairwise || [];
  const transfers = recommendedData?.transfers || [];
  const members = activeGroup?.members || [];

  const totalSpending = expenses
    .filter((e) => !e.is_reversed && !e.is_reversal)
    .reduce((sum, e) => sum + e.amount, 0);

  const [activeMobileTab, setActiveMobileTab] = useState<'overview' | 'expenses' | 'settlements' | 'activity'>('overview');

  return (
    <div className="min-h-screen bg-[#fafafb] text-neutral-900 flex flex-col font-sans pb-24 md:pb-10">
      <IslandHeader groups={groups} activeGroup={activeGroup} />

      <main className="flex-1 max-w-5xl w-full mx-auto px-4 sm:px-6 pt-6 sm:pt-8">
        <AnimatePresence mode="wait">
          {currentTab === 'individual' ? (
            <motion.div
              key="individual-tab"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
            >
              <PersonalStream />
            </motion.div>
          ) : groups.length === 0 ? (
            <motion.div
              key="empty-groups-state"
              initial={{ opacity: 0, scale: 0.96 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.96 }}
              transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
              className="settlr-panel max-w-md mx-auto p-8 sm:p-10 text-center my-12 bg-white"
            >
              <div className="w-12 h-12 rounded-2xl bg-neutral-100 border border-neutral-200/60 mx-auto flex items-center justify-center mb-4 p-2 shadow-2xs">
                <img src={logoImg} alt="Settlr" className="w-full h-full object-contain" />
              </div>
              <h2 className="text-xl font-bold text-neutral-900 mb-1.5 tracking-tight">
                Create Your First Ledger
              </h2>
              <p className="text-xs text-neutral-500 mb-6 leading-relaxed">
                Create a group for your apartment, trip, or roommates to start splitting bills with automatic zero-sum debt netting.
              </p>
              <div className="flex flex-col sm:flex-row gap-2.5 justify-center">
                <motion.button
                  whileHover={{ scale: 1.03 }}
                  whileTap={{ scale: 0.95 }}
                  type="button"
                  onClick={() => setIsCreateGroupOpen(true)}
                  className="inline-flex items-center justify-center gap-1.5 px-4 py-2 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white font-semibold text-xs shadow-sm transition-all cursor-pointer"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Create Group</span>
                </motion.button>
                <motion.button
                  whileHover={{ scale: 1.03 }}
                  whileTap={{ scale: 0.95 }}
                  type="button"
                  onClick={() => setIsJoinGroupOpen(true)}
                  className="inline-flex items-center justify-center gap-1.5 px-4 py-2 rounded-xl bg-white hover:bg-neutral-50 border border-neutral-200 text-neutral-700 font-semibold text-xs shadow-2xs transition-all cursor-pointer"
                >
                  <UserPlus className="w-3.5 h-3.5 text-neutral-400" />
                  <span>Join with Code</span>
                </motion.button>
              </div>
            </motion.div>
          ) : activeGroup ? (
            <motion.div
              key={`group-view-${activeGroup.id}`}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
            >
              {/* Desktop Dashboard (md and up) */}
              <div className="hidden md:block space-y-7">
                <NetStandingCard
                  group={activeGroup}
                  balances={balances}
                  totalSpending={totalSpending}
                />

                <BilateralDebtMatrix
                  groupId={activeGroup.id}
                  currency={activeGroup.currency}
                  creatorId={activeGroup.created_by}
                  balances={balances}
                  transfers={transfers}
                  settlements={settlements}
                />

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-7">
                  <div className="lg:col-span-2">
                    <TransactionTable
                      groupId={activeGroup.id}
                      currency={activeGroup.currency}
                      expenses={expenses}
                    />
                  </div>
                  <div className="lg:col-span-1">
                    <div className="settlr-panel p-5 bg-white">
                      <ActivityFeed activity={activity} />
                    </div>
                  </div>
                </div>
              </div>

              {/* Mobile Tabbed View (below md) */}
              <div className="block md:hidden">
                <AnimatePresence mode="wait">
                  {activeMobileTab === 'overview' && (
                    <motion.div
                      key="mob-overview"
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -8 }}
                      transition={{ duration: 0.18, ease: [0.16, 1, 0.3, 1] }}
                      className="space-y-5"
                    >
                      <NetStandingCard
                        group={activeGroup}
                        balances={balances}
                        totalSpending={totalSpending}
                      />
                      <BilateralDebtMatrix
                        groupId={activeGroup.id}
                        currency={activeGroup.currency}
                        creatorId={activeGroup.created_by}
                        balances={balances}
                        transfers={transfers}
                        settlements={settlements}
                      />
                    </motion.div>
                  )}

                  {activeMobileTab === 'expenses' && (
                    <motion.div
                      key="mob-expenses"
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -8 }}
                      transition={{ duration: 0.18, ease: [0.16, 1, 0.3, 1] }}
                      className="space-y-4"
                    >
                      <TransactionTable
                        groupId={activeGroup.id}
                        currency={activeGroup.currency}
                        expenses={expenses}
                      />
                    </motion.div>
                  )}

                  {activeMobileTab === 'settlements' && (
                    <motion.div
                      key="mob-settlements"
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -8 }}
                      transition={{ duration: 0.18, ease: [0.16, 1, 0.3, 1] }}
                      className="space-y-4"
                    >
                      <BilateralDebtMatrix
                        groupId={activeGroup.id}
                        currency={activeGroup.currency}
                        balances={balances}
                        transfers={transfers}
                        settlements={settlements}
                      />
                    </motion.div>
                  )}

                  {activeMobileTab === 'activity' && (
                    <motion.div
                      key="mob-activity"
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -8 }}
                      transition={{ duration: 0.18, ease: [0.16, 1, 0.3, 1] }}
                      className="settlr-panel p-4 bg-white"
                    >
                      <ActivityFeed activity={activity} />
                    </motion.div>
                  )}
                </AnimatePresence>

                {/* Mobile Dock */}
                <HapticDock
                  activeTab={activeMobileTab}
                  setActiveTab={setActiveMobileTab}
                  onAddExpense={() => setIsAddExpenseOpen(true)}
                />
              </div>

              {/* Modals */}
              <AddExpenseModal
                groupId={activeGroup.id}
                currency={activeGroup.currency}
                members={members}
              />

              <RecordSettlementModal
                groupId={activeGroup.id}
                currency={activeGroup.currency}
                members={members}
                pairwise={pairwise}
              />

              <PairwiseModal
                pairwise={pairwise}
                currency={activeGroup.currency}
              />

              <ExpenseDetailsModal
                groupId={activeGroup.id}
                currency={activeGroup.currency}
                members={members}
              />

              <GroupSettingsModal
                group={activeGroup}
                balances={balances}
              />
            </motion.div>
          ) : (
            <motion.div
              key="loading-view"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex flex-col items-center justify-center py-24"
            >
              <div className="w-6 h-6 border-2 border-neutral-300 border-t-neutral-900 rounded-full animate-spin mb-3" />
              <span className="text-xs font-semibold text-neutral-500">Loading ledger...</span>
            </motion.div>
          )}
        </AnimatePresence>

        <CreateGroupModal />
        <JoinGroupModal />
        <SmartSpendPopup groups={groups} />
      </main>
    </div>
  );
};

export default function App() {
  const token = useAuthStore((state) => state.token);
  const [, setRerender] = useState(0);

  if (!token) {
    return <OnboardingScreen onComplete={() => setRerender((v) => v + 1)} />;
  }

  return (
    <QueryClientProvider client={queryClient}>
      <Dashboard />
    </QueryClientProvider>
  );
}
