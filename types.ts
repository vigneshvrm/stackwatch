export interface ServiceConfig {
  id: string;
  name: string;
  description: string;
  path: string; // The relative path for Nginx routing
  icon: 'prometheus' | 'grafana' | 'help';
  status: 'active' | 'maintenance' | 'deprecated';
}

export interface ArchitectureMeta {
  version: string;
  buildDate: string;
  environment: string;
}