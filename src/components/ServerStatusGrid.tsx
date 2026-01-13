import React, { useState, useEffect } from 'react';

interface Server {
  id: string;
  name: string;
  ip: string;
  status: 'online' | 'warning' | 'offline' | 'maintenance';
  type: 'linux' | 'windows' | 'container';
  cpu?: number;
  memory?: number;
  lastSeen: string;
}

const ServerStatusGrid: React.FC = () => {
  const [servers, setServers] = useState<Server[]>([
    { id: '1', name: 'prod-web-01', ip: '192.168.1.10', status: 'online', type: 'linux', cpu: 45, memory: 62, lastSeen: '2s ago' },
    { id: '2', name: 'prod-web-02', ip: '192.168.1.11', status: 'online', type: 'linux', cpu: 38, memory: 55, lastSeen: '5s ago' },
    { id: '3', name: 'prod-db-01', ip: '192.168.1.20', status: 'warning', type: 'linux', cpu: 82, memory: 78, lastSeen: '3s ago' },
    { id: '4', name: 'prod-api-01', ip: '192.168.1.30', status: 'online', type: 'container', cpu: 25, memory: 40, lastSeen: '1s ago' },
    { id: '5', name: 'staging-web', ip: '192.168.2.10', status: 'online', type: 'linux', cpu: 15, memory: 30, lastSeen: '10s ago' },
    { id: '6', name: 'win-server-01', ip: '192.168.1.50', status: 'maintenance', type: 'windows', lastSeen: '5m ago' },
  ]);

  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'online' | 'warning' | 'offline'>('all');

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 600);
    return () => clearTimeout(timer);
  }, []);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'online':
        return 'bg-green-500';
      case 'warning':
        return 'bg-yellow-500';
      case 'offline':
        return 'bg-red-500';
      case 'maintenance':
        return 'bg-blue-500';
      default:
        return 'bg-slate-500';
    }
  };

  const getStatusBg = (status: string) => {
    switch (status) {
      case 'online':
        return 'bg-green-500/10 border-green-500/20 dark:bg-green-500/10';
      case 'warning':
        return 'bg-yellow-500/10 border-yellow-500/20 dark:bg-yellow-500/10';
      case 'offline':
        return 'bg-red-500/10 border-red-500/20 dark:bg-red-500/10';
      case 'maintenance':
        return 'bg-blue-500/10 border-blue-500/20 dark:bg-blue-500/10';
      default:
        return 'bg-slate-500/10 border-slate-500/20';
    }
  };

  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'linux':
        return (
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12.504 0c-.155 0-.315.008-.48.021-4.226.333-3.105 4.807-3.17 6.298-.076 1.092-.3 1.953-1.05 3.02-.885 1.051-2.127 2.75-2.716 4.521-.278.832-.41 1.684-.287 2.489a.424.424 0 00-.11.135c-.26.268-.45.6-.663.839-.199.199-.485.267-.797.4-.313.136-.658.269-.864.68-.09.189-.136.394-.132.602 0 .199.027.4.055.536.058.399.116.728.04.97-.249.68-.28 1.145-.106 1.484.174.334.535.47.94.601.81.2 1.91.135 2.774.6.926.466 1.866.67 2.616.47.526-.116.97-.464 1.208-.946.587-.003 1.23-.269 2.26-.334.699-.058 1.574.267 2.577.2.025.134.063.198.114.333l.003.003c.391.778 1.113 1.132 1.884 1.071.771-.06 1.592-.536 2.257-1.306.631-.765 1.683-1.084 2.378-1.503.348-.199.629-.469.649-.853.023-.4-.2-.811-.714-1.376v-.097l-.003-.003c-.17-.2-.25-.535-.338-.926-.085-.401-.182-.786-.492-1.046h-.003c-.059-.054-.123-.067-.188-.135a.357.357 0 00-.19-.064c.431-1.278.264-2.55-.173-3.694-.533-1.41-1.465-2.638-2.175-3.483-.796-1.005-1.576-1.957-1.56-3.368.026-2.152.236-6.133-3.544-6.139zm.529 3.405h.013c.213 0 .396.062.584.198.19.135.33.332.438.533.105.259.158.459.166.724 0-.02.006-.04.006-.06v.105a.086.086 0 01-.004-.021l-.004-.024a1.807 1.807 0 01-.15.706.953.953 0 01-.213.335.71.71 0 00-.088-.042c-.104-.045-.198-.064-.284-.133a1.312 1.312 0 00-.22-.066c.05-.06.146-.133.183-.198.053-.128.082-.264.088-.402v-.02a1.21 1.21 0 00-.061-.4c-.045-.134-.101-.2-.183-.333-.084-.066-.167-.132-.267-.132h-.016c-.093 0-.176.03-.262.132a.8.8 0 00-.205.334 1.18 1.18 0 00-.09.468v.018c0 .133.034.267.072.4a.959.959 0 00.163.332c-.067.014-.134.03-.2.064-.07.03-.138.073-.2.108a.858.858 0 01-.133-.095c-.08-.082-.134-.166-.186-.266a1.413 1.413 0 01-.108-.467 2.004 2.004 0 010-.66c.025-.2.061-.4.132-.531a.986.986 0 01.387-.4c.168-.092.37-.133.576-.133z"/>
          </svg>
        );
      case 'windows':
        return (
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
            <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.9-1.801"/>
          </svg>
        );
      case 'container':
        return (
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
          </svg>
        );
      default:
        return null;
    }
  };

  const filteredServers = servers.filter(server => {
    if (filter === 'all') return true;
    return server.status === filter;
  });

  const statusCounts = {
    all: servers.length,
    online: servers.filter(s => s.status === 'online').length,
    warning: servers.filter(s => s.status === 'warning').length,
    offline: servers.filter(s => s.status === 'offline').length,
  };

  if (loading) {
    return (
      <div className="rounded-2xl bg-white/50 dark:bg-slate-800/30 backdrop-blur-sm border border-slate-200/50 dark:border-slate-700/50 p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-slate-200 dark:bg-slate-700 rounded w-1/4"></div>
          <div className="grid grid-cols-2 lg:grid-cols-3 gap-3">
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <div key={i} className="h-24 bg-slate-200/50 dark:bg-slate-700/50 rounded-xl"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-2xl bg-white/50 dark:bg-slate-800/30 backdrop-blur-sm border border-slate-200/50 dark:border-slate-700/50 overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 border-b border-slate-200/50 dark:border-slate-700/50">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h3 className="text-lg font-semibold text-slate-900 dark:text-white">Server Status</h3>
            <p className="text-sm text-slate-500 dark:text-slate-400">Real-time monitoring of your infrastructure</p>
          </div>

          {/* Filter Tabs */}
          <div className="flex items-center space-x-1 bg-slate-100 dark:bg-slate-800 rounded-xl p-1">
            {(['all', 'online', 'warning', 'offline'] as const).map((status) => (
              <button
                key={status}
                onClick={() => setFilter(status)}
                className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 ${
                  filter === status
                    ? 'bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-sm'
                    : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
                }`}
              >
                {status.charAt(0).toUpperCase() + status.slice(1)}
                <span className="ml-1.5 text-xs opacity-60">({statusCounts[status]})</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Grid */}
      <div className="p-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {filteredServers.map((server) => (
            <div
              key={server.id}
              className={`relative rounded-xl border p-4 transition-all duration-200 hover:scale-[1.02] cursor-pointer ${getStatusBg(server.status)}`}
            >
              {/* Status Indicator */}
              <div className="absolute top-3 right-3">
                <span className={`flex h-2.5 w-2.5 rounded-full ${getStatusColor(server.status)}`}>
                  {server.status === 'online' && (
                    <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${getStatusColor(server.status)}`}></span>
                  )}
                </span>
              </div>

              {/* Server Info */}
              <div className="flex items-start space-x-3">
                <div className="p-2 rounded-lg bg-white/50 dark:bg-slate-800/50 text-slate-600 dark:text-slate-300">
                  {getTypeIcon(server.type)}
                </div>
                <div className="flex-1 min-w-0">
                  <h4 className="text-sm font-semibold text-slate-900 dark:text-white truncate">
                    {server.name}
                  </h4>
                  <p className="text-xs text-slate-500 dark:text-slate-400 font-mono">
                    {server.ip}
                  </p>
                </div>
              </div>

              {/* Metrics */}
              {(server.cpu !== undefined || server.memory !== undefined) && (
                <div className="mt-3 pt-3 border-t border-slate-200/30 dark:border-slate-700/30">
                  <div className="flex items-center space-x-4 text-xs">
                    {server.cpu !== undefined && (
                      <div className="flex items-center space-x-1.5">
                        <span className="text-slate-500 dark:text-slate-400">CPU</span>
                        <div className="w-16 h-1.5 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden">
                          <div
                            className={`h-full rounded-full transition-all duration-500 ${
                              server.cpu > 80 ? 'bg-red-500' : server.cpu > 60 ? 'bg-yellow-500' : 'bg-green-500'
                            }`}
                            style={{ width: `${server.cpu}%` }}
                          />
                        </div>
                        <span className="text-slate-600 dark:text-slate-300 font-medium">{server.cpu}%</span>
                      </div>
                    )}
                    {server.memory !== undefined && (
                      <div className="flex items-center space-x-1.5">
                        <span className="text-slate-500 dark:text-slate-400">MEM</span>
                        <div className="w-16 h-1.5 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden">
                          <div
                            className={`h-full rounded-full transition-all duration-500 ${
                              server.memory > 80 ? 'bg-red-500' : server.memory > 60 ? 'bg-yellow-500' : 'bg-green-500'
                            }`}
                            style={{ width: `${server.memory}%` }}
                          />
                        </div>
                        <span className="text-slate-600 dark:text-slate-300 font-medium">{server.memory}%</span>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* Last Seen */}
              <div className="mt-2 text-xs text-slate-400 dark:text-slate-500">
                Last seen: {server.lastSeen}
              </div>
            </div>
          ))}
        </div>

        {filteredServers.length === 0 && (
          <div className="text-center py-8 text-slate-500 dark:text-slate-400">
            No servers match the selected filter
          </div>
        )}
      </div>
    </div>
  );
};

export default ServerStatusGrid;
