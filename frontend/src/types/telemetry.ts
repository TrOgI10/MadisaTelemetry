export type HealthStatus = 'green' | 'amber' | 'red';

export interface SystemMetrics {
  cpu_usage_percent: number;
  ram_used_gb: number;
  ram_total_gb: number;
  ram_usage_percent: number;
  disk_c_total_gb: number;
  disk_c_free_gb: number;
  disk_c_used_gb: number;
  disk_c_percent_free: number;
  uptime_hours: number;
  uptime_days: number;
  uptime_formatted: string;
  last_boot_datetime: string;
  sql_service_status: string;
}

export interface TerminalTelemetry {
  client_id: string;
  client_name: string;
  delegation: 'PALMA' | 'MADRID' | 'BARCELONA' | 'IBIZA';
  zone: number;
  terminal_id: string;
  timestamp: string;
  system: SystemMetrics;
  status: HealthStatus;
}