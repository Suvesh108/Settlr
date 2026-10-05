import { create } from 'zustand';
import { User } from '../types';

interface AuthState {
  user: User | null;
  token: string | null;
  setAuth: (user: User, token: string) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>((set) => {
  const savedToken = localStorage.getItem('access_token');
  let savedUser: User | null = null;
  try {
    const raw = localStorage.getItem('user_data');
    savedUser = raw ? JSON.parse(raw) : null;
  } catch {
    savedUser = null;
  }

  return {
    user: savedUser,
    token: savedToken || null,
    setAuth: (user, token) => {
      localStorage.setItem('access_token', token);
      localStorage.setItem('user_data', JSON.stringify(user));
      set({ user, token });
    },
    logout: () => {
      localStorage.removeItem('access_token');
      localStorage.removeItem('user_data');
      set({ user: null, token: null });
    },
  };
});
