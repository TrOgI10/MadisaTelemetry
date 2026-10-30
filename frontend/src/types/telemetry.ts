// frontend/src/types/telemetry.ts

export type HealthStatus = 'green' | 'amber' | 'red';

export type Delegation = 'PALMA' | 'MADRID' | 'BARCELONA' | 'IBIZA';

export interface SystemMetrics {
  cpu_usage_percent: number;
  ram_used_gb: number;
  ram_total_gb: number;
  ram_usage_percent?: number;
  disk_c_total_gb?: number;
  disk_c_free_gb?: number;
  disk_c_used_gb?: number;
  disk_c_percent_free: number;
  sql_service_status: string;
  print_spooler_jobs?: number;
  uptime_formatted?: string;
  uptime_hours?: number;
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
  delegation: Delegation;
  zone: number;
  terminal_id: string;
  timestamp: string;
  system: SystemMetrics;
  database?: DatabaseMetrics;
  status: HealthStatus;
}