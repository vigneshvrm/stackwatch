import React, { useState, useEffect } from 'react';
import ThemeToggle from './ThemeToggle';

interface HealthStatus {
  status: 'nominal' | 'degraded' | 'critical' | 'error';
  healthy: number;
  unhealthy: number;
  warnings: number;
  timestamp: string;
}

const Header: React.FC = () => {
  const [healthStatus, setHealthStatus] = useState<HealthStatus>({
    status: 'nominal',
    healthy: 0,
    unhealthy: 0,
    warnings: 0,
    timestamp: new Date().toISOString()
  });
  const [previousStatus, setPreviousStatus] = useState<string>('nominal');
  const [showNotification, setShowNotification] = useState(false);

  const fetchHealthStatus = async () => {
    try {
      // Try /api/health first (if health-api.sh is running)
      // Fallback to direct health check endpoint if available
      const response = await fetch('/api/health', {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
        cache: 'no-cache',
      });

      if (response.ok) {
        const data: HealthStatus = await response.json();
        setHealthStatus(data);
        
        // Show notification if status changed to degraded or critical
        if (previousStatus !== data.status && (data.status === 'degraded' || data.status === 'critical')) {
          setShowNotification(true);
          setTimeout(() => setShowNotification(false), 5000);
        }
        setPreviousStatus(data.status);
      }
    } catch (error) {
      // If health API is not available, set to degraded
      console.warn('Health API not available:', error);
      setHealthStatus({
        status: 'degraded',
        healthy: 0,
        unhealthy: 0,
        warnings: 1,
        timestamp: new Date().toISOString()
      });
    }
  };

  useEffect(() => {
    // Initial fetch
    fetchHealthStatus();
    
    // Poll every 60 seconds
    const interval = setInterval(() => {
      fetchHealthStatus();
    }, 60000);

    return () => clearInterval(interval);
  }, [previousStatus]);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'nominal':
        return 'text-green-600 dark:text-green-400';
      case 'degraded':
        return 'text-yellow-600 dark:text-yellow-400';
      case 'critical':
        return 'text-red-600 dark:text-red-400';
      default:
        return 'text-slate-600 dark:text-slate-400';
    }
  };

  const getStatusBgColor = (status: string) => {
    switch (status) {
      case 'nominal':
        return 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-500/30';
      case 'degraded':
        return 'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-500/30';
      case 'critical':
        return 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-500/30';
      default:
        return 'bg-slate-100 dark:bg-brand-800 border-slate-200 dark:border-brand-700';
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'nominal':
        return 'Nominal';
      case 'degraded':
        return 'Degraded';
      case 'critical':
        return 'Critical';
      default:
        return 'Unknown';
    }
  };

  return (
    <>
      {/* Notification Banner */}
      {showNotification && (healthStatus.status === 'degraded' || healthStatus.status === 'critical') && (
        <div className={`w-full py-2 px-4 text-center text-sm font-medium ${getStatusBgColor(healthStatus.status)} ${getStatusColor(healthStatus.status)} border-b transition-all duration-300`}>
          System Status Changed: {getStatusLabel(healthStatus.status)} - {healthStatus.unhealthy > 0 ? `${healthStatus.unhealthy} service(s) unhealthy` : `${healthStatus.warnings} warning(s)`}
        </div>
      )}
      
      <header className="w-full py-8 px-4 sm:px-6 lg:px-8 border-b border-slate-200 dark:border-brand-700/50 bg-white/80 dark:bg-brand-900/50 backdrop-blur-sm sticky top-0 z-10 transition-colors duration-200">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 bg-gradient-to-br from-blue-600 to-indigo-600 rounded-lg flex items-center justify-center shadow-lg">
              <span className="text-white font-bold text-xl">S</span>
            </div>
            <div>
              <h1 className="text-2xl font-bold text-slate-900 dark:text-white tracking-tight transition-colors duration-200">StackWatch</h1>
              <p className="text-xs text-slate-600 dark:text-slate-400 uppercase tracking-wider font-semibold transition-colors duration-200">Infrastructure Gateway</p>
            </div>
          </div>
          <div className="flex items-center space-x-3">
            <div className="hidden sm:block">
              <span className={`px-3 py-1 rounded-full text-xs border transition-colors duration-200 ${getStatusBgColor(healthStatus.status)} ${getStatusColor(healthStatus.status)}`}>
                System Status: <span className={`font-bold ${getStatusColor(healthStatus.status)}`}>{getStatusLabel(healthStatus.status)}</span>
                {healthStatus.unhealthy > 0 && (
                  <span className="ml-1">({healthStatus.unhealthy} down)</span>
                )}
              </span>
            </div>
            <ThemeToggle />
          </div>
        </div>
      </header>
    </>
  );
};

export default Header;