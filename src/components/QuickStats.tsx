import React, { useState, useEffect } from 'react';

interface StatCard {
  id: string;
  label: string;
  value: string;
  subValue?: string;
  icon: React.ReactNode;
  trend?: 'up' | 'down' | 'stable';
  trendValue?: string;
  color: 'blue' | 'green' | 'purple' | 'orange';
}

const QuickStats: React.FC = () => {
  const [stats, setStats] = useState<StatCard[]>([
    {
      id: 'uptime',
      label: 'System Uptime',
      value: '99.9%',
      subValue: 'Last 30 days',
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      ),
      trend: 'up',
      trendValue: '+0.1%',
      color: 'green',
    },
    {
      id: 'servers',
      label: 'Active Servers',
      value: '12',
      subValue: 'All operational',
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
        </svg>
      ),
      trend: 'stable',
      color: 'blue',
    },
    {
      id: 'alerts',
      label: 'Active Alerts',
      value: '3',
      subValue: '2 warnings, 1 info',
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
        </svg>
      ),
      trend: 'down',
      trendValue: '-2',
      color: 'orange',
    },
    {
      id: 'metrics',
      label: 'Metrics/sec',
      value: '2.4K',
      subValue: 'Ingestion rate',
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
        </svg>
      ),
      trend: 'up',
      trendValue: '+15%',
      color: 'purple',
    },
  ]);

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Simulate loading delay
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  // Fetch real stats from Prometheus API (if available)
  useEffect(() => {
    const fetchStats = async () => {
      try {
        const response = await fetch('/api/health');
        if (response.ok) {
          const data = await response.json();
          // Update stats based on health data
          setStats(prev => prev.map(stat => {
            if (stat.id === 'servers' && data.healthy !== undefined) {
              return { ...stat, value: String(data.healthy + data.unhealthy), subValue: `${data.healthy} healthy` };
            }
            if (stat.id === 'alerts' && data.warnings !== undefined) {
              return { ...stat, value: String(data.warnings), subValue: data.warnings > 0 ? 'Requires attention' : 'All clear' };
            }
            return stat;
          }));
        }
      } catch (error) {
        console.warn('Could not fetch health stats:', error);
      }
    };

    fetchStats();
    const interval = setInterval(fetchStats, 30000);
    return () => clearInterval(interval);
  }, []);

  const getColorClasses = (color: string) => {
    const colors: Record<string, { bg: string; icon: string; border: string }> = {
      blue: {
        bg: 'from-blue-500/10 to-blue-600/10 dark:from-blue-500/20 dark:to-blue-600/20',
        icon: 'text-blue-500',
        border: 'border-blue-500/20',
      },
      green: {
        bg: 'from-green-500/10 to-emerald-600/10 dark:from-green-500/20 dark:to-emerald-600/20',
        icon: 'text-green-500',
        border: 'border-green-500/20',
      },
      purple: {
        bg: 'from-purple-500/10 to-indigo-600/10 dark:from-purple-500/20 dark:to-indigo-600/20',
        icon: 'text-purple-500',
        border: 'border-purple-500/20',
      },
      orange: {
        bg: 'from-orange-500/10 to-amber-600/10 dark:from-orange-500/20 dark:to-amber-600/20',
        icon: 'text-orange-500',
        border: 'border-orange-500/20',
      },
    };
    return colors[color] || colors.blue;
  };

  const getTrendIcon = (trend?: string) => {
    if (trend === 'up') {
      return (
        <svg className="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 10l7-7m0 0l7 7m-7-7v18" />
        </svg>
      );
    }
    if (trend === 'down') {
      return (
        <svg className="w-4 h-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 14l-7 7m0 0l-7-7m7 7V3" />
        </svg>
      );
    }
    return (
      <svg className="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 12h14" />
      </svg>
    );
  };

  if (loading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="animate-pulse rounded-2xl bg-slate-200/50 dark:bg-slate-800/50 h-32" />
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {stats.map((stat) => {
        const colors = getColorClasses(stat.color);
        return (
          <div
            key={stat.id}
            className={`relative overflow-hidden rounded-2xl bg-gradient-to-br ${colors.bg} border ${colors.border} backdrop-blur-sm p-5 transition-all duration-300 hover:scale-[1.02] hover:shadow-lg group`}
          >
            {/* Background decoration */}
            <div className="absolute -right-4 -top-4 w-24 h-24 bg-gradient-to-br from-white/5 to-transparent rounded-full blur-2xl" />

            <div className="relative">
              {/* Header */}
              <div className="flex items-start justify-between mb-3">
                <div className={`p-2 rounded-xl bg-white/50 dark:bg-slate-800/50 ${colors.icon}`}>
                  {stat.icon}
                </div>
                {stat.trend && (
                  <div className="flex items-center space-x-1 text-xs">
                    {getTrendIcon(stat.trend)}
                    {stat.trendValue && (
                      <span className={`font-medium ${
                        stat.trend === 'up' ? 'text-green-600 dark:text-green-400' :
                        stat.trend === 'down' ? 'text-red-600 dark:text-red-400' :
                        'text-slate-500'
                      }`}>
                        {stat.trendValue}
                      </span>
                    )}
                  </div>
                )}
              </div>

              {/* Value */}
              <div className="mb-1">
                <span className="text-3xl font-bold text-slate-900 dark:text-white">
                  {stat.value}
                </span>
              </div>

              {/* Label */}
              <p className="text-sm font-medium text-slate-600 dark:text-slate-300">
                {stat.label}
              </p>
              {stat.subValue && (
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                  {stat.subValue}
                </p>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
};

export default QuickStats;
