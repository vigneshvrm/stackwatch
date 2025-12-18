import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { ThemeProvider } from './contexts/ThemeContext';
import Header from './components/Header';
import Footer from './components/Footer';
import ServiceCard from './components/ServiceCard';
import HelpPage from './components/HelpPage';
import { SERVICES } from './constants';

const Dashboard: React.FC = () => {
  return (
    <>
      <Header />

      <main className="flex-grow flex flex-col items-center justify-center p-4 sm:p-8 lg:p-12 relative overflow-hidden">
        {/* Background Decorative Elements */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-blue-500/10 dark:bg-blue-500/10 rounded-full blur-[100px] -z-10 pointer-events-none transition-colors duration-200"></div>

        <div className="max-w-4xl w-full space-y-12">
          
          <div className="text-center space-y-4">
            <h2 className="text-3xl sm:text-4xl font-bold text-slate-900 dark:text-white transition-colors duration-200">
              Observability Stack
            </h2>
            <p className="text-slate-600 dark:text-slate-400 text-lg max-w-2xl mx-auto transition-colors duration-200">
              Select a monitoring service below to access real-time metrics and visualization dashboards.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 max-w-5xl mx-auto">
            {SERVICES.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>

          <div className="mt-12 p-4 rounded-lg bg-blue-50 dark:bg-blue-900/10 border border-blue-200 dark:border-blue-500/20 max-w-2xl mx-auto text-center transition-colors duration-200">
            <p className="text-sm text-blue-700 dark:text-blue-300 transition-colors duration-200">
              <span className="font-semibold">Network Note:</span> All traffic is tunnelled through the secure gateway. 
              Direct access to ports 9090 and 3000 is disabled.
            </p>
          </div>

        </div>
      </main>

      <Footer />
    </>
  );
};

const App: React.FC = () => {
  return (
    <ThemeProvider>
      <BrowserRouter>
        <div className="min-h-screen flex flex-col bg-slate-50 dark:bg-brand-900 text-slate-900 dark:text-slate-100 font-sans selection:bg-blue-500/30 dark:selection:bg-blue-500/30 transition-colors duration-200">
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