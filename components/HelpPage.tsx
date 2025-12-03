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
                ? 'bg-blue-600 text-white'
                : 'text-slate-300 hover:bg-brand-700 hover:text-white'
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
            <div className="mt-1 ml-2 border-l border-brand-600 pl-2">
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
    return `# StackBill Help & Documentation

Welcome to the StackBill Observability Platform help documentation.

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

  // Auto-hide sidebar on mobile
  useEffect(() => {
    const handleResize = (): void => {
      if (window.innerWidth < 1024) {
        setSidebarVisible(false);
      } else {
        setSidebarVisible(true);
      }
    };

    window.addEventListener('resize', handleResize);
    handleResize(); // Initial check

    return () => window.removeEventListener('resize', handleResize);
  }, []);

  if (loading && !markdownContent) {
    return (
      <div className="min-h-screen flex flex-col bg-brand-900 text-slate-100">
        <Header />
        <main className="flex-grow flex items-center justify-center">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
            <p className="text-slate-400">Loading documentation...</p>
          </div>
        </main>
        <Footer />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col bg-brand-900 text-slate-100 font-sans">
      <Header />
      
      <main className="flex-grow flex flex-col lg:flex-row relative">
        {/* Sidebar Toggle Button */}
        <button
          onClick={toggleSidebar}
          className="fixed top-20 left-4 z-50 lg:hidden bg-brand-800 border border-brand-700 rounded-lg p-2 text-slate-300 hover:text-white hover:bg-brand-700 transition-colors shadow-lg"
          aria-label="Toggle sidebar"
        >
          <svg
            className="w-6 h-6"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            {sidebarVisible ? (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            ) : (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            )}
          </svg>
        </button>

        {/* Sidebar */}
        <aside
          className={`${
            sidebarVisible ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
          } fixed lg:sticky top-0 left-0 h-screen lg:h-auto w-72 bg-brand-800 border-r border-brand-700 z-40 transition-transform duration-300 ease-in-out flex flex-col`}
        >
          <div className="p-4 border-b border-brand-700 flex items-center justify-between">
            <h2 className="text-xl font-bold text-white">Documentation</h2>
            <button
              onClick={toggleSidebar}
              className="lg:hidden text-slate-400 hover:text-white transition-colors"
              aria-label="Close sidebar"
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
              <p className="text-slate-400 text-sm">No documentation available</p>
            )}
          </div>
        </aside>

        {/* Overlay for mobile */}
        {sidebarVisible && (
          <div
            className="lg:hidden fixed inset-0 bg-black bg-opacity-50 z-30"
            onClick={() => setSidebarVisible(false)}
          />
        )}

        {/* Content Area */}
        <div className="flex-1 flex flex-col min-w-0">
          <div className="p-4 sm:p-8 lg:p-12 flex-1">
            <div className="max-w-4xl mx-auto">
              {/* Back Button */}
              <button
                onClick={() => navigate('/')}
                className="mb-6 flex items-center text-blue-400 hover:text-blue-300 transition-colors"
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
                  <p className="text-slate-400">Loading document...</p>
                </div>
              )}

              {/* Error State */}
              {error && !docLoading && (
                <div className="text-red-400 mb-4 p-4 bg-red-900/20 border border-red-500/30 rounded">
                  <p className="font-semibold">Error loading documentation:</p>
                  <p>{error}</p>
                </div>
              )}

              {/* Markdown Content */}
              {!docLoading && markdownContent && (
                <div className="bg-brand-800 border border-brand-700 rounded-xl shadow-lg p-6 sm:p-8 lg:p-10 prose prose-invert prose-headings:text-white prose-h1:text-3xl prose-h1:font-bold prose-h1:mb-6 prose-h1:mt-0 prose-h2:text-2xl prose-h2:font-semibold prose-h2:mt-8 prose-h2:mb-4 prose-h2:border-b prose-h2:border-brand-600 prose-h2:pb-2 prose-h3:text-xl prose-h3:font-semibold prose-h3:mt-6 prose-h3:mb-3 prose-h4:text-lg prose-h4:font-semibold prose-h4:mt-4 prose-h4:mb-2 prose-p:text-slate-300 prose-p:leading-relaxed prose-p:my-4 prose-a:text-blue-400 prose-a:no-underline hover:prose-a:text-blue-300 prose-strong:text-white prose-strong:font-semibold prose-code:text-blue-300 prose-code:bg-brand-900 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-code:text-sm prose-code:font-mono prose-pre:bg-brand-900 prose-pre:border prose-pre:border-brand-700 prose-pre:rounded-lg prose-pre:p-4 prose-pre:overflow-x-auto prose-img:rounded-lg prose-img:shadow-lg prose-img:border prose-img:border-brand-700 prose-img:max-w-full prose-img:h-auto prose-img:my-6 prose-ul:list-disc prose-ul:ml-6 prose-ul:my-4 prose-ol:list-decimal prose-ol:ml-6 prose-ol:my-4 prose-li:my-2 prose-li:leading-relaxed prose-li:pl-1 prose-table:w-full prose-table:my-6 prose-th:bg-brand-700 prose-th:text-white prose-th:font-semibold prose-th:p-3 prose-th:border prose-th:border-brand-600 prose-td:p-3 prose-td:border prose-td:border-brand-600 prose-td:text-slate-300 prose-hr:border-brand-600 prose-hr:my-8 prose-blockquote:border-l-4 prose-blockquote:border-blue-500 prose-blockquote:pl-4 prose-blockquote:italic prose-blockquote:text-slate-400 max-w-none">
                  <ReactMarkdown remarkPlugins={[remarkGfm]}>
                    {markdownContent}
                  </ReactMarkdown>
                </div>
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
