import React from 'react';
import Header from './components/Header';
import Footer from './components/Footer';
import ServiceCard from './components/ServiceCard';
import { SERVICES } from './constants';

const App: React.FC = () => {
  return (
    <div className="min-h-screen flex flex-col bg-brand-900 text-slate-100 font-sans selection:bg-blue-500/30">
      <Header />

      <main className="flex-grow flex flex-col items-center justify-center p-4 sm:p-8 lg:p-12 relative overflow-hidden">
        {/* Background Decorative Elements */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-blue-500/10 rounded-full blur-[100px] -z-10 pointer-events-none"></div>

        <div className="max-w-4xl w-full space-y-12">
          
          <div className="text-center space-y-4">
            <h2 className="text-3xl sm:text-4xl font-bold text-white">
              Observability Stack
            </h2>
            <p className="text-slate-400 text-lg max-w-2xl mx-auto">
              Select a monitoring service below to access real-time metrics and visualization dashboards.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-3xl mx-auto">
            {SERVICES.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>

          <div className="mt-12 p-4 rounded-lg bg-blue-900/10 border border-blue-500/20 max-w-2xl mx-auto text-center">
            <p className="text-sm text-blue-300">
              <span className="font-semibold">Network Note:</span> All traffic is tunnelled through the secure gateway. 
              Direct access to ports 9090 and 3000 is disabled.
            </p>
          </div>

        </div>
      </main>

      <Footer />
    </div>
  );
};

export default App;