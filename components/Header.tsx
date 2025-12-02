import React from 'react';

const Header: React.FC = () => {
  return (
    <header className="w-full py-8 px-4 sm:px-6 lg:px-8 border-b border-brand-700/50 bg-brand-900/50 backdrop-blur-sm sticky top-0 z-10">
      <div className="max-w-7xl mx-auto flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <a href="/" className="flex items-center space-x-3 group">
            <div className="w-10 h-10 bg-gradient-to-br from-blue-600 to-indigo-600 rounded-lg flex items-center justify-center shadow-lg group-hover:shadow-blue-500/25 transition-all">
              <span className="text-white font-bold text-xl">S</span>
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white tracking-tight">StackBill</h1>
              <p className="text-xs text-slate-400 uppercase tracking-wider font-semibold">Infrastructure Gateway</p>
            </div>
          </a>
        </div>
        
        <div className="flex items-center space-x-4">
           {/* Help Button */}
           <a 
            href="/help" 
            className="flex items-center space-x-1 px-3 py-1.5 rounded-lg text-slate-300 hover:text-white hover:bg-white/10 transition-colors text-sm font-medium"
            aria-label="View Documentation"
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span className="hidden sm:inline">Help</span>
          </a>

          <div className="hidden sm:block">
            <span className="px-3 py-1 rounded-full bg-brand-800 text-xs text-slate-400 border border-brand-700">
              System Status: <span className="text-green-400 font-bold">Nominal</span>
            </span>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;