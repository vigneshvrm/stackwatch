import React from 'react';
import { useTheme } from '../contexts/ThemeContext';

const ThemeToggle: React.FC = () => {
  const { theme, toggleTheme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <div className="flex items-center space-x-2">
      {/* Light Mode Label */}
      <span className={`text-xs font-medium transition-colors duration-200 ${
        !isDark 
          ? 'text-slate-900 dark:text-white' 
          : 'text-slate-500 dark:text-slate-400'
      }`}>
        Light
      </span>
      
      {/* Toggle Switch */}
      <button
        onClick={toggleTheme}
        className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-slate-50 dark:focus:ring-offset-brand-900 ${
          isDark 
            ? 'bg-blue-600 dark:bg-blue-500' 
            : 'bg-slate-300 dark:bg-slate-600'
        }`}
        role="switch"
        aria-checked={isDark}
        aria-label={`Switch to ${isDark ? 'light' : 'dark'} mode`}
        title={`Switch to ${isDark ? 'light' : 'dark'} mode`}
      >
        {/* Toggle Circle */}
        <span
          className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform duration-200 ${
            isDark ? 'translate-x-6' : 'translate-x-1'
          }`}
        />
      </button>
      
      {/* Dark Mode Label */}
      <span className={`text-xs font-medium transition-colors duration-200 ${
        isDark 
          ? 'text-slate-900 dark:text-white' 
          : 'text-slate-500 dark:text-slate-400'
      }`}>
        Dark
      </span>
    </div>
  );
};

export default ThemeToggle;

