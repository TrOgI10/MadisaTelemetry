// frontend/src/types/telemetry.ts

export type HealthStatus = 'green' | 'amber' | 'red';

export type Delegation = 'PALMA' | 'MADRID' | 'BARCELONA' | 'IBIZA';

export interface ProcessMetric {
  name: string;
  ram_mb?: number;
  cpu_seconds?: number;
}

export interface SystemMetrics {
  ip_private?: string;
  ip_public?: string;
  cpu_usage_percent: number;
  ram_used_gb: number;
  ram_total_gb: number;
  ram_usage_percent: number;
  disk_c_total_gb: number;
  disk_c_free_gb: number;
  disk_c_used_gb: number;
  disk_c_percent_free: number;
  sql_service_status: string;
  print_spooler_jobs: number;
  uptime_hours: number;
  uptime_human: string;
  uptime_formatted: string;
  top_ram_processes?: ProcessMetric[];
  top_cpu_processes?: ProcessMetric[];
}

export interface DatabaseMetrics {
  connected?: boolean;
  last_trans_datetime?: string;
  blocked_processes?: number;
}

export interface TerminalTelemetry {
  id?: string;
  client_id: string;
  client_name: string;
  delegation: string;
  zone?: string | number;
  terminal_id: string;
  timestamp?: string | number | any;
  last_seen?: string | number | any;
  server_timestamp?: string | number | any;
  received_at?: string | number | any;
  system: any;
  database?: any;
  status?: HealthStatus;
  isOffline?: boolean;
  hasClockSkew?: boolean;
}