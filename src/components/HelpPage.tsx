import React, { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import AppLayout from './AppLayout';
import DocumentationSidebar from './DocumentationSidebar';

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
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [docLoading, setDocLoading] = useState<boolean>(false);

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
    }
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

  const documentationSidebar = (
    <DocumentationSidebar
      menuItems={menuItems}
      selectedDoc={selectedDoc}
      onMenuClick={handleMenuClick}
    />
  );

  const breadcrumbs = [
    { label: 'Home', path: '/' },
    { label: 'Documentation' },
  ];

  return (
    <AppLayout
      breadcrumbs={breadcrumbs}
      showProfile={false}
      sidebarVariant="documentation"
      documentationSidebar={documentationSidebar}
    >
      <div className="max-w-4xl mx-auto">
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
    </AppLayout>
  );
};

export default HelpPage;
