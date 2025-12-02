import React from 'react';
import Header from './Header';
import Footer from './Footer';

const HelpPage: React.FC = () => {
  return (
    <div className="min-h-screen flex flex-col bg-brand-900 text-slate-100 font-sans selection:bg-blue-500/30">
      <Header />

      <main className="flex-grow flex flex-col items-center p-4 sm:p-8 relative">
        {/* Background Decorative Elements */}
        <div className="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-500/5 rounded-full blur-[100px] -z-10 pointer-events-none"></div>

        <div className="max-w-4xl w-full">
          <div className="mb-8 flex items-center justify-between">
            <a 
              href="/" 
              className="group flex items-center space-x-2 text-blue-400 hover:text-blue-300 transition-colors px-4 py-2 rounded-lg hover:bg-white/5"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 transition-transform group-hover:-translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
              <span>Back to Dashboard</span>
            </a>
            <h1 className="text-2xl font-bold text-white tracking-tight">Documentation</h1>
          </div>

          <article className="bg-brand-800 border border-brand-700 rounded-xl p-8 sm:p-12 shadow-xl relative overflow-hidden">
            {/* Content Placeholder for User MD Injection */}
            <div className="space-y-6 text-slate-300 leading-relaxed">
              <h2 className="text-xl font-semibold text-white">How to use StackBill</h2>
              <p>
                Welcome to the StackBill observability gateway. This portal allows you to securely access our internal monitoring tools.
              </p>
              
              <hr className="border-brand-700 my-8" />
              
              <div className="p-4 bg-brand-900/50 rounded border border-blue-500/20 text-blue-200 text-sm font-mono">
                {/* USER INSTRUCTION: Place your Markdown content or rendered HTML here */}
                &lt;!-- Markdown Content Placeholder --&gt;<br/>
                Please replace this section with the rendered Markdown content.<br/>
                Files are located in /docs/
              </div>

              <h3 className="text-lg font-medium text-white pt-4">Troubleshooting</h3>
              <ul className="list-disc list-inside space-y-2 marker:text-blue-500">
                <li>If a service is unreachable, ensure you are connected to the VPN.</li>
                <li>Check the "System Status" indicator in the header.</li>
                <li>Contact DevOps if you encounter 502 Bad Gateway errors.</li>
              </ul>
            </div>
          </article>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default HelpPage;