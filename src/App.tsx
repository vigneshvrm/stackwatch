import React, { useState } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { ThemeProvider } from './contexts/ThemeContext';
import Sidebar from './components/Sidebar';
import ServiceCard from './components/ServiceCard';
import HelpPage from './components/HelpPage';
import ThemeToggle from './components/ThemeToggle';
import { SERVICES } from './constants';

const DashboardHeader: React.FC<{ onMenuClick: () => void }> = ({ onMenuClick }) => {
  return (
    <header className="sticky top-0 z-30 bg-white/80 dark:bg-slate-900/80 backdrop-blur-xl border-b border-slate-200/50 dark:border-slate-700/50">
      <div className="px-4 sm:px-6 lg:px-8 py-4">
        <div className="flex items-center justify-between">
          {/* Mobile menu button */}
          <button
            onClick={onMenuClick}
            className="lg:hidden p-2 rounded-xl text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-all"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>

          {/* Spacer for centering */}
          <div className="flex-1" />

          {/* Right side */}
          <div className="flex items-center space-x-3">
            <ThemeToggle />

            {/* Profile */}
            <div className="hidden sm:flex items-center space-x-3 pl-3 border-l border-slate-200 dark:border-slate-700">
              <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white font-semibold text-sm shadow-lg shadow-blue-500/25">
                A
              </div>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
};

const Dashboard: React.FC = () => {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen flex bg-slate-50 dark:bg-slate-900">
      {/* Sidebar */}
      <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-w-0">
        <DashboardHeader onMenuClick={() => setSidebarOpen(true)} />

        <main className="flex-1 overflow-y-auto">
          {/* Background gradient */}
          <div className="absolute inset-0 overflow-hidden pointer-events-none">
            <div className="absolute top-0 right-0 w-[800px] h-[600px] bg-gradient-to-br from-blue-500/5 via-indigo-500/5 to-purple-500/5 rounded-full blur-3xl transform translate-x-1/3 -translate-y-1/4" />
            <div className="absolute bottom-0 left-0 w-[600px] h-[400px] bg-gradient-to-tr from-cyan-500/5 via-blue-500/5 to-indigo-500/5 rounded-full blur-3xl transform -translate-x-1/3 translate-y-1/4" />
          </div>

          <div className="relative px-4 sm:px-6 lg:px-8 py-8 space-y-8">
            {/* Welcome Section */}
            <div className="text-center max-w-2xl mx-auto">
              <h1 className="text-3xl sm:text-4xl font-bold text-slate-900 dark:text-white mb-3">
                Welcome to StackWatch
              </h1>
              <p className="text-slate-500 dark:text-slate-400 text-lg">
                Your centralized observability gateway for monitoring infrastructure
              </p>
            </div>

            {/* Services Grid */}
            <div className="max-w-4xl mx-auto">
              <h2 className="text-lg font-semibold text-slate-900 dark:text-white mb-4 text-center">
                Quick Access
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                {SERVICES.map((service) => (
                  <ServiceCard key={service.id} service={service} />
                ))}
              </div>
            </div>

            {/* Footer */}
            <footer className="pt-8 border-t border-slate-200/50 dark:border-slate-700/50 max-w-4xl mx-auto w-full">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 text-sm text-slate-500 dark:text-slate-400">
                <p>&copy; {new Date().getFullYear()} StackWatch. All rights reserved.</p>
                <div className="flex items-center space-x-4">
                  <span className="font-mono text-xs">v1.0.0</span>
                  <span>|</span>
                  <span>Secure Routing via Nginx</span>
                </div>
              </div>
            </footer>
          </div>
        </main>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  return (
    <ThemeProvider>
      <BrowserRouter>
        <div className="min-h-screen bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-slate-100 font-sans selection:bg-blue-500/30 transition-colors duration-200">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/help" element={<HelpPage />} />
          </Routes>
        </div>
      </BrowserRouter>
    </ThemeProvider>
  );
};

export default App;
