import React, { useState } from 'react';
import { useAuthStore } from '../store/authStore';
import { useUIStore } from '../store/uiStore';
import { apiRequest } from '../services/api';
import { User, Group } from '../types';
import logoImg from '../assets/logo.png';
import { ArrowRight, Sparkles, KeyRound, User as UserIcon } from 'lucide-react';
import { CustomSelect } from './ui/CustomSelect';

interface OnboardingScreenProps {
  onComplete: () => void;
}

export const OnboardingScreen: React.FC<OnboardingScreenProps> = ({ onComplete }) => {
  const setAuth = useAuthStore((state) => state.setAuth);
  const setActiveGroupId = useUIStore((state) => state.setActiveGroupId);

  const [name, setName] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [currency, setCurrency] = useState('INR');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanName = name.trim();
    if (!cleanName) return;

    setLoading(true);
    setError(null);

    try {
      // 1. Establish guest session identity with the user's chosen name
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

      // 2. If user optionally entered an invite code, join that group immediately
      const cleanCode = inviteCode.trim();
      if (cleanCode) {
        try {
          const res = await apiRequest<{ group_id: string }>('/groups/join', {
            method: 'POST',
            body: JSON.stringify({ invite_code: cleanCode }),
          });
          if (res?.group_id) {
            setActiveGroupId(res.group_id);
          }
        } catch (joinErr: unknown) {
          // If code fails, inform user but still proceed with the identity
          console.warn('Optional join code failed:', joinErr);
        }
      }

      onComplete();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to start session');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#fafafa] flex flex-col justify-center items-center p-4 sm:p-6 font-sans">
      <div className="w-full max-w-sm">
        {/* Brand / Logo Header */}
        <div className="text-center mb-6">
          <div className="w-14 h-14 rounded-2xl bg-white border border-neutral-200/90 shadow-sm mx-auto mb-3 flex items-center justify-center p-2.5">
            <img src={logoImg} alt="Settlr Logo" className="w-full h-full object-contain" />
          </div>
          <h1 className="text-2xl font-bold text-neutral-900 tracking-tight">
            Welcome to Settlr
          </h1>
          <p className="text-xs text-neutral-500 mt-1 max-w-xs mx-auto leading-relaxed">
            Smart expense tracking & mathematically optimal debt settlement.
          </p>
        </div>

        {/* Card Form */}
        <div className="saas-card p-6 sm:p-7 bg-white rounded-3xl border border-neutral-200/80 shadow-xl shadow-neutral-900/5">
          {error && (
            <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-medium">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Identity / Name (Required) */}
            <div>
              <label className="block text-xs font-semibold text-neutral-700 uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
                <UserIcon className="w-3.5 h-3.5 text-neutral-400" />
                <span>Your Full Name</span>
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Enter your name"
                className="w-full px-3.5 py-2.5 text-sm bg-neutral-50 border border-neutral-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500 transition-all font-medium text-neutral-900 placeholder:text-neutral-400"
                autoFocus
                required
              />
              <span className="text-[11px] text-neutral-400 mt-1 block">
                How other group members will identify your transactions.
              </span>
            </div>

            {/* Default Currency */}
            <div>
              <label className="block text-xs font-semibold text-neutral-700 uppercase tracking-wider mb-1.5">
                Currency
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

            {/* Join Code (Optional) */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="block text-xs font-semibold text-neutral-700 uppercase tracking-wider flex items-center gap-1.5">
                  <KeyRound className="w-3.5 h-3.5 text-neutral-400" />
                  <span>Group Invite Code</span>
                </label>
                <span className="text-[10px] text-neutral-400 font-medium px-1.5 py-0.5 rounded bg-neutral-100">
                  Optional
                </span>
              </div>
              <input
                type="text"
                value={inviteCode}
                onChange={(e) => setInviteCode(e.target.value)}
                placeholder="e.g. ROOM402 or invite code"
                className="w-full px-3.5 py-2.5 text-sm font-mono bg-neutral-50 border border-neutral-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500 transition-all placeholder:font-sans placeholder:text-neutral-400"
              />
              <span className="text-[11px] text-neutral-400 mt-1 block">
                Have an invite code from friends or flatmates? Enter it here to join instantly.
              </span>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading || !name.trim()}
              className="w-full mt-2 py-2.5 px-4 rounded-full bg-neutral-900 hover:bg-neutral-800 text-white font-medium text-sm shadow-sm flex items-center justify-center gap-1.5 transition-all cursor-pointer disabled:opacity-50 active:scale-98"
            >
              {loading ? (
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <span>Continue</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>
        </div>

        {/* Security / Privacy reassurance */}
        <div className="mt-5 text-center text-xs text-neutral-400 flex items-center justify-center gap-1.5">
          <Sparkles className="w-3.5 h-3.5 text-neutral-400" />
          <span>Local-first encrypted session. Zero tracking.</span>
        </div>
      </div>
    </div>
  );
};
