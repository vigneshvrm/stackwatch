import React, { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { Link } from 'react-router-dom';
import ThemeToggle from './ThemeToggle';

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
      setMarkdownContent(getDefaultHelpContent());
      setLoading(false);
    }
  };

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

  const handleMenuClick = (item: MenuItem): void => {
    if (item.type === 'file' && item.path) {
      fetchDocument(item.path);
      if (window.innerWidth < 1024) {
        setSidebarVisible(false);
      }
    }
  };

  const toggleSidebar = (): void => {
    setSidebarVisible(prev => !prev);
  };

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
          onClick={() => handleMenuClick(item)}
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

  const getDefaultHelpContent = (): string => {
    return `# StackWatch Documentation

Welcome to the StackWatch Observability Platform documentation.

## Getting Started

StackWatch provides comprehensive infrastructure monitoring through:

- **Prometheus** - Time-series metrics collection and alerting
- **Grafana** - Data visualization and dashboards
- **Node Exporter** - Linux server metrics
- **Windows Exporter** - Windows server metrics

## Quick Links

### Accessing Services

| Service | URL | Description |
|---------|-----|-------------|
| Prometheus | \`/prometheus/\` | Query metrics and manage alerts |
| Grafana | \`/grafana/\` | View dashboards (default: admin/admin) |
| Dashboard | \`/\` | Main StackWatch interface |

### Common Tasks

1. **View server metrics** - Navigate to Prometheus and use PromQL queries
2. **Create dashboards** - Use Grafana to visualize your data
3. **Set up alerts** - Configure alerting rules in Prometheus

## Support

For additional support, please contact your system administrator.

---

*Last updated: ${new Date().toLocaleDateString()}*`;
  };

  useEffect(() => {
    fetchManifest();
  }, []);

  useEffect(() => {
    const handleResize = (): void => {
      if (window.innerWidth < 1024) {
        setSidebarVisible(false);
      }
    };

    window.addEventListener('resize', handleResize);
    if (window.innerWidth < 1024) {
      setSidebarVisible(false);
    }

    return () => window.removeEventListener('resize', handleResize);
  }, []);

  if (loading && !markdownContent) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-slate-50 dark:bg-slate-900">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-4 border-slate-200 dark:border-slate-700 border-t-blue-500 mx-auto mb-4"></div>
          <p className="text-slate-500 dark:text-slate-400">Loading documentation...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-screen flex overflow-hidden bg-slate-50 dark:bg-slate-900">
      {/* Sidebar Overlay */}
      {sidebarVisible && (
        <div
          className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-40 lg:hidden"
          onClick={() => setSidebarVisible(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed lg:sticky top-0 left-0 h-screen w-72 z-50 lg:z-auto transform transition-transform duration-300 ease-in-out ${
          sidebarVisible ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        }`}
      >
        <div className="absolute inset-0 bg-white/80 dark:bg-slate-900/90 backdrop-blur-xl border-r border-slate-200/50 dark:border-slate-700/50" />

        <div className="relative h-full flex flex-col">
          {/* Header */}
          <div className="p-4 border-b border-slate-200/50 dark:border-slate-700/50">
            <Link to="/" className="flex items-center space-x-3 group">
              <div className="w-9 h-9 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center shadow-lg shadow-blue-500/25 transition-transform group-hover:scale-105">
                <span className="text-white font-bold text-lg">S</span>
              </div>
              <div>
                <h1 className="text-base font-bold text-slate-900 dark:text-white">StackWatch</h1>
                <p className="text-xs text-slate-500 dark:text-slate-400">Documentation</p>
              </div>
            </Link>

            {/* Mobile close button */}
            <button
              onClick={toggleSidebar}
              className="lg:hidden absolute top-4 right-4 p-2 rounded-xl text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-all"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          {/* Navigation */}
          <nav className="flex-1 overflow-y-auto p-3">
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
              className="flex items-center space-x-2 px-3 py-2 rounded-xl text-sm text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-white transition-all"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
              <span>Back to Dashboard</span>
            </Link>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Header */}
        <header className="sticky top-0 z-30 bg-white/80 dark:bg-slate-900/80 backdrop-blur-xl border-b border-slate-200/50 dark:border-slate-700/50">
          <div className="px-4 sm:px-6 lg:px-8 py-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                {/* Mobile menu button */}
                <button
                  onClick={toggleSidebar}
                  className="lg:hidden p-2 rounded-xl text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-all"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                  </svg>
                </button>

                {/* Breadcrumb */}
                <div className="hidden sm:flex items-center space-x-2 text-sm">
                  <Link to="/" className="text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 transition-colors">
                    Home
                  </Link>
                  <svg className="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                  <span className="text-slate-900 dark:text-white font-medium">Documentation</span>
                </div>
              </div>

              <ThemeToggle />
            </div>
          </div>
        </header>

        {/* Content */}
        <main className="flex-1 overflow-y-auto">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
            {/* Loading */}
            {docLoading && (
              <div className="text-center py-16">
                <div className="animate-spin rounded-full h-10 w-10 border-4 border-slate-200 dark:border-slate-700 border-t-blue-500 mx-auto mb-4"></div>
                <p className="text-slate-500 dark:text-slate-400 text-sm">Loading document...</p>
              </div>
            )}

            {/* Error */}
            {error && !docLoading && (
              <div className="rounded-2xl bg-red-500/10 border border-red-500/20 p-6 mb-8">
                <div className="flex items-start space-x-3">
                  <svg className="w-6 h-6 text-red-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                  <div>
                    <h3 className="font-semibold text-red-700 dark:text-red-400">Error loading documentation</h3>
                    <p className="text-sm text-red-600 dark:text-red-300 mt-1">{error}</p>
                  </div>
                </div>
              </div>
            )}

            {/* Markdown Content */}
            {!docLoading && markdownContent && (
              <article className="markdown-content">
                <ReactMarkdown remarkPlugins={[remarkGfm]}>
                  {markdownContent}
                </ReactMarkdown>
              </article>
            )}
          </div>
        </main>

        {/* Footer */}
        <footer className="border-t border-slate-200/50 dark:border-slate-700/50 bg-white/50 dark:bg-slate-900/50 backdrop-blur-sm">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <p className="text-sm text-slate-500 dark:text-slate-400 text-center">
              &copy; {new Date().getFullYear()} StackWatch Documentation
            </p>
          </div>
        </footer>
      </div>
    </div>
  );
};

export default HelpPage;
