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
        {/* Sidebar - Seamlessly aligned below header (header py-8 = 4rem padding + ~2.5rem content = 6.5rem total) */}
        <aside
          className={`${
            sidebarVisible ? 'translate-x-0' : '-translate-x-full'
          } fixed lg:fixed top-[6.5rem] left-0 h-[calc(100vh-6.5rem)] w-72 bg-slate-100 dark:bg-brand-800 border-r border-slate-200 dark:border-brand-700 z-40 transition-all duration-300 ease-in-out flex flex-col shadow-xl`}
        >
          <div className="p-4 border-b border-slate-200 dark:border-brand-700 flex items-center justify-between bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20">
            <h2 className="text-xl font-bold text-slate-900 dark:text-white transition-colors duration-200">Documentation</h2>
            <button
              onClick={toggleSidebar}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors p-1.5 rounded hover:bg-slate-200 dark:hover:bg-brand-700"
              aria-label="Toggle sidebar"
              title={sidebarVisible ? "Hide sidebar" : "Show sidebar"}
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                {/* Hamburger menu icon - three horizontal lines */}
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
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

        {/* Content Area - No overlap with sidebar */}
        <div className={`flex-1 flex flex-col min-w-0 transition-all duration-300 ${
          sidebarVisible ? 'lg:ml-72' : 'lg:ml-0'
        }`}>
          <div className={`pt-28 sm:pt-28 lg:pt-28 px-4 sm:px-6 lg:px-8 xl:px-12 pb-4 sm:pb-6 lg:pb-8 xl:pb-12 flex-1 transition-all duration-300 ${
            sidebarVisible ? 'lg:pl-8' : 'lg:pl-20'
          }`}>
            <div className="max-w-4xl mx-auto">
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

              {/* Markdown Content - Professional Industry Standard Formatting */}
              {!docLoading && markdownContent && (
                <article className="bg-white dark:bg-brand-800 border border-slate-200 dark:border-brand-700 rounded-lg shadow-lg overflow-hidden transition-colors duration-200">
                  <div className="prose prose-slate dark:prose-invert max-w-none
                    prose-headings:font-semibold prose-headings:text-slate-900 dark:prose-headings:text-slate-100
                    prose-h1:text-4xl prose-h1:font-bold prose-h1:mb-6 prose-h1:mt-0 prose-h1:pb-4 prose-h1:border-b prose-h1:border-slate-200 dark:prose-h1:border-brand-700
                    prose-h2:text-2xl prose-h2:font-semibold prose-h2:mt-10 prose-h2:mb-4 prose-h2:pb-2 prose-h2:border-b prose-h2:border-slate-200 dark:prose-h2:border-brand-700 prose-h2:text-slate-800 dark:prose-h2:text-slate-100
                    prose-h3:text-xl prose-h3:font-semibold prose-h3:mt-8 prose-h3:mb-3 prose-h3:text-slate-800 dark:prose-h3:text-slate-200
                    prose-h4:text-lg prose-h4:font-semibold prose-h4:mt-6 prose-h4:mb-2 prose-h4:text-slate-700 dark:prose-h4:text-slate-300
                    prose-p:text-slate-700 dark:prose-p:text-slate-300 prose-p:leading-7 prose-p:my-4
                    prose-a:text-blue-600 dark:prose-a:text-blue-400 prose-a:no-underline hover:prose-a:underline prose-a:font-medium
                    prose-strong:text-slate-900 dark:prose-strong:text-white prose-strong:font-semibold
                    prose-code:text-blue-700 dark:prose-code:text-blue-300 prose-code:bg-slate-100 dark:prose-code:bg-brand-900 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-code:text-sm prose-code:font-mono prose-code:before:content-[''] prose-code:after:content-['']
                    prose-pre:bg-slate-900 dark:prose-pre:bg-brand-950 prose-pre:border prose-pre:border-slate-700 dark:prose-pre:border-brand-600 prose-pre:rounded-lg prose-pre:p-4 prose-pre:overflow-x-auto
                    prose-img:rounded-lg prose-img:shadow-md prose-img:border prose-img:border-slate-200 dark:prose-img:border-brand-700 prose-img:max-w-full prose-img:h-auto prose-img:my-6
                    prose-ul:my-4 prose-ul:pl-6 prose-ul:list-disc
                    prose-ol:my-4 prose-ol:pl-6 prose-ol:list-decimal
                    prose-li:my-2 prose-li:leading-7
                    prose-table:w-full prose-table:my-6 prose-table:border-collapse prose-table:border prose-table:border-slate-300 dark:prose-table:border-brand-600 prose-table:rounded-lg prose-table:overflow-hidden
                    prose-th:bg-slate-100 dark:prose-th:bg-brand-700 prose-th:text-slate-900 dark:prose-th:text-slate-100 prose-th:font-semibold prose-th:p-3 prose-th:border prose-th:border-slate-300 dark:prose-th:border-brand-600 prose-th:text-left prose-th:align-top
                    prose-td:p-3 prose-td:border prose-td:border-slate-300 dark:prose-td:border-brand-600 prose-td:text-slate-700 dark:prose-td:text-slate-300 prose-td:align-top prose-td:text-left
                    prose-tr:border-b prose-tr:border-slate-200 dark:prose-tr:border-brand-700 prose-tr:hover:bg-slate-50 dark:prose-tr:hover:bg-brand-800/50
                    prose-hr:border-slate-300 dark:prose-hr:border-brand-600 prose-hr:my-8
                    prose-blockquote:border-l-4 prose-blockquote:border-blue-500 prose-blockquote:pl-4 prose-blockquote:italic prose-blockquote:text-slate-600 dark:prose-blockquote:text-slate-400 prose-blockquote:my-6
                    [&_table]:w-full [&_table]:border-collapse [&_table]:border [&_table]:border-slate-300 [&_table]:dark:border-brand-600 [&_table]:rounded-lg [&_table]:overflow-hidden [&_table]:my-6
                    [&_th]:bg-slate-100 [&_th]:dark:bg-brand-700 [&_th]:text-slate-900 [&_th]:dark:text-slate-100 [&_th]:font-semibold [&_th]:p-3 [&_th]:border [&_th]:border-slate-300 [&_th]:dark:border-brand-600 [&_th]:text-left [&_th]:align-top
                    [&_td]:p-3 [&_td]:border [&_td]:border-slate-300 [&_td]:dark:border-brand-600 [&_td]:text-slate-700 [&_td]:dark:text-slate-300 [&_td]:align-top [&_td]:text-left
                    [&_tr]:border-b [&_tr]:border-slate-200 [&_tr]:dark:border-brand-700 [&_tr:hover]:bg-slate-50 [&_tr:hover]:dark:bg-brand-800/50
                    [&_p]:text-slate-700 [&_p]:dark:text-slate-300 [&_p]:leading-7 [&_p]:my-4
                    [&_strong]:text-slate-900 [&_strong]:dark:text-white [&_strong]:font-semibold
                    [&_code]:text-blue-700 [&_code]:dark:text-blue-300 [&_code]:bg-slate-100 [&_code]:dark:bg-brand-900 [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:rounded [&_code]:text-sm [&_code]:font-mono
                    [&_pre]:bg-slate-900 [&_pre]:dark:bg-brand-950 [&_pre]:border [&_pre]:border-slate-700 [&_pre]:dark:border-brand-600 [&_pre]:rounded-lg [&_pre]:p-4 [&_pre]:overflow-x-auto
                    [&_ul]:my-4 [&_ul]:pl-6 [&_ul]:list-disc
                    [&_ol]:my-4 [&_ol]:pl-6 [&_ol]:list-decimal
                    [&_li]:my-2 [&_li]:leading-7">
                    <div className="px-6 py-8 sm:px-8 sm:py-10 lg:px-12 lg:py-12">
                      <ReactMarkdown remarkPlugins={[remarkGfm]}>
                        {markdownContent}
                      </ReactMarkdown>
                    </div>
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
