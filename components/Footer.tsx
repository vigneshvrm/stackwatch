import React from 'react';
import { APP_METADATA } from '../constants';

const Footer: React.FC = () => {
  return (
    <footer className="w-full py-6 mt-auto border-t border-brand-700/50 bg-brand-900">
      <div className="max-w-7xl mx-auto px-4 text-center">
        <p className="text-slate-500 text-sm">
          &copy; {new Date().getFullYear()} StackBill Architecture. All links routed via internal Nginx proxy.
        </p>
        <div className="mt-2 flex justify-center space-x-4 text-xs text-slate-600 font-mono">
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