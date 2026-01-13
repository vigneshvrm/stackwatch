import React, { useState } from 'react';
import Sidebar from './Sidebar';
import AppHeader from './AppHeader';
import { APP_METADATA } from '../constants';

interface Breadcrumb {
  label: string;
  path?: string;
}

interface AppLayoutProps {
  children: React.ReactNode;
  breadcrumbs?: Breadcrumb[];
  showProfile?: boolean;
  showGradientBackground?: boolean;
  sidebarVariant?: 'navigation' | 'documentation';
  documentationSidebar?: React.ReactNode;
}

const AppLayout: React.FC<AppLayoutProps> = ({
  children,
  breadcrumbs,
  showProfile = true,
  showGradientBackground = false,
  sidebarVariant = 'navigation',
  documentationSidebar,
}) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen flex bg-slate-50 dark:bg-slate-900">
      {/* Sidebar - use custom documentation sidebar or default navigation */}
      {sidebarVariant === 'documentation' && documentationSidebar ? (
        <>
          {/* Mobile overlay */}
          {sidebarOpen && (
            <div
              className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-40 lg:hidden"
              onClick={() => setSidebarOpen(false)}
            />
          )}
          {/* Documentation sidebar with visibility control */}
          <div
            className={`fixed lg:sticky top-0 left-0 h-screen z-50 lg:z-auto transform transition-transform duration-300 ease-in-out ${
              sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
            }`}
          >
            {documentationSidebar}
          </div>
        </>
      ) : (
        <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      )}

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-w-0">
        <AppHeader
          onMenuClick={() => setSidebarOpen(true)}
          breadcrumbs={breadcrumbs}
          showProfile={showProfile}
        />

        <main className="flex-1 overflow-y-auto relative">
          {/* Optional gradient background */}
          {showGradientBackground && (
            <div className="absolute inset-0 overflow-hidden pointer-events-none">
              <div className="absolute top-0 right-0 w-[800px] h-[600px] bg-gradient-to-br from-blue-500/5 via-indigo-500/5 to-purple-500/5 rounded-full blur-3xl transform translate-x-1/3 -translate-y-1/4" />
              <div className="absolute bottom-0 left-0 w-[600px] h-[400px] bg-gradient-to-tr from-cyan-500/5 via-blue-500/5 to-indigo-500/5 rounded-full blur-3xl transform -translate-x-1/3 translate-y-1/4" />
            </div>
          )}

          <div className="relative px-4 sm:px-6 lg:px-8 py-8">
            {children}
          </div>
        </main>

        {/* Footer */}
        <footer className="border-t border-slate-200/50 dark:border-slate-700/50 bg-white/50 dark:bg-slate-900/50 backdrop-blur-sm">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 text-sm text-slate-500 dark:text-slate-400">
              <p>&copy; {new Date().getFullYear()} StackWatch. All rights reserved.</p>
              <span className="font-mono text-xs">v{APP_METADATA.version}</span>
            </div>
          </div>
        </footer>
      </div>
    </div>
  );
};

export default AppLayout;
