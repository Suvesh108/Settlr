import React, { useState } from 'react';
import { motion } from 'motion/react';
import { useUIStore } from '../../store/uiStore';
import { apiRequest } from '../../services/api';
import { Group } from '../../types';
import { X, AlertCircle } from 'lucide-react';
import { useQueryClient } from '@tanstack/react-query';
import { CustomSelect } from '../ui/CustomSelect';
import { AnimatedModal } from '../ui/AnimatedModal';

export const CreateGroupModal: React.FC = () => {
  const { isCreateGroupOpen, setIsCreateGroupOpen, setActiveGroupId } = useUIStore();
  const queryClient = useQueryClient();

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [currency, setCurrency] = useState('INR');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const group = await apiRequest<Group>('/groups', {
        method: 'POST',
        body: JSON.stringify({ name: name.trim(), description: description.trim(), currency }),
      });

      queryClient.invalidateQueries({ queryKey: ['groups'] });
      setActiveGroupId(group.id);
      setIsCreateGroupOpen(false);
      setName('');
      setDescription('');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create group');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AnimatedModal
      isOpen={isCreateGroupOpen}
      onClose={() => setIsCreateGroupOpen(false)}
      maxWidth="max-w-md"
    >
      <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
        <div>
          <h3 className="font-bold text-base text-neutral-900">Create New Group</h3>
          <p className="text-xs text-neutral-500">Initialize a shared multi-party ledger</p>
        </div>
        <motion.button
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.92 }}
          type="button"
          onClick={() => setIsCreateGroupOpen(false)}
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
            Group Name
          </label>
          <input
            type="text"
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Apartment 101, Trip to Bali"
            className="w-full px-3.5 py-2 text-sm rounded-lg border border-neutral-300 text-neutral-900 focus:outline-none focus:border-neutral-900 transition-colors"
          />
        </div>

        <div>
          <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
            Description (Optional)
          </label>
          <input
            type="text"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Shared apartment rent, groceries & utilities"
            className="w-full px-3.5 py-2 text-sm rounded-lg border border-neutral-300 text-neutral-900 focus:outline-none focus:border-neutral-900 transition-colors"
          />
        </div>

        <div>
          <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
            Base Currency
          </label>
          <CustomSelect
            value={currency}
            onChange={setCurrency}
            options={[
              { value: 'INR', label: 'INR (₹)' },
              { value: 'USD', label: 'USD ($)' },
              { value: 'EUR', label: 'EUR (€)' },
              { value: 'GBP', label: 'GBP (£)' },
            ]}
          />
          <span className="text-[11px] text-neutral-400 mt-1.5 block">
            Immutable currency setting to ensure strict mathematical invariance.
          </span>
        </div>

        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.96 }}
          type="submit"
          disabled={loading}
          className="w-full mt-2 py-2.5 px-4 rounded-xl bg-neutral-900 hover:bg-neutral-800 text-white font-semibold text-xs shadow-sm transition-all cursor-pointer disabled:opacity-50"
        >
          {loading ? 'Creating...' : 'Create Group'}
        </motion.button>
      </form>
    </AnimatedModal>
  );
};
