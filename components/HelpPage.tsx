import React, { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { useNavigate } from 'react-router-dom';
import Header from './Header';
import Footer from './Footer';

const HelpPage: React.FC = () => {
  const navigate = useNavigate();
  const [markdownContent, setMarkdownContent] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Try to load help documentation
    // First, try to fetch from /help/docs/help.md (served by Nginx)
    fetch('/help/docs/help.md')
      .then((response) => {
        if (!response.ok) {
          throw new Error('Help documentation not found');
        }
        return response.text();
      })
      .then((text) => {
        setMarkdownContent(text);
        setLoading(false);
      })
      .catch(() => {
        // If file doesn't exist, show default content
        setMarkdownContent(getDefaultHelpContent());
        setLoading(false);
      });
  }, []);

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

*Last updated: ${new Date().toLocaleDateString()}*
`;
  };

  if (loading) {
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
      
      <main className="flex-grow p-4 sm:p-8 lg:p-12">
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

          {/* Markdown Content */}
          <div className="bg-brand-800 border border-brand-700 rounded-xl shadow-lg p-6 sm:p-8 lg:p-10 prose prose-invert prose-headings:text-white prose-p:text-slate-300 prose-a:text-blue-400 prose-a:no-underline hover:prose-a:text-blue-300 prose-strong:text-white prose-code:text-blue-300 prose-code:bg-brand-900 prose-code:px-1 prose-code:py-0.5 prose-code:rounded prose-pre:bg-brand-900 prose-pre:border prose-pre:border-brand-700 prose-img:rounded-lg prose-img:shadow-lg prose-img:border prose-img:border-brand-700 prose-img:max-w-full prose-img:h-auto prose-ul:list-disc prose-ol:list-decimal prose-li:my-2 prose-li:ml-4 max-w-none">
            {error ? (
              <div className="text-red-400 mb-4 p-4 bg-red-900/20 border border-red-500/30 rounded">
                <p className="font-semibold">Error loading documentation:</p>
                <p>{error}</p>
              </div>
            ) : null}
            <ReactMarkdown remarkPlugins={[remarkGfm]}>
              {markdownContent}
            </ReactMarkdown>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default HelpPage;

