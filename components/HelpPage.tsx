import React, { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { useNavigate } from 'react-router-dom';
import Header from './Header';
import Footer from './Footer';

interface MenuItem {
  title: string;
  type: 'file' | 'section';
  path?: string;
  children?: MenuItem[];
}

interface Manifest {
  sections: MenuItem[];
}

const HelpPage: React.FC = () => {
  const navigate = useNavigate();
  const [menuItems, setMenuItems] = useState<MenuItem[]>([]);
  const [selectedDoc, setSelectedDoc] = useState<string>('');
  const [markdownContent, setMarkdownContent] = useState<string>('');
  const [sidebarVisible, setSidebarVisible] = useState<boolean>(true);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [docLoading, setDocLoading] = useState<boolean>(false);

  // Fetch manifest.json
  const fetchManifest = async (): Promise<void> => {
    try {
      const response = await fetch('/help/docs/manifest.json');
      if (!response.ok) {
        throw new Error('Manifest not found');
      }
      const manifest: Manifest = await response.json();
      setMenuItems(manifest.sections || []);
      
      // Auto-select first document if available
      const firstDoc = findFirstDocument(manifest.sections);
      if (firstDoc) {
        setSelectedDoc(firstDoc);
        fetchDocument(firstDoc);
      } else {
        setLoading(false);
        setError('No documentation files found in manifest');
      }
    } catch (err) {
      console.error('Error loading manifest:', err);
      setError('Failed to load documentation manifest');
      setLoading(false);
      // Fallback to default content
      setMarkdownContent(getDefaultHelpContent());
      setLoading(false);
    }
  };

  // Find first document in menu structure
  const findFirstDocument = (items: MenuItem[]): string | null => {
    for (const item of items) {
      if (item.type === 'file' && item.path) {
        return item.path;
      }
      if (item.type === 'section' && item.children) {
        const found = findFirstDocument(item.children);
        if (found) return found;
      }
    }
    return null;
  };

  // Fetch document content
  const fetchDocument = async (path: string): Promise<void> => {
    setDocLoading(true);
    setError(null);
    try {
      const response = await fetch(`/help/docs/${path}`);
      if (!response.ok) {
        throw new Error(`Document not found: ${path}`);
      }
      const text = await response.text();
      setMarkdownContent(text);
      setSelectedDoc(path);
    } catch (err) {
      console.error('Error loading document:', err);
      setError(`Failed to load document: ${path}`);
      setMarkdownContent(`# Error\n\nUnable to load the requested document: \`${path}\``);
    } finally {
      setDocLoading(false);
      setLoading(false);
    }
  };

  // Handle menu item click - only for file items
  const handleMenuClick = (item: MenuItem): void => {
    if (item.type === 'file' && item.path) {
      fetchDocument(item.path);
      // Close sidebar on mobile after selection
      if (window.innerWidth < 1024) {
        setSidebarVisible(false);
      }
    }
    // Section items are not clickable - they're just category headers
  };

  // Toggle sidebar visibility
  const toggleSidebar = (): void => {
    setSidebarVisible(prev => !prev);
  };

  // Render sidebar menu - Flat structure like Ceph docs (no expandable sections)
  const renderMenuItem = (item: MenuItem, level: number = 0, index: number = 0) => {
    const isSelected = item.type === 'file' && item.path === selectedDoc;
    const hasChildren = item.type === 'section' && item.children && item.children.length > 0;

    // Section headers are non-clickable category labels
    if (item.type === 'section') {
      return (
        <div key={`${item.title}-${level}-${index}`} className="mt-4 first:mt-0">
          {/* Section header - non-clickable label */}
          <div className="px-4 py-2 text-slate-400 dark:text-slate-400 text-xs uppercase font-semibold tracking-wider">
            {item.title}
          </div>
          {/* Always render children - flat structure */}
          {hasChildren && (
            <div className="space-y-0.5">
              {item.children!.map((child, childIndex) => renderMenuItem(child, level + 1, childIndex))}
            </div>
          )}
        </div>
      );
    }

    // File items are clickable menu items
    return (
      <div key={`${item.title}-${level}-${index}`}>
        <button
          onClick={() => handleMenuClick(item)}
          className={`w-full text-left px-4 py-2.5 rounded-md transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-slate-800 ${
            isSelected
              ? 'bg-blue-600 dark:bg-blue-600 text-white font-semibold shadow-sm ring-2 ring-blue-400/50'
              : 'text-slate-300 dark:text-slate-300 hover:bg-slate-700/50 dark:hover:bg-slate-700/50 hover:text-white dark:hover:text-white'
          } ${level > 0 ? 'pl-8 text-sm font-normal' : 'font-medium text-base'}`}
        >
          <span className="truncate">{item.title}</span>
        </button>
      </div>
    );
  };

  // Get default help content
  const getDefaultHelpContent = (): string => {
    return `# StackWatch Help & Documentation

Welcome to the StackWatch Observability Platform help documentation.

## Getting Started

### Accessing Services

- **Prometheus**: Access the Prometheus monitoring interface to view metrics and run queries
- **Grafana**: Access Grafana dashboards for data visualization and analytics
- **Help**: You're here! This documentation provides guidance on using the platform

## Features

### Prometheus
- Time-series data collection
- PromQL query language
- Alert management
- Target monitoring

### Grafana
- Interactive dashboards
- Data visualization
- Alert notifications
- Data source management

## Support

For additional support or questions, please contact your system administrator.

---

*Last updated: ${new Date().toLocaleDateString()}*`;
  };

  // Load manifest on mount
  useEffect(() => {
    fetchManifest();
  }, []);

  // Auto-hide sidebar on mobile, but allow manual toggle on desktop
  useEffect(() => {
    const handleResize = (): void => {
      // On mobile/tablet, auto-hide sidebar
      if (window.innerWidth < 1024) {
        setSidebarVisible(false);
      }
      // On desktop, keep current state (user preference)
    };

    window.addEventListener('resize', handleResize);
    // Initial check: hide on mobile, show on desktop
    if (window.innerWidth < 1024) {
      setSidebarVisible(false);
    }

    return () => window.removeEventListener('resize', handleResize);
  }, []);

  if (loading && !markdownContent) {
    return (
      <div className="min-h-screen flex flex-col bg-slate-50 dark:bg-brand-900 text-slate-900 dark:text-slate-100 transition-colors duration-200">
        <Header />
        <main className="flex-grow flex items-center justify-center">
          <div className="text-center">
            <div className="animate-spin rounded-full h-14 w-14 border-4 border-slate-200 dark:border-slate-700 border-t-blue-600 dark:border-t-blue-500 mx-auto mb-6"></div>
            <p className="text-slate-600 dark:text-slate-400 transition-colors duration-200 text-base font-medium">Loading documentation...</p>
          </div>
        </main>
        <Footer />
      </div>
    );
  }

  return (
    <div className="h-screen flex flex-col overflow-hidden bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 font-sans transition-colors duration-200">
      <Header />
      
      {/* Seamless Unified Container - Sidebar and Content as One Window */}
      <div className="flex flex-1 overflow-hidden bg-white dark:bg-slate-900" style={{ height: 'calc(100vh - 6.5rem)' }}>
        {/* Mobile toggle button */}
        {!sidebarVisible && (
          <button
            onClick={toggleSidebar}
            className="lg:hidden fixed top-24 left-4 z-50 bg-slate-800 dark:bg-slate-900 border border-slate-700/50 dark:border-slate-700/50 rounded-lg p-3 text-slate-200 hover:text-white hover:bg-slate-700/80 dark:hover:bg-slate-800/80 transition-all duration-200 shadow-xl hover:shadow-2xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
            aria-label="Show sidebar"
            title="Show sidebar"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
        )}

        {/* Sidebar - Fixed position, only scrolls internally if menu is long */}
        <aside
          className={`${
            sidebarVisible ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
          } fixed lg:relative w-80 h-full bg-slate-800 dark:bg-slate-900 border-r border-slate-700/30 dark:border-slate-700/30 flex flex-col transition-transform duration-300 ease-in-out lg:transition-none z-40 lg:z-auto flex-shrink-0`}
        >
          {/* Custom scrollbar styling for sidebar */}
          <style>{`
            .sidebar-scroll::-webkit-scrollbar {
              width: 8px;
            }
            .sidebar-scroll::-webkit-scrollbar-track {
              background: rgba(15, 23, 42, 0.3);
              border-radius: 4px;
            }
            .sidebar-scroll::-webkit-scrollbar-thumb {
              background: rgba(71, 85, 105, 0.5);
              border-radius: 4px;
            }
            .sidebar-scroll::-webkit-scrollbar-thumb:hover {
              background: rgba(71, 85, 105, 0.7);
            }
          `}</style>
          
          {/* Navigation Menu - Clean, minimal, no header branding */}
          <div className="flex-1 overflow-y-auto sidebar-scroll">
            <nav className="p-4">
              {/* Mobile close button */}
              <div className="lg:hidden flex justify-end mb-4">
                <button
                  onClick={toggleSidebar}
                  className="text-slate-400 hover:text-white transition-all duration-200 p-2 rounded-md hover:bg-slate-700/50 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  aria-label="Hide sidebar"
                  title="Hide sidebar"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
              {menuItems.length > 0 ? (
                <div className="space-y-1">
                  {menuItems.map((item, index) => renderMenuItem(item, 0, index))}
                </div>
              ) : (
                <p className="text-slate-400 text-sm p-4 text-center">No documentation available</p>
              )}
            </nav>
          </div>
        </aside>

        {/* Overlay for mobile/tablet */}
        {sidebarVisible && (
          <div
            className="lg:hidden fixed inset-0 bg-black/60 backdrop-blur-sm z-30 transition-opacity duration-300"
            onClick={() => setSidebarVisible(false)}
          />
        )}

        {/* Main Content Area - Scrolls independently within its container */}
        <main className="flex-1 overflow-y-auto bg-white dark:bg-slate-900 h-full min-w-0">
          <div className="pt-8 px-6 sm:px-8 lg:px-12 xl:px-20 pb-12 sm:pb-16 lg:pb-20">
            <div className="max-w-5xl mx-auto w-full">
              {/* Back Button */}
              <button
                onClick={() => navigate('/')}
                className="mb-10 flex items-center text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 transition-all duration-200 text-sm font-semibold group focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-slate-50 dark:focus:ring-offset-brand-900 rounded-md px-2 py-1 -ml-2"
              >
                <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-2 transition-transform duration-200 group-hover:-translate-x-1" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clipRule="evenodd" />
                </svg>
                Back to Dashboard
              </button>

              {/* Loading State */}
              {docLoading && (
                <div className="text-center py-16">
                  <div className="animate-spin rounded-full h-12 w-12 border-4 border-slate-200 dark:border-slate-700 border-t-blue-600 dark:border-t-blue-500 mx-auto mb-6"></div>
                  <p className="text-slate-600 dark:text-slate-400 transition-colors duration-200 text-base font-medium">Loading document...</p>
                </div>
              )}

              {/* Error State */}
              {error && !docLoading && (
                <div className="text-red-700 dark:text-red-400 mb-6 p-5 bg-red-50 dark:bg-red-900/20 border-l-4 border-red-500 dark:border-red-500 rounded-r-lg shadow-sm transition-colors duration-200">
                  <p className="font-bold text-lg mb-2">Error loading documentation</p>
                  <p className="text-sm">{error}</p>
                </div>
              )}

              {/* Markdown Content - Professional Documentation Style */}
              {!docLoading && markdownContent && (
                <article className="prose prose-slate dark:prose-invert max-w-none
                  prose-headings:font-bold prose-headings:text-slate-900 dark:prose-headings:text-slate-100 prose-headings:tracking-tight
                  prose-h1:text-5xl prose-h1:font-bold prose-h1:mb-6 prose-h1:mt-0 prose-h1:text-slate-900 dark:prose-h1:text-slate-100 prose-h1:leading-tight prose-h1:border-b prose-h1:border-slate-200 dark:prose-h1:border-slate-700 prose-h1:pb-4
                  prose-h2:text-3xl prose-h2:font-semibold prose-h2:mt-12 prose-h2:mb-5 prose-h2:text-slate-900 dark:prose-h2:text-slate-100 prose-h2:border-b prose-h2:border-slate-200 dark:prose-h2:border-slate-700 prose-h2:pb-3 prose-h2:leading-tight
                  prose-h3:text-2xl prose-h3:font-semibold prose-h3:mt-10 prose-h3:mb-4 prose-h3:text-slate-800 dark:prose-h3:text-slate-200 prose-h3:leading-snug
                  prose-h4:text-xl prose-h4:font-semibold prose-h4:mt-8 prose-h4:mb-3 prose-h4:text-slate-700 dark:prose-h4:text-slate-300 prose-h4:leading-snug
                  prose-p:text-slate-700 dark:prose-p:text-slate-300 prose-p:leading-relaxed prose-p:my-6 prose-p:text-base
                  prose-a:text-blue-600 dark:prose-a:text-blue-400 prose-a:no-underline hover:prose-a:underline prose-a:font-medium prose-a:transition-all prose-a:duration-200
                  prose-strong:text-slate-900 dark:prose-strong:text-white prose-strong:font-bold
                  prose-code:text-blue-700 dark:prose-code:text-blue-300 prose-code:bg-slate-100 dark:prose-code:bg-slate-800/80 prose-code:px-2 prose-code:py-1 prose-code:rounded-md prose-code:text-sm prose-code:font-mono prose-code:before:content-[''] prose-code:after:content-[''] prose-code:border prose-code:border-slate-200 dark:prose-code:border-slate-700
                  prose-pre:bg-slate-900 dark:prose-pre:bg-slate-950 prose-pre:border prose-pre:border-slate-700/50 prose-pre:rounded-xl prose-pre:p-5 prose-pre:overflow-x-auto prose-pre:shadow-lg prose-pre:my-8
                  prose-pre-code:bg-transparent prose-pre-code:border-0 prose-pre-code:p-0 prose-pre-code:text-slate-100
                  prose-img:rounded-xl prose-img:shadow-lg prose-img:border prose-img:border-slate-200 dark:prose-img:border-slate-700 prose-img:max-w-full prose-img:h-auto prose-img:my-8
                  prose-ul:my-6 prose-ul:pl-7 prose-ul:list-disc prose-ul:space-y-2
                  prose-ol:my-6 prose-ol:pl-7 prose-ol:list-decimal prose-ol:space-y-2
                  prose-li:my-2 prose-li:leading-relaxed prose-li:text-slate-700 dark:prose-li:text-slate-300 prose-li:text-base prose-li:pl-1
                  prose-table:w-full prose-table:my-8 prose-table:border-collapse prose-table:border prose-table:border-slate-300 dark:prose-table:border-slate-600 prose-table:rounded-lg prose-table:overflow-hidden prose-table:shadow-md
                  prose-th:bg-slate-100 dark:prose-th:bg-slate-800 prose-th:text-slate-900 dark:prose-th:text-slate-100 prose-th:font-bold prose-th:p-4 prose-th:border prose-th:border-slate-300 dark:prose-th:border-slate-600 prose-th:text-left prose-th:text-sm prose-th:uppercase prose-th:tracking-wider
                  prose-td:p-4 prose-td:border prose-td:border-slate-300 dark:prose-td:border-slate-600 prose-td:text-slate-700 dark:prose-td:text-slate-300 prose-td:text-left prose-td:text-sm
                  prose-tr:border-b prose-tr:border-slate-200 dark:prose-tr:border-slate-700 prose-tr:hover:bg-slate-50 dark:prose-tr:hover:bg-slate-800/30 prose-tr:transition-colors
                  prose-hr:border-slate-300 dark:prose-hr:border-slate-600 prose-hr:my-10 prose-hr:border-t-2
                  prose-blockquote:border-l-4 prose-blockquote:border-blue-500 dark:prose-blockquote:border-blue-400 prose-blockquote:pl-6 prose-blockquote:italic prose-blockquote:text-slate-600 dark:prose-blockquote:text-slate-400 prose-blockquote:my-8 prose-blockquote:bg-slate-50 dark:prose-blockquote:bg-slate-800/30 prose-blockquote:py-4 prose-blockquote:pr-4 prose-blockquote:rounded-r-lg">
                  <ReactMarkdown remarkPlugins={[remarkGfm]}>
                    {markdownContent}
                  </ReactMarkdown>
                </article>
              )}
            </div>
          </div>
        </main>
      </div>

      <Footer />
    </div>
  );
};

export default HelpPage;
