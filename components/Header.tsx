import React from 'react';

const Header: React.FC = () => {
  return (
    <header className="w-full py-8 px-4 sm:px-6 lg:px-8 border-b border-brand-700/50 bg-brand-900/50 backdrop-blur-sm sticky top-0 z-10">
      <div className="max-w-7xl mx-auto flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 bg-gradient-to-br from-blue-600 to-indigo-600 rounded-lg flex items-center justify-center shadow-lg">
            <span className="text-white font-bold text-xl">S</span>
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white tracking-tight">StackBill</h1>
            <p className="text-xs text-slate-400 uppercase tracking-wider font-semibold">Infrastructure Gateway</p>
          </div>
        </div>
        <div className="hidden sm:block">
          <span className="px-3 py-1 rounded-full bg-brand-800 text-xs text-slate-400 border border-brand-700">
            System Status: <span className="text-green-400 font-bold">Nominal</span>
          </span>
        </div>
      </div>
    </header>
  );
};

export default Header;