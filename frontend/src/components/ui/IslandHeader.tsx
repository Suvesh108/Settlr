import React, { useState } from 'react';
import { motion } from 'motion/react';
import { useAuthStore } from '../../store/authStore';
import { useUIStore } from '../../store/uiStore';
import { Group } from '../../types';
import logoImg from '../../assets/logo.png';
import { ProfileModal } from '../modals/ProfileModal';
import { 
  Users, 
  User, 
  ChevronDown, 
  Copy, 
  Check, 
  UserPlus, 
  Plus 
} from 'lucide-react';
import { CustomSelect } from './CustomSelect';

interface IslandHeaderProps {
  groups?: Group[];
  activeGroup?: Group;
}

export const IslandHeader: React.FC<IslandHeaderProps> = ({ groups = [], activeGroup }) => {
  const safeGroups = groups || [];
  const user = useAuthStore((state) => state.user);
  const { 
    currentTab, 
    setCurrentTab, 
    setActiveGroupId, 
    setIsCreateGroupOpen, 
    setIsJoinGroupOpen 
  } = useUIStore();

  const [copied, setCopied] = useState(false);
  const [isProfileOpen, setIsProfileOpen] = useState(false);

  const handleCopyInvite = () => {
    if (activeGroup?.invite_code) {
      navigator.clipboard.writeText(activeGroup.invite_code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <>
      <header className="sticky top-0 z-40 w-full bg-white/85 backdrop-blur-md border-b border-neutral-200/70 transition-all">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-15 flex items-center justify-between gap-3">
          
          {/* Left: Brand Identity & Mode Segment */}
          <div className="flex items-center gap-3 sm:gap-5">
            <div className="flex items-center gap-2.5">
              <div className="w-7 h-7 rounded-lg overflow-hidden flex items-center justify-center shrink-0 shadow-2xs">
                <img src={logoImg} alt="Settlr" className="w-full h-full object-contain" />
              </div>
              <span className="font-semibold text-sm tracking-tight text-neutral-900 hidden sm:inline">
                Settlr
              </span>
            </div>

            {/* Segmented Switch: Personal | Groups */}
            <nav className="relative flex items-center p-0.5 bg-neutral-100/90 rounded-lg border border-neutral-200/60">
              <button
                type="button"
                onClick={() => setCurrentTab('individual')}
                className={`relative z-10 flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium transition-colors cursor-pointer ${
                  currentTab === 'individual'
                    ? 'text-neutral-900 font-semibold'
                    : 'text-neutral-500 hover:text-neutral-800'
                }`}
              >
                {currentTab === 'individual' && (
                  <motion.div
                    layoutId="header-segmented-pill"
                    className="absolute inset-0 bg-white rounded-md shadow-2xs border border-neutral-200/40"
                    transition={{ type: 'spring', stiffness: 500, damping: 35 }}
                  />
                )}
                <User className="relative z-10 w-3.5 h-3.5" />
                <span className="relative z-10">Personal</span>
              </button>

              <button
                type="button"
                onClick={() => setCurrentTab('group')}
                className={`relative z-10 flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium transition-colors cursor-pointer ${
                  currentTab === 'group'
                    ? 'text-neutral-900 font-semibold'
                    : 'text-neutral-500 hover:text-neutral-800'
                }`}
              >
                {currentTab === 'group' && (
                  <motion.div
                    layoutId="header-segmented-pill"
                    className="absolute inset-0 bg-white rounded-md shadow-2xs border border-neutral-200/40"
                    transition={{ type: 'spring', stiffness: 500, damping: 35 }}
                  />
                )}
                <Users className="relative z-10 w-3.5 h-3.5" />
                <span className="relative z-10">Groups</span>
              </button>
            </nav>
          </div>

          {/* Center (Desktop Only): Group Switcher & Code */}
          {currentTab === 'group' && safeGroups.length > 0 && (
            <div className="hidden md:flex items-center gap-2">
              <div className="w-44">
                <CustomSelect
                  value={activeGroup?.id || ''}
                  onChange={setActiveGroupId}
                  options={safeGroups.map((g) => ({
                    value: g.id,
                    label: g.name,
                  }))}
                />
              </div>

              {activeGroup && activeGroup.created_by === user?.id && (
                <button
                  type="button"
                  onClick={handleCopyInvite}
                  title="Share Invite Code (Group Creator)"
                  className="flex items-center gap-1 text-[11px] font-mono text-neutral-600 px-2 py-1 rounded-md bg-neutral-50 hover:bg-neutral-100 border border-neutral-200/80 transition-all cursor-pointer"
                >
                  {copied ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3 text-neutral-400" />}
                  <span>{activeGroup.invite_code}</span>
                </button>
              )}

              <motion.button
                whileHover={{ scale: 1.08 }}
                whileTap={{ scale: 0.92 }}
                type="button"
                onClick={() => setIsJoinGroupOpen(true)}
                title="Join with Code"
                className="p-1 rounded-md text-neutral-500 hover:text-neutral-900 hover:bg-neutral-100 transition-all cursor-pointer"
              >
                <UserPlus className="w-3.5 h-3.5" />
              </motion.button>

              <motion.button
                whileHover={{ scale: 1.08 }}
                whileTap={{ scale: 0.92 }}
                type="button"
                onClick={() => setIsCreateGroupOpen(true)}
                title="Create Group"
                className="p-1 rounded-md text-neutral-500 hover:text-neutral-900 hover:bg-neutral-100 transition-all cursor-pointer"
              >
                <Plus className="w-3.5 h-3.5" />
              </motion.button>
            </div>
          )}

          {/* Right: Personal Profile Avatar Pill */}
          <div className="flex items-center gap-2">
            <motion.button
              whileHover={{ scale: 1.04 }}
              whileTap={{ scale: 0.95 }}
              type="button"
              onClick={() => setIsProfileOpen(true)}
              className="flex items-center gap-2 pl-1.5 pr-3 py-1 rounded-full bg-neutral-100 hover:bg-neutral-200/80 text-neutral-800 text-xs font-medium transition-all cursor-pointer border border-neutral-200/60 shadow-2xs"
              title="Your Profile & Settings"
            >
              <div className="w-5.5 h-5.5 rounded-full bg-neutral-900 text-white flex items-center justify-center font-bold text-[10px] tracking-tight">
                {user?.name ? user.name.slice(0, 2).toUpperCase() : 'U'}
              </div>
              <span className="font-semibold text-xs">{user?.name || 'User'}</span>
            </motion.button>
          </div>

        </div>
      </header>

      <ProfileModal 
        isOpen={isProfileOpen} 
        onClose={() => setIsProfileOpen(false)} 
      />
    </>
  );
};
