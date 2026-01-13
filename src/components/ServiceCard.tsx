import React from 'react';
import { Link } from 'react-router-dom';
import { ServiceConfig } from '../types';
import { ICONS } from '../constants';

interface ServiceCardProps {
  service: ServiceConfig;
}

const ServiceCard: React.FC<ServiceCardProps> = ({ service }) => {
  const isInternalRoute = service.path === '/help';

  const getServiceColor = (id: string) => {
    switch (id) {
      case 'svc-prom':
        return {
          bg: 'from-orange-500/10 to-red-500/10 dark:from-orange-500/20 dark:to-red-500/20',
          border: 'border-orange-500/20 hover:border-orange-500/40',
          icon: 'text-orange-500',
          glow: 'group-hover:shadow-orange-500/20',
        };
      case 'svc-graf':
        return {
          bg: 'from-amber-500/10 to-orange-500/10 dark:from-amber-500/20 dark:to-orange-500/20',
          border: 'border-amber-500/20 hover:border-amber-500/40',
          icon: 'text-amber-500',
          glow: 'group-hover:shadow-amber-500/20',
        };
      case 'svc-help':
        return {
          bg: 'from-blue-500/10 to-indigo-500/10 dark:from-blue-500/20 dark:to-indigo-500/20',
          border: 'border-blue-500/20 hover:border-blue-500/40',
          icon: 'text-blue-500',
          glow: 'group-hover:shadow-blue-500/20',
        };
      default:
        return {
          bg: 'from-slate-500/10 to-slate-600/10',
          border: 'border-slate-500/20 hover:border-slate-500/40',
          icon: 'text-slate-500',
          glow: 'group-hover:shadow-slate-500/20',
        };
    }
  };

  const colors = getServiceColor(service.id);

  const cardContent = (
    <div className={`group relative overflow-hidden rounded-2xl bg-gradient-to-br ${colors.bg} border ${colors.border} backdrop-blur-sm p-6 transition-all duration-300 hover:scale-[1.02] ${colors.glow} hover:shadow-xl`}>
      {/* Background decoration */}
      <div className="absolute -right-8 -top-8 w-32 h-32 bg-gradient-to-br from-white/10 to-transparent rounded-full blur-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-500" />

      {/* Status indicator */}
      <div className="absolute top-4 right-4">
        <span className={`flex h-2.5 w-2.5 rounded-full ${service.status === 'active' ? 'bg-green-500' : 'bg-yellow-500'}`}>
          <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${service.status === 'active' ? 'bg-green-400' : 'bg-yellow-400'}`}></span>
        </span>
      </div>

      <div className="relative">
        {/* Icon */}
        <div className={`mb-4 p-3 rounded-xl bg-white/50 dark:bg-slate-800/50 w-fit ${colors.icon} transition-transform duration-300 group-hover:scale-110 group-hover:-rotate-3`}>
          {ICONS[service.icon]}
        </div>

        {/* Title */}
        <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-1 tracking-tight">
          {service.name}
        </h3>

        {/* Description */}
        <p className="text-sm text-slate-600 dark:text-slate-400 mb-4">
          {service.description}
        </p>

        {/* Action */}
        <div className="flex items-center text-sm font-medium text-blue-600 dark:text-blue-400 opacity-0 transform translate-y-2 transition-all duration-300 group-hover:opacity-100 group-hover:translate-y-0">
          <span>
            {service.id === 'svc-help' && 'View Documentation'}
            {service.id === 'svc-prom' && 'Access Prometheus'}
            {service.id === 'svc-graf' && 'Access Grafana'}
          </span>
          <svg className="w-4 h-4 ml-1 transition-transform duration-300 group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </div>
      </div>
    </div>
  );

  if (isInternalRoute) {
    return (
      <Link
        to={service.path}
        aria-label={`Navigate to ${service.name}`}
      >
        {cardContent}
      </Link>
    );
  }

  return (
    <a
      href={service.path}
      aria-label={`Navigate to ${service.name}`}
    >
      {cardContent}
    </a>
  );
};

export default ServiceCard;
