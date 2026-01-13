import React from 'react';
import { Link } from 'react-router-dom';

interface MenuItem {
  title: string;
  type: 'file' | 'section';
  path?: string;
  children?: MenuItem[];
}

interface DocumentationSidebarProps {
  menuItems: MenuItem[];
  selectedDoc: string;
  onMenuClick: (item: MenuItem) => void;
  onClose?: () => void;
}

const DocumentationSidebar: React.FC<DocumentationSidebarProps> = ({
  menuItems,
  selectedDoc,
  onMenuClick,
  onClose,
}) => {
  const renderMenuItem = (item: MenuItem, level: number = 0, index: number = 0) => {
    const isSelected = item.type === 'file' && item.path === selectedDoc;
    const hasChildren = item.type === 'section' && item.children && item.children.length > 0;

    if (item.type === 'section') {
      return (
        <div key={`${item.title}-${level}-${index}`} className="mt-6 first:mt-0">
          <div className="px-4 py-2 text-xs uppercase font-semibold tracking-wider text-slate-400 dark:text-slate-500">
            {item.title}
          </div>
          {hasChildren && (
            <div className="space-y-0.5">
              {item.children!.map((child, childIndex) => renderMenuItem(child, level + 1, childIndex))}
            </div>
          )}
        </div>
      );
    }

    return (
      <div key={`${item.title}-${level}-${index}`}>
        <button
          onClick={() => onMenuClick(item)}
          className={`w-full text-left px-4 py-2.5 rounded-xl transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500/50 ${
            isSelected
              ? 'bg-blue-500/10 dark:bg-blue-500/20 text-blue-600 dark:text-blue-400 font-semibold'
              : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100/80 dark:hover:bg-slate-800/50 hover:text-slate-900 dark:hover:text-white'
          } ${level > 0 ? 'pl-8 text-sm' : 'text-sm font-medium'}`}
        >
          <span className="truncate flex items-center">
            {isSelected && (
              <span className="w-1.5 h-1.5 rounded-full bg-blue-500 mr-2" />
            )}
            {item.title}
          </span>
        </button>
      </div>
    );
  };

  return (
    <aside className="w-64 h-screen">
      <div className="absolute inset-0 bg-white/80 dark:bg-slate-900/90 backdrop-blur-xl border-r border-slate-200/50 dark:border-slate-700/50" />

      <div className="relative h-full flex flex-col">
        {/* Header */}
        <div className="p-6 border-b border-slate-200/50 dark:border-slate-700/50">
          <Link to="/" className="flex items-center space-x-3 group">
            <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center shadow-lg shadow-blue-500/25 transition-transform group-hover:scale-105">
              <span className="text-white font-bold text-xl">S</span>
            </div>
            <div>
              <h1 className="text-lg font-bold text-slate-900 dark:text-white">StackWatch</h1>
              <p className="text-xs text-slate-500 dark:text-slate-400">Documentation</p>
            </div>
          </Link>

          {/* Mobile close button */}
          {onClose && (
            <button
              onClick={onClose}
              className="lg:hidden absolute top-6 right-4 p-2 rounded-xl text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-all"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          )}
        </div>

        {/* Navigation */}
        <nav className="flex-1 overflow-y-auto p-4">
          {menuItems.length > 0 ? (
            <div className="space-y-1">
              {menuItems.map((item, index) => renderMenuItem(item, 0, index))}
            </div>
          ) : (
            <p className="text-slate-500 dark:text-slate-400 text-sm p-4 text-center">No documentation available</p>
          )}
        </nav>

        {/* Footer */}
        <div className="p-4 border-t border-slate-200/50 dark:border-slate-700/50">
          <Link
            to="/"
            className="flex items-center space-x-2 px-3 py-2.5 rounded-xl text-sm text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-white transition-all"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span>Back to Dashboard</span>
          </Link>
        </div>
      </div>
    </aside>
  );
};

export default DocumentationSidebar;
