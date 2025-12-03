import React from 'react';
import { APP_METADATA } from '../constants';

const Footer: React.FC = () => {
  return (
    <footer className="w-full py-6 mt-auto border-t border-slate-200 dark:border-brand-700/50 bg-white dark:bg-brand-900 transition-colors duration-200">
      <div className="max-w-7xl mx-auto px-4 text-center">
        <p className="text-slate-600 dark:text-slate-500 text-sm transition-colors duration-200">
          &copy; {new Date().getFullYear()} StackWatch Architecture. All links routed via internal Nginx proxy.
        </p>
        <div className="mt-2 flex justify-center space-x-4 text-xs text-slate-500 dark:text-slate-600 font-mono transition-colors duration-200">
          <span>v{APP_METADATA.version}</span>
          <span>|</span>
          <span>Env: {APP_METADATA.environment}</span>
          <span>|</span>
          <span>Secure Routing</span>
        </div>
      </div>
    </footer>
  );
};

export default Footer;