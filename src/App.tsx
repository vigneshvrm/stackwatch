import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { ThemeProvider } from './contexts/ThemeContext';
import AppLayout from './components/AppLayout';
import ServiceCard from './components/ServiceCard';
import HelpPage from './components/HelpPage';
import { SERVICES } from './constants';

const Dashboard: React.FC = () => {
  return (
    <AppLayout showGradientBackground={true} showProfile={true}>
      <div className="space-y-8">
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
      </div>
    </AppLayout>
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
