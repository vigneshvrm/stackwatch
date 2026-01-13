import React, { useState, useEffect } from 'react';

interface Alert {
  id: string;
  severity: 'critical' | 'warning' | 'info' | 'resolved';
  title: string;
  description: string;
  source: string;
  timestamp: string;
  acknowledged: boolean;
}

const RecentAlerts: React.FC = () => {
  const [alerts, setAlerts] = useState<Alert[]>([
    {
      id: '1',
      severity: 'warning',
      title: 'High CPU Usage',
      description: 'prod-db-01 CPU usage exceeded 80% threshold',
      source: 'Prometheus',
      timestamp: '5 minutes ago',
      acknowledged: false,
    },
    {
      id: '2',
      severity: 'info',
      title: 'Backup Completed',
      description: 'Daily backup completed successfully for all databases',
      source: 'System',
      timestamp: '1 hour ago',
      acknowledged: true,
    },
    {
      id: '3',
      severity: 'warning',
      title: 'Memory Pressure',
      description: 'prod-db-01 memory usage at 78%',
      source: 'Prometheus',
      timestamp: '10 minutes ago',
      acknowledged: false,
    },
    {
      id: '4',
      severity: 'resolved',
      title: 'Service Restored',
      description: 'API endpoint /health is responding normally',
      source: 'Health Check',
      timestamp: '30 minutes ago',
      acknowledged: true,
    },
  ]);

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 400);
    return () => clearTimeout(timer);
  }, []);

  const getSeverityStyles = (severity: string) => {
    switch (severity) {
      case 'critical':
        return {
          bg: 'bg-red-500/10 dark:bg-red-500/20',
          border: 'border-l-red-500',
          icon: 'text-red-500',
          badge: 'bg-red-100 dark:bg-red-500/20 text-red-700 dark:text-red-400',
        };
      case 'warning':
        return {
          bg: 'bg-yellow-500/10 dark:bg-yellow-500/20',
          border: 'border-l-yellow-500',
          icon: 'text-yellow-500',
          badge: 'bg-yellow-100 dark:bg-yellow-500/20 text-yellow-700 dark:text-yellow-400',
        };
      case 'info':
        return {
          bg: 'bg-blue-500/10 dark:bg-blue-500/20',
          border: 'border-l-blue-500',
          icon: 'text-blue-500',
          badge: 'bg-blue-100 dark:bg-blue-500/20 text-blue-700 dark:text-blue-400',
        };
      case 'resolved':
        return {
          bg: 'bg-green-500/10 dark:bg-green-500/20',
          border: 'border-l-green-500',
          icon: 'text-green-500',
          badge: 'bg-green-100 dark:bg-green-500/20 text-green-700 dark:text-green-400',
        };
      default:
        return {
          bg: 'bg-slate-500/10',
          border: 'border-l-slate-500',
          icon: 'text-slate-500',
          badge: 'bg-slate-100 dark:bg-slate-500/20 text-slate-700 dark:text-slate-400',
        };
    }
  };

  const getSeverityIcon = (severity: string) => {
    switch (severity) {
      case 'critical':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
        );
      case 'warning':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
      case 'info':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
      case 'resolved':
        return (
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
      default:
        return null;
    }
  };

  const acknowledgeAlert = (id: string) => {
    setAlerts(prev => prev.map(alert =>
      alert.id === id ? { ...alert, acknowledged: true } : alert
    ));
  };

  if (loading) {
    return (
      <div className="rounded-2xl bg-white/50 dark:bg-slate-800/30 backdrop-blur-sm border border-slate-200/50 dark:border-slate-700/50 p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-slate-200 dark:bg-slate-700 rounded w-1/4"></div>
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-20 bg-slate-200/50 dark:bg-slate-700/50 rounded-xl"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  const unacknowledgedCount = alerts.filter(a => !a.acknowledged && a.severity !== 'resolved').length;

  return (
    <div className="rounded-2xl bg-white/50 dark:bg-slate-800/30 backdrop-blur-sm border border-slate-200/50 dark:border-slate-700/50 overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 border-b border-slate-200/50 dark:border-slate-700/50">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <h3 className="text-lg font-semibold text-slate-900 dark:text-white">Recent Alerts</h3>
            {unacknowledgedCount > 0 && (
              <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 dark:bg-red-500/20 text-red-700 dark:text-red-400">
                {unacknowledgedCount} new
              </span>
            )}
          </div>
          <a
            href="/prometheus/alerts"
            className="text-sm text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 font-medium flex items-center space-x-1 transition-colors"
          >
            <span>View all</span>
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </a>
        </div>
      </div>

      {/* Alerts List */}
      <div className="divide-y divide-slate-200/50 dark:divide-slate-700/50">
        {alerts.map((alert) => {
          const styles = getSeverityStyles(alert.severity);
          return (
            <div
              key={alert.id}
              className={`px-6 py-4 border-l-4 ${styles.border} ${styles.bg} transition-all duration-200 hover:bg-opacity-80`}
            >
              <div className="flex items-start justify-between">
                <div className="flex items-start space-x-3">
                  <div className={`mt-0.5 ${styles.icon}`}>
                    {getSeverityIcon(alert.severity)}
                  </div>
                  <div>
                    <div className="flex items-center space-x-2">
                      <h4 className="text-sm font-semibold text-slate-900 dark:text-white">
                        {alert.title}
                      </h4>
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${styles.badge}`}>
                        {alert.severity}
                      </span>
                    </div>
                    <p className="text-sm text-slate-600 dark:text-slate-400 mt-0.5">
                      {alert.description}
                    </p>
                    <div className="flex items-center space-x-3 mt-2 text-xs text-slate-500 dark:text-slate-500">
                      <span className="flex items-center space-x-1">
                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        <span>{alert.timestamp}</span>
                      </span>
                      <span className="flex items-center space-x-1">
                        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                        </svg>
                        <span>{alert.source}</span>
                      </span>
                    </div>
                  </div>
                </div>

                {/* Actions */}
                {!alert.acknowledged && alert.severity !== 'resolved' && (
                  <button
                    onClick={() => acknowledgeAlert(alert.id)}
                    className="px-3 py-1.5 text-xs font-medium rounded-lg bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-600 border border-slate-200 dark:border-slate-600 transition-all duration-200 shadow-sm hover:shadow"
                  >
                    Acknowledge
                  </button>
                )}
                {alert.acknowledged && (
                  <span className="text-xs text-slate-400 dark:text-slate-500 flex items-center space-x-1">
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span>Acknowledged</span>
                  </span>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {alerts.length === 0 && (
        <div className="px-6 py-12 text-center">
          <div className="w-12 h-12 rounded-full bg-green-100 dark:bg-green-500/20 flex items-center justify-center mx-auto mb-4">
            <svg className="w-6 h-6 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h4 className="text-sm font-medium text-slate-900 dark:text-white">All Clear</h4>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">No active alerts at this time</p>
        </div>
      )}
    </div>
  );
};

export default RecentAlerts;
