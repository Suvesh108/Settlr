import React, { useState } from 'react';
import { useAuthStore } from '../../store/authStore';
import { apiRequest } from '../../services/api';
import { User } from '../../types';
import { X, User as UserIcon, LogOut, Check, Sparkles, AlertTriangle, Trash2 } from 'lucide-react';
import { AnimatedModal } from '../ui/AnimatedModal';
import { CustomSelect } from '../ui/CustomSelect';
import { motion, AnimatePresence } from 'motion/react';

interface ProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const ProfileModal: React.FC<ProfileModalProps> = ({ isOpen, onClose }) => {
  const currentUser = useAuthStore((state) => state.user);
  const setAuth = useAuthStore((state) => state.setAuth);
  const logout = useAuthStore((state) => state.logout);

  const [name, setName] = useState(currentUser?.name || '');
  const [currency, setCurrency] = useState(currentUser?.default_currency || 'INR');
  const [loading, setLoading] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false);

  React.useEffect(() => {
    if (isOpen) {
      setName(currentUser?.name || '');
      setCurrency(currentUser?.default_currency || 'INR');
      setError(null);
      setSaved(false);
      setShowLogoutConfirm(false);
    }
  }, [isOpen, currentUser]);

  if (!isOpen) return null;

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanName = name.trim();
    if (!cleanName) return;

    setLoading(true);
    setError(null);
    setSaved(false);

    try {
      // Update session identity
      const user = await apiRequest<User>('/auth/session', {
        method: 'POST',
        body: JSON.stringify({
          name: cleanName,
          email: `${cleanName.toLowerCase().replace(/\s+/g, '.')}@local`,
          default_currency: currency,
        }),
      });

      if (user.token) {
        setAuth(user, user.token);
      }
      setSaved(true);
      setTimeout(() => {
        onClose();
      }, 700);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to update profile');
    } finally {
      setLoading(false);
    }
  };

  const handleConfirmLogout = () => {
    logout();
    localStorage.removeItem('active_group_id');
    window.location.reload();
  };

  return (
    <AnimatedModal
      isOpen={isOpen}
      onClose={onClose}
      maxWidth="max-w-sm"
    >
      <div>
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-full bg-neutral-900 text-white flex items-center justify-center font-bold text-xs shadow-xs">
              {currentUser?.name ? currentUser.name.slice(0, 2).toUpperCase() : 'U'}
            </div>
            <div>
              <h3 className="font-bold text-base text-neutral-900">Your Profile</h3>
              <p className="text-xs text-neutral-500">Personal settings & preferences</p>
            </div>
          </div>
          <motion.button
            whileHover={{ scale: 1.1, rotate: 90 }}
            whileTap={{ scale: 0.9 }}
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-neutral-100 hover:bg-neutral-200 flex items-center justify-center text-neutral-500 transition-colors cursor-pointer"
          >
            <X className="w-4 h-4" />
          </motion.button>
        </div>

        {error && (
          <div className="mt-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-medium">
            {error}
          </div>
        )}

        {saved && (
          <div className="mt-4 p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-700 text-xs font-medium flex items-center gap-1.5">
            <Check className="w-4 h-4 text-emerald-600" />
            <span>Profile saved successfully!</span>
          </div>
        )}

        <form onSubmit={handleUpdate} className="mt-5 space-y-4">
          <div>
            <label className="block text-xs font-semibold text-neutral-700 uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
              <UserIcon className="w-3.5 h-3.5 text-neutral-400" />
              <span>Display Name</span>
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Suvesh"
              className="w-full px-3.5 py-2.5 text-sm bg-neutral-50 hover:bg-neutral-100 border border-neutral-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500 transition-all font-medium text-neutral-900"
              required
            />
            <span className="text-[11px] text-neutral-400 mt-1 block">
              Used across all shared groups for debt settlement calculations.
            </span>
          </div>

          <div>
            <label className="block text-xs font-semibold text-neutral-700 uppercase tracking-wider mb-1.5">
              Default Currency
            </label>
            <CustomSelect
              value={currency}
              onChange={setCurrency}
              options={[
                { value: 'INR', label: 'INR (₹)', sublabel: 'Indian Rupee' },
                { value: 'USD', label: 'USD ($)', sublabel: 'US Dollar' },
                { value: 'EUR', label: 'EUR (€)', sublabel: 'Euro' },
                { value: 'GBP', label: 'GBP (£)', sublabel: 'British Pound' },
              ]}
            />
          </div>

          <div className="pt-2 flex items-center justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-3.5 py-2 text-xs font-medium text-neutral-600 hover:text-neutral-900 cursor-pointer"
            >
              Cancel
            </button>
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              type="submit"
              disabled={loading || !name.trim()}
              className="px-4 py-2 rounded-full bg-sky-500 hover:bg-sky-600 text-white font-medium text-xs shadow-sm shadow-sky-500/25 transition-all cursor-pointer disabled:opacity-50"
            >
              {loading ? 'Saving...' : 'Save Profile'}
            </motion.button>
          </div>
        </form>

        <div className="mt-5 pt-4 border-t border-neutral-100">
          <AnimatePresence>
            {showLogoutConfirm ? (
              <motion.div
                initial={{ opacity: 0, y: 10, scale: 0.97 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: 8, scale: 0.97 }}
                transition={{ duration: 0.18, ease: 'easeOut' }}
                className="p-3.5 rounded-2xl bg-rose-50/90 border border-rose-200 text-rose-900 shadow-sm space-y-2.5"
              >
                <div className="flex items-start gap-2.5">
                  <div className="w-7 h-7 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center shrink-0 mt-0.5">
                    <AlertTriangle className="w-4 h-4" />
                  </div>
                  <div>
                    <h4 className="text-xs font-bold text-rose-900 leading-tight">
                      Confirm Account Log Out
                    </h4>
                    <p className="text-[11px] text-rose-700 mt-0.5 leading-snug">
                      If you log out, your local session and personal offline data will be removed from this device.
                    </p>
                  </div>
                </div>

                <div className="flex items-center justify-end gap-2 pt-1">
                  <button
                    type="button"
                    onClick={() => setShowLogoutConfirm(false)}
                    className="px-3 py-1.5 text-xs font-semibold text-neutral-600 hover:text-neutral-900 rounded-lg hover:bg-rose-100/50 transition-colors cursor-pointer"
                  >
                    Cancel
                  </button>
                  <motion.button
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.97 }}
                    type="button"
                    onClick={handleConfirmLogout}
                    className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-rose-600 hover:bg-rose-700 text-white text-xs font-semibold shadow-xs shadow-rose-600/30 transition-colors cursor-pointer"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                    <span>Yes, Log Out</span>
                  </motion.button>
                </div>
              </motion.div>
            ) : (
              <div className="flex items-center justify-between">
                <div className="text-[11px] text-neutral-400">
                  Account ID: <span className="font-mono text-neutral-500">{currentUser?.id?.slice(0, 10)}...</span>
                </div>
                <motion.button
                  whileHover={{ scale: 1.03 }}
                  whileTap={{ scale: 0.96 }}
                  type="button"
                  onClick={() => setShowLogoutConfirm(true)}
                  className="inline-flex items-center gap-1.5 text-xs text-rose-600 hover:text-rose-700 font-semibold px-2.5 py-1 rounded-lg hover:bg-rose-50 transition-colors cursor-pointer"
                >
                  <LogOut className="w-3.5 h-3.5" />
                  <span>Log Out</span>
                </motion.button>
              </div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </AnimatedModal>
  );
};
