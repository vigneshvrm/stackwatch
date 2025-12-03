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

  // Render sidebar menu - Professional Documentation Style
  const renderMenuItem = (item: MenuItem, level: number = 0, index: number = 0) => {
    const isExpanded = item.type === 'section' && expandedSections.has(item.title);
    const isSelected = item.type === 'file' && item.path === selectedDoc;
    const hasChildren = item.type === 'section' && item.children && item.children.length > 0;

    return (
      <div key={`${item.title}-${level}-${index}`}>
        <button
          onClick={() => handleMenuClick(item)}
          className={`w-full text-left px-3 py-2 rounded transition-colors duration-150 ${
            isSelected
              ? 'bg-blue-600 text-white font-medium'
              : 'text-slate-200 hover:bg-slate-700 dark:hover:bg-slate-700 hover:text-white'
          } ${level > 0 ? 'pl-6 text-sm' : 'font-medium'}`}
        >
          <div className="flex items-center justify-between">
            <span>{item.title}</span>
            {hasChildren && (
              <svg
                className={`w-4 h-4 transition-transform duration-200 ${isExpanded ? 'rotate-90' : ''}`}
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
          <div className="mt-1 ml-2 border-l border-slate-600 dark:border-slate-600 pl-2 space-y-0.5">
            {item.children!.map((child, childIndex) => renderMenuItem(child, level + 1, childIndex))}
          </div>
        )}
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
        {/* Floating button to show sidebar when hidden - Aligned with header */}
        {!sidebarVisible && (
          <button
            onClick={toggleSidebar}
            className="fixed top-[6.5rem] left-4 z-50 bg-slate-800 dark:bg-slate-900 border border-slate-700 dark:border-slate-700 rounded-lg p-2.5 text-slate-200 hover:text-white hover:bg-slate-700 dark:hover:bg-slate-800 transition-all duration-200 shadow-lg"
            aria-label="Show sidebar"
            title="Show sidebar"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              {/* Hamburger menu icon - three horizontal lines */}
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
        )}

        {/* Sidebar - Professional Documentation Style (Dark, Clean) - Seamlessly aligned with header */}
        <aside
          className={`${
            sidebarVisible ? 'translate-x-0' : '-translate-x-full'
          } fixed lg:fixed top-[6.5rem] left-0 h-[calc(100vh-6.5rem)] w-72 bg-slate-800 dark:bg-slate-900 border-r border-slate-700 dark:border-slate-700 z-40 transition-all duration-300 ease-in-out flex flex-col`}
        >
          {/* Sidebar Header - Professional Style */}
          <div className="p-4 border-b border-slate-700 dark:border-slate-700 flex items-center justify-between bg-slate-700 dark:bg-slate-800">
            <div className="flex items-center space-x-2">
              <svg className="w-5 h-5 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 8h10M7 12h10M7 16h10" />
              </svg>
              <h2 className="text-lg font-semibold text-white">StackWatch</h2>
            </div>
            <button
              onClick={toggleSidebar}
              className="text-slate-300 hover:text-white transition-colors p-1.5 rounded hover:bg-slate-600 dark:hover:bg-slate-700"
              aria-label="Hide sidebar"
              title="Hide sidebar"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                {/* Hamburger menu icon - three horizontal lines */}
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
          </div>
          
          {/* Navigation Menu - Professional Documentation Style */}
          <div className="flex-1 overflow-y-auto">
            <nav className="p-2">
              {menuItems.length > 0 ? (
                <div className="space-y-0.5">
                  {menuItems.map((item, index) => renderMenuItem(item, 0, index))}
                </div>
              ) : (
                <p className="text-slate-400 text-sm p-4">No documentation available</p>
              )}
            </nav>
          </div>
        </aside>

        {/* Overlay for mobile/tablet */}
        {sidebarVisible && (
          <div
            className="lg:hidden fixed inset-0 bg-black bg-opacity-50 z-30 transition-opacity duration-300"
            onClick={() => setSidebarVisible(false)}
          />
        )}

        {/* Content Area - Professional Documentation Style */}
        <div className={`flex-1 flex flex-col min-w-0 transition-all duration-300 ${
          sidebarVisible ? 'lg:ml-72' : 'lg:ml-0'
        }`}>
          <div className={`pt-6 px-6 sm:px-8 lg:px-12 xl:px-16 pb-8 sm:pb-12 lg:pb-16 flex-1 transition-all duration-300 ${
            sidebarVisible ? 'lg:pl-8' : 'lg:pl-6'
          }`}>
            <div className="max-w-4xl">
              {/* Back Button */}
              <button
                onClick={() => navigate('/')}
                className="mb-8 flex items-center text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 transition-colors duration-200 text-sm font-medium"
              >
                <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 mr-2" viewBox="0 0 20 20" fill="currentColor">
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

              {/* Markdown Content - Professional Documentation Style */}
              {!docLoading && markdownContent && (
                <article className="prose prose-slate dark:prose-invert max-w-none
                  prose-headings:font-bold prose-headings:text-slate-900 dark:prose-headings:text-slate-100 prose-headings:tracking-tight
                  prose-h1:text-4xl prose-h1:font-bold prose-h1:mb-4 prose-h1:mt-0 prose-h1:text-slate-900 dark:prose-h1:text-slate-100
                  prose-h2:text-2xl prose-h2:font-semibold prose-h2:mt-10 prose-h2:mb-4 prose-h2:text-slate-900 dark:prose-h2:text-slate-100 prose-h2:border-b prose-h2:border-slate-200 dark:prose-h2:border-slate-700 prose-h2:pb-2
                  prose-h3:text-xl prose-h3:font-semibold prose-h3:mt-8 prose-h3:mb-3 prose-h3:text-slate-800 dark:prose-h3:text-slate-200
                  prose-h4:text-lg prose-h4:font-semibold prose-h4:mt-6 prose-h4:mb-2 prose-h4:text-slate-700 dark:prose-h4:text-slate-300
                  prose-p:text-slate-700 dark:prose-p:text-slate-300 prose-p:leading-relaxed prose-p:my-4
                  prose-a:text-blue-600 dark:prose-a:text-blue-400 prose-a:no-underline hover:prose-a:underline
                  prose-strong:text-slate-900 dark:prose-strong:text-white prose-strong:font-semibold
                  prose-code:text-blue-700 dark:prose-code:text-blue-300 prose-code:bg-slate-100 dark:prose-code:bg-slate-800 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-code:text-sm prose-code:font-mono prose-code:before:content-[''] prose-code:after:content-['']
                  prose-pre:bg-slate-900 dark:prose-pre:bg-slate-950 prose-pre:border prose-pre:border-slate-700 prose-pre:rounded-lg prose-pre:p-4 prose-pre:overflow-x-auto
                  prose-img:rounded-lg prose-img:shadow-md prose-img:border prose-img:border-slate-200 dark:prose-img:border-slate-700 prose-img:max-w-full prose-img:h-auto prose-img:my-6
                  prose-ul:my-4 prose-ul:pl-6
                  prose-ol:my-4 prose-ol:pl-6
                  prose-li:my-2 prose-li:leading-relaxed
                  prose-table:w-full prose-table:my-6 prose-table:border-collapse prose-table:border prose-table:border-slate-300 dark:prose-table:border-slate-600
                  prose-th:bg-slate-100 dark:prose-th:bg-slate-700 prose-th:text-slate-900 dark:prose-th:text-slate-100 prose-th:font-semibold prose-th:p-3 prose-th:border prose-th:border-slate-300 dark:prose-th:border-slate-600 prose-th:text-left
                  prose-td:p-3 prose-td:border prose-td:border-slate-300 dark:prose-td:border-slate-600 prose-td:text-slate-700 dark:prose-td:text-slate-300 prose-td:text-left
                  prose-tr:border-b prose-tr:border-slate-200 dark:prose-tr:border-slate-700
                  prose-hr:border-slate-300 dark:prose-hr:border-slate-600 prose-hr:my-8
                  prose-blockquote:border-l-4 prose-blockquote:border-blue-500 prose-blockquote:pl-4 prose-blockquote:italic prose-blockquote:text-slate-600 dark:prose-blockquote:text-slate-400 prose-blockquote:my-6">
                  <ReactMarkdown remarkPlugins={[remarkGfm]}>
                    {markdownContent}
                  </ReactMarkdown>
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
