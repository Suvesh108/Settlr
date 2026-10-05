import React, { useState } from 'react';
import { useAuthStore } from '../store/authStore';
import { apiRequest } from '../services/api';
import { User } from '../types';
import logoImg from '../assets/logo.png';
import { ShieldCheck, ArrowRight } from 'lucide-react';
import { CustomSelect } from './ui/CustomSelect';

export const AuthScreen: React.FC = () => {
  const [isRegister, setIsRegister] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [currency, setCurrency] = useState('INR');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const setAuth = useAuthStore((state) => state.setAuth);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      if (isRegister) {
        const user = await apiRequest<User>('/auth/register', {
          method: 'POST',
          body: JSON.stringify({ name, email, password, default_currency: currency }),
        });
        if (user.token) {
          setAuth(user, user.token);
        }
      } else {
        const user = await apiRequest<User>('/auth/login', {
          method: 'POST',
          body: JSON.stringify({ email, password }),
        });
        if (user.token) {
          setAuth(user, user.token);
        }
      }
    } catch (err: unknown) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('Authentication failed');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-neutral-50 flex flex-col justify-center items-center p-4 sm:p-6">
      <div className="w-full max-w-sm">
        {/* Header with Logo */}
        <div className="text-center mb-8">
          <div className="w-12 h-12 rounded-xl bg-white border border-neutral-200 shadow-xs mx-auto mb-3 flex items-center justify-center p-1.5">
            <img
              src={logoImg}
              alt="Settlr Logo"
              className="w-full h-full object-contain"
            />
          </div>
          <h1 className="text-2xl font-bold text-neutral-900 tracking-tight">
            {isRegister ? 'Create your account' : 'Sign in to Settlr'}
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Real-time multi-party ledger & automated bill splitting
          </p>
        </div>

        {/* Card */}
        <div className="bg-white border border-neutral-200 rounded-2xl p-6 sm:p-7 shadow-xs">
          {error && (
            <div className="mb-4 p-3 rounded-lg bg-rose-50 border border-rose-200 text-rose-700 text-xs font-medium">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {isRegister && (
              <div>
                <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
                  Full Name
                </label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Suvesh"
                  className="w-full px-3.5 py-2 text-sm rounded-lg border border-neutral-300 text-neutral-900 placeholder-neutral-400 focus:outline-none focus:border-neutral-900 transition-colors"
                />
              </div>
            )}

            <div>
              <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
                Email address
              </label>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="suvesh@example.com"
                className="w-full px-3.5 py-2 text-sm rounded-lg border border-neutral-300 text-neutral-900 placeholder-neutral-400 focus:outline-none focus:border-neutral-900 transition-colors"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
                Password
              </label>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full px-3.5 py-2 text-sm rounded-lg border border-neutral-300 text-neutral-900 placeholder-neutral-400 focus:outline-none focus:border-neutral-900 transition-colors"
              />
            </div>

            {isRegister && (
              <div>
                <label className="block text-xs font-semibold text-neutral-700 mb-1.5">
                  Default Currency
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
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full mt-2 py-2.5 px-4 rounded-full bg-sky-500 hover:bg-sky-600 text-white font-medium text-sm shadow-sm shadow-sky-500/25 flex items-center justify-center gap-1.5 transition-all cursor-pointer disabled:opacity-50 active:scale-98"
            >
              {loading ? (
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <span>{isRegister ? 'Create Account' : 'Sign In'}</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

          <div className="mt-5 pt-4 border-t border-neutral-100 text-center">
            <button
              type="button"
              onClick={() => {
                setIsRegister(!isRegister);
                setError(null);
              }}
              className="text-xs text-neutral-500 hover:text-neutral-900 font-medium transition-colors cursor-pointer"
            >
              {isRegister
                ? 'Already have an account? Sign in'
                : "Don't have an account? Sign up"}
            </button>
          </div>
        </div>

        {/* Trust tag */}
        <div className="mt-6 flex items-center justify-center gap-1.5 text-xs text-neutral-400 font-normal">
          <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
          <span>Strict zero-sum mathematical consistency</span>
        </div>
      </div>
    </div>
  );
};
