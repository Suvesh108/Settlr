import React, { useState, useRef, useEffect } from 'react';
import { ChevronDown, Check } from 'lucide-react';

export interface DropdownOption {
  value: string;
  label: string;
  sublabel?: string;
  icon?: React.ReactNode;
}

interface CustomSelectProps {
  value: string;
  onChange: (value: string) => void;
  options: DropdownOption[];
  placeholder?: string;
  className?: string;
  disabled?: boolean;
}

export const CustomSelect: React.FC<CustomSelectProps> = ({
  value,
  onChange,
  options,
  placeholder = 'Select an option...',
  className = '',
  disabled = false,
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const selectedOption = options.find((opt) => opt.value === value);

  // Close when clicked outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <div ref={containerRef} className={`relative w-full ${className}`}>
      {/* Trigger Button */}
      <button
        type="button"
        disabled={disabled}
        onClick={() => setIsOpen((prev) => !prev)}
        className="w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl border border-neutral-200 bg-neutral-50 hover:bg-neutral-100 text-neutral-900 text-xs sm:text-sm font-medium focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:bg-white transition-all cursor-pointer text-left shadow-2xs disabled:opacity-50"
      >
        <div className="flex items-center gap-2 truncate">
          {selectedOption?.icon && (
            <span className="shrink-0 text-neutral-500">{selectedOption.icon}</span>
          )}
          <span className="truncate">
            {selectedOption ? selectedOption.label : placeholder}
          </span>
        </div>
        <ChevronDown
          className={`w-4 h-4 text-neutral-400 shrink-0 ml-2 transition-transform duration-200 ${
            isOpen ? 'rotate-180 text-neutral-700' : ''
          }`}
        />
      </button>

      {/* Floating Dropdown Menu Panel (ReactBits / 21st.dev style) */}
      {isOpen && (
        <div className="absolute z-[120] left-0 right-0 mt-1.5 p-1.5 bg-white rounded-2xl border border-neutral-200/90 shadow-xl max-h-60 overflow-y-auto animate-in fade-in zoom-in-95 duration-150">
          <div className="space-y-0.5">
            {options.map((option) => {
              const isSelected = option.value === value;
              return (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => {
                    onChange(option.value);
                    setIsOpen(false);
                  }}
                  className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-medium transition-colors text-left cursor-pointer ${
                    isSelected
                      ? 'bg-neutral-100 text-neutral-900 font-semibold'
                      : 'text-neutral-700 hover:bg-neutral-50 hover:text-neutral-900'
                  }`}
                >
                  <div className="flex items-center gap-2 truncate">
                    {option.icon && (
                      <span className="shrink-0 text-neutral-500">{option.icon}</span>
                    )}
                    <div className="truncate">
                      <span>{option.label}</span>
                      {option.sublabel && (
                        <span className="block text-[10px] text-neutral-400 font-normal">
                          {option.sublabel}
                        </span>
                      )}
                    </div>
                  </div>

                  {isSelected && (
                    <Check className="w-3.5 h-3.5 text-neutral-900 shrink-0 ml-2" />
                  )}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};
