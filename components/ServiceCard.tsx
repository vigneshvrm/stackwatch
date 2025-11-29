import React from 'react';
import { ServiceConfig } from '../types';
import { ICONS } from '../constants';

interface ServiceCardProps {
  service: ServiceConfig;
}

const ServiceCard: React.FC<ServiceCardProps> = ({ service }) => {
  return (
    <a
      href={service.path}
      className="group relative flex flex-col items-center justify-center p-8 bg-brand-800 border border-brand-700 rounded-xl shadow-lg transition-all duration-300 hover:bg-brand-700 hover:scale-105 hover:shadow-blue-500/20 hover:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-brand-900"
      aria-label={`Navigate to ${service.name}`}
    >
      <div className="mb-4 transition-transform duration-300 group-hover:-translate-y-1">
        {ICONS[service.icon]}
      </div>
      
      <h2 className="text-xl font-bold text-white mb-2 tracking-tight">
        {service.name}
      </h2>
      
      <p className="text-sm text-slate-400 text-center max-w-[200px]">
        {service.description}
      </p>

      <div className="absolute top-4 right-4">
        <span className={`flex h-3 w-3 rounded-full ${service.status === 'active' ? 'bg-green-500' : 'bg-yellow-500'}`}>
          <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${service.status === 'active' ? 'bg-green-400' : 'bg-yellow-400'}`}></span>
        </span>
      </div>

      <div className="mt-6 flex items-center text-blue-400 text-sm font-medium opacity-0 transform translate-y-2 transition-all duration-300 group-hover:opacity-100 group-hover:translate-y-0">
        Access Portal &rarr;
      </div>
    </a>
  );
};

export default ServiceCard;