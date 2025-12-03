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
  const [expandedSections, setExpandedSections] = useState<Set<string>>(new Set());
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

  // Handle menu item click
  const handleMenuClick = (item: MenuItem): void => {
    if (item.type === 'file' && item.path) {
      fetchDocument(item.path);
      // Close sidebar on mobile after selection
      if (window.innerWidth < 1024) {
        setSidebarVisible(false);
      }
    } else if (item.type === 'section' && item.children) {
      // Toggle section expansion
      const sectionKey = item.title;
      setExpandedSections(prev => {
        const newSet = new Set(prev);
        if (newSet.has(sectionKey)) {
          newSet.delete(sectionKey);
        } else {
          newSet.add(sectionKey);
        }
        return newSet;
      });
    }
  };

  // Toggle sidebar visibility
  const toggleSidebar = (): void => {
    setSidebarVisible(prev => !prev);
  };

  // Render sidebar menu
  const renderSidebar = () => {
    const renderMenuItem = (item: MenuItem, level: number = 0) => {
      const isExpanded = item.type === 'section' && expandedSections.has(item.title);
      const isSelected = item.type === 'file' && item.path === selectedDoc;
      const hasChildren = item.type === 'section' && item.children && item.children.length > 0;

      return (
        <div key={`${item.title}-${level}`}>
          <button
            onClick={() => handleMenuClick(item)}
            className={`w-full text-left px-4 py-2 rounded-lg transition-colors ${
              isSelected
                ? 'bg-blue-600 dark:bg-blue-600 text-white'
                : 'text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-brand-700 hover:text-slate-900 dark:hover:text-white'
            } ${level > 0 ? 'pl-8' : ''}`}
          >
            <div className="flex items-center justify-between">
              <span className="font-medium">{item.title}</span>
              {hasChildren && (
                <svg
                  className={`w-4 h-4 transition-transform ${isExpanded ? 'rotate-90' : ''}`}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              )}
            </div>
          </button>
          {hasChildren && isExpanded && (
            <div className="mt-1 ml-2 border-l border-slate-300 dark:border-brand-600 pl-2">
              {item.children!.map(child => renderMenuItem(child, level + 1))}
            </div>
          )}
        </div>
      );
    };

    return (
      <div className="h-full overflow-y-auto">
        <div className="space-y-1">
          {menuItems.map(item => renderMenuItem(item))}
        </div>
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
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
            <p className="text-slate-600 dark:text-slate-400 transition-colors duration-200">Loading documentation...</p>
          </div>
        </main>
        <Footer />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col bg-slate-50 dark:bg-brand-900 text-slate-900 dark:text-slate-100 font-sans transition-colors duration-200">
      <Header />
      
      <main className="flex-grow flex flex-col lg:flex-row relative">
        {/* Sidebar Toggle Button - Always visible */}
        <button
          onClick={toggleSidebar}
          className={`fixed top-20 left-4 z-50 bg-slate-100 dark:bg-brand-800 border border-slate-200 dark:border-brand-700 rounded-lg p-2 text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white hover:bg-slate-200 dark:hover:bg-brand-700 transition-all duration-200 shadow-lg ${
            !sidebarVisible ? 'lg:left-4' : 'lg:left-[19rem]'
          }`}
          aria-label="Toggle sidebar"
          title={sidebarVisible ? "Hide sidebar" : "Show sidebar"}
        >
          <svg
            className="w-6 h-6"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            {sidebarVisible ? (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 19l-7-7 7-7m8 14l-7-7 7-7" />
            ) : (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 5l7 7-7 7M5 5l7 7-7 7" />
            )}
          </svg>
        </button>

        {/* Sidebar */}
        <aside
          className={`${
            sidebarVisible ? 'translate-x-0' : '-translate-x-full'
          } fixed lg:fixed top-0 left-0 h-screen w-72 bg-slate-100 dark:bg-brand-800 border-r border-slate-200 dark:border-brand-700 z-40 transition-all duration-300 ease-in-out flex flex-col shadow-xl`}
        >
          <div className="p-4 border-b border-slate-200 dark:border-brand-700 flex items-center justify-between bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20">
            <h2 className="text-xl font-bold text-slate-900 dark:text-white transition-colors duration-200">Documentation</h2>
            <button
              onClick={toggleSidebar}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors p-1 rounded hover:bg-slate-200 dark:hover:bg-brand-700"
              aria-label="Close sidebar"
              title="Hide sidebar"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div className="flex-1 overflow-y-auto p-4">
            {menuItems.length > 0 ? (
              renderSidebar()
            ) : (
              <p className="text-slate-600 dark:text-slate-400 text-sm transition-colors duration-200">No documentation available</p>
            )}
          </div>
        </aside>

        {/* Overlay for mobile/tablet */}
        {sidebarVisible && (
          <div
            className="lg:hidden fixed inset-0 bg-black bg-opacity-50 z-30 transition-opacity duration-300"
            onClick={() => setSidebarVisible(false)}
          />
        )}

        {/* Content Area */}
        <div className={`flex-1 flex flex-col min-w-0 transition-all duration-300 ${
          sidebarVisible ? 'lg:ml-72' : 'lg:ml-0'
        }`}>
          <div className="p-4 sm:p-6 lg:p-8 xl:p-12 flex-1">
            <div className="max-w-5xl mx-auto">
              {/* Back Button */}
              <button
                onClick={() => navigate('/')}
                className="mb-6 flex items-center text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 transition-colors duration-200"
              >
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clipRule="evenodd" />
                </svg>
                Back to Dashboard
              </button>

              {/* Loading State */}
              {docLoading && (
                <div className="text-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto mb-4"></div>
                  <p className="text-slate-600 dark:text-slate-400 transition-colors duration-200">Loading document...</p>
                </div>
              )}

              {/* Error State */}
              {error && !docLoading && (
                <div className="text-red-600 dark:text-red-400 mb-4 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-500/30 rounded transition-colors duration-200">
                  <p className="font-semibold">Error loading documentation:</p>
                  <p>{error}</p>
                </div>
              )}

              {/* Markdown Content - Professional Styling */}
              {!docLoading && markdownContent && (
                <article className="bg-white dark:bg-brand-800 border border-slate-200 dark:border-brand-700 rounded-2xl shadow-2xl overflow-hidden transition-colors duration-200">
                  {/* Content Container with Professional Padding */}
                  <div className="p-8 sm:p-10 lg:p-12 xl:p-16 prose dark:prose-invert max-w-none
                    prose-headings:text-slate-900 dark:prose-headings:text-white prose-headings:font-bold
                    prose-h1:text-5xl prose-h1:font-extrabold prose-h1:mb-10 prose-h1:mt-0 prose-h1:text-center prose-h1:border-b-2 prose-h1:border-slate-300 dark:prose-h1:border-brand-600 prose-h1:pb-6 prose-h1:bg-gradient-to-r prose-h1:from-blue-600 prose-h1:to-indigo-600 prose-h1:bg-clip-text prose-h1:text-transparent dark:prose-h1:from-blue-400 dark:prose-h1:to-indigo-400
                    prose-h2:text-3xl prose-h2:font-bold prose-h2:mt-12 prose-h2:mb-8 prose-h2:border-b prose-h2:border-slate-300 dark:prose-h2:border-brand-600 prose-h2:pb-4 prose-h2:text-left prose-h2:text-slate-800 dark:prose-h2:text-slate-100
                    prose-h3:text-2xl prose-h3:font-semibold prose-h3:mt-10 prose-h3:mb-6 prose-h3:text-left prose-h3:text-slate-800 dark:prose-h3:text-slate-200
                    prose-h4:text-xl prose-h4:font-semibold prose-h4:mt-8 prose-h4:mb-4 prose-h4:text-left prose-h4:text-slate-700 dark:prose-h4:text-slate-300
                    prose-p:text-slate-700 dark:prose-p:text-slate-300 prose-p:leading-relaxed prose-p:my-5 prose-p:text-left prose-p:text-base
                    prose-a:text-blue-600 dark:prose-a:text-blue-400 prose-a:no-underline hover:prose-a:text-blue-700 dark:hover:prose-a:text-blue-300 prose-a:font-semibold prose-a:border-b-2 prose-a:border-blue-300 dark:prose-a:border-blue-600 hover:prose-a:border-blue-500
                    prose-strong:text-slate-900 dark:prose-strong:text-white prose-strong:font-bold prose-strong:text-lg
                    prose-code:text-blue-700 dark:prose-code:text-blue-300 prose-code:bg-slate-100 dark:prose-code:bg-brand-900 prose-code:px-2 prose-code:py-1 prose-code:rounded-md prose-code:text-sm prose-code:font-mono prose-code:border prose-code:border-slate-200 dark:prose-code:border-brand-700
                    prose-pre:bg-gradient-to-br prose-pre:from-slate-900 prose-pre:to-slate-800 dark:prose-pre:from-brand-950 dark:prose-pre:to-brand-900 prose-pre:border prose-pre:border-slate-700 dark:prose-pre:border-brand-600 prose-pre:rounded-xl prose-pre:p-6 prose-pre:overflow-x-auto prose-pre:shadow-inner
                    prose-img:rounded-xl prose-img:shadow-2xl prose-img:border-2 prose-img:border-slate-200 dark:prose-img:border-brand-700 prose-img:max-w-full prose-img:h-auto prose-img:my-8 prose-img:mx-auto prose-img:ring-4 prose-img:ring-slate-100 dark:prose-img:ring-brand-800
                    prose-ul:list-disc prose-ul:ml-8 prose-ul:my-6 prose-ul:text-left prose-ul:space-y-2
                    prose-ol:list-decimal prose-ol:ml-8 prose-ol:my-6 prose-ol:text-left prose-ol:space-y-2
                    prose-li:my-3 prose-li:leading-relaxed prose-li:pl-2 prose-li:text-left prose-li:text-base
                    prose-table:w-full prose-table:my-10 prose-table:border-collapse prose-table:shadow-xl prose-table:rounded-xl prose-table:overflow-hidden prose-table:ring-1 prose-table:ring-slate-200 dark:prose-table:ring-brand-700
                    prose-th:bg-gradient-to-r prose-th:from-blue-600 prose-th:to-indigo-600 dark:prose-th:from-blue-700 dark:prose-th:to-indigo-700 prose-th:text-white prose-th:font-bold prose-th:p-5 prose-th:border prose-th:border-blue-500 dark:prose-th:border-blue-600 prose-th:text-left prose-th:align-top prose-th:text-base prose-th:uppercase prose-th:tracking-wide
                    prose-td:p-5 prose-td:border prose-td:border-slate-200 dark:prose-td:border-brand-600 prose-td:text-slate-700 dark:prose-td:text-slate-300 prose-td:align-top prose-td:text-left prose-td:text-base prose-td:bg-slate-50 dark:prose-td:bg-brand-800/50
                    prose-tr:hover:bg-blue-50 dark:prose-tr:hover:bg-blue-900/20 prose-tr:transition-colors prose-tr:duration-200
                    prose-hr:border-slate-300 dark:prose-hr:border-brand-600 prose-hr:my-12 prose-hr:border-t-2 prose-hr:border-dashed
                    prose-blockquote:border-l-4 prose-blockquote:border-blue-500 prose-blockquote:pl-6 prose-blockquote:pr-6 prose-blockquote:py-4 prose-blockquote:italic prose-blockquote:bg-gradient-to-r prose-blockquote:from-blue-50 prose-blockquote:to-indigo-50 dark:prose-blockquote:from-blue-900/20 dark:prose-blockquote:to-indigo-900/20 prose-blockquote:text-slate-700 dark:prose-blockquote:text-slate-300 prose-blockquote:rounded-r-xl prose-blockquote:my-8 prose-blockquote:shadow-sm prose-blockquote:text-lg">
                    <ReactMarkdown remarkPlugins={[remarkGfm]}>
                      {markdownContent}
                    </ReactMarkdown>
                  </div>
                </article>
              )}
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default HelpPage;
