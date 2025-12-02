import { ServiceConfig, ArchitectureMeta } from './types';

export const APP_METADATA: ArchitectureMeta = {
  version: '1.0.0',
  buildDate: new Date().toISOString().split('T')[0],
  environment: 'production',
};

// Extensibility: Add new services here without modifying UI components
export const SERVICES: ServiceConfig[] = [
  {
    id: 'svc-prom',
    name: 'Prometheus',
    description: 'Time-series event monitoring and alerting.',
    path: '/prometheus',
    icon: 'prometheus',
    status: 'active',
  },
  {
    id: 'svc-graf',
    name: 'Grafana',
    description: 'Operational dashboards and data visualization.',
    path: '/grafana',
    icon: 'grafana',
    status: 'active',
  },
  {
    id: 'svc-help',
    name: 'Help & Documentation',
    description: 'User guides, tutorials, and documentation.',
    path: '/help',
    icon: 'help',
    status: 'active',
  },
];

// SVG Icons defined as constants for performance and zero-dependency
export const ICONS = {
  prometheus: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-12 h-12 text-orange-500">
      <path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Zm0 18a8 8 0 1 1 8-8 8 8 0 0 1-8 8Z" />
      <path d="M12 12v6" />
      <path d="M12 12h-4" />
      <circle cx="12" cy="12" r="2" className="fill-current" />
    </svg>
  ),
  grafana: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-12 h-12 text-orange-400">
      <path d="M3 3v18h18" />
      <path d="M18.7 8l-5.1 5.2-2.8-2.7L7 14.3" />
      <circle cx="7" cy="14.3" r="2" />
      <circle cx="10.8" cy="10.5" r="2" />
      <circle cx="13.6" cy="13.2" r="2" />
      <circle cx="18.7" cy="8" r="2" />
    </svg>
  ),
  help: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-12 h-12 text-blue-400">
      <circle cx="12" cy="12" r="10" />
      <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
      <path d="M12 17h.01" />
    </svg>
  )
};