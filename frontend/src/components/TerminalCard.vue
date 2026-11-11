<script setup lang="ts">
import { computed } from 'vue';
import type { TerminalTelemetry } from '../types/telemetry';

const props = defineProps<{
  terminal: TerminalTelemetry;
}>();

const emit = defineEmits<{
  (e: 'select', terminal: TerminalTelemetry): void;
}>();

const statusCardClasses = computed(() => {
  if (props.terminal.isOffline) {
    return 'border-rose-300 dark:border-rose-900 bg-rose-50/50 dark:bg-rose-950/20 hover:border-rose-400';
  }
  switch (props.terminal.status) {
    case 'green': 
      return 'border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 hover:border-[#1976d2]';
    case 'amber': 
      return 'border-amber-300 dark:border-amber-900 bg-amber-50/40 dark:bg-amber-950/20 hover:border-amber-400';
    case 'red': 
      return 'border-rose-300 dark:border-rose-900 bg-rose-50/40 dark:bg-rose-950/20 hover:border-rose-400';
    default: 
      return 'border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900';
  }
});
</script>

<template>
  <div 
    @click="emit('select', props.terminal)"
    :class="[
      'rounded-xl border p-4 shadow-sm hover:shadow-md transition-all cursor-pointer active:scale-[0.99] select-none flex flex-col justify-between',
      statusCardClasses
    ]"
  >
    <div>
      <!-- Header de la tarjeta -->
      <div class="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-800">
        <div>
          <div class="flex items-center gap-2">
            <h3 class="font-bold text-slate-900 dark:text-white text-base leading-tight truncate">
              {{ terminal.client_name }}
            </h3>
            <span 
              v-if="terminal.isOffline" 
              class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-rose-100 dark:bg-rose-900/60 text-rose-700 dark:text-rose-300 border border-rose-300 dark:border-rose-700 uppercase animate-pulse"
            >
              Offline
            </span>
          </div>
          <span class="text-xs text-slate-500 dark:text-slate-400">{{ terminal.client_id }} • {{ terminal.delegation }}</span>
        </div>
        <span class="text-xs font-mono font-bold px-2 py-1 rounded bg-slate-100 dark:bg-slate-800 text-[#1976d2] dark:text-blue-400 border border-slate-200 dark:border-slate-700">
          {{ terminal.terminal_id }}
        </span>
      </div>

      <!-- Métricas -->
      <div class="mt-3 grid grid-cols-2 gap-2 text-xs">
        <div class="bg-slate-50 dark:bg-slate-800/60 p-2.5 rounded-lg border border-slate-100 dark:border-slate-800">
          <span class="text-[10px] text-slate-400 uppercase font-medium block">CPU</span>
          <span class="font-mono text-sm font-semibold text-slate-800 dark:text-white">
            {{ terminal.system.cpu_usage_percent }}%
          </span>
        </div>

        <div class="bg-slate-50 dark:bg-slate-800/60 p-2.5 rounded-lg border border-slate-100 dark:border-slate-800">
          <span class="text-[10px] text-slate-400 uppercase font-medium block">RAM</span>
          <span class="font-mono text-sm font-semibold text-slate-800 dark:text-white">
            {{ terminal.system.ram_usage_percent ?? Math.round((terminal.system.ram_used_gb / terminal.system.ram_total_gb) * 100) }}%
          </span>
          <span class="text-[10px] text-slate-400 block truncate">
            {{ terminal.system.ram_used_gb }}/{{ terminal.system.ram_total_gb }} GB
          </span>
        </div>

        <div class="bg-slate-50 dark:bg-slate-800/60 p-2.5 rounded-lg border border-slate-100 dark:border-slate-800">
          <span class="text-[10px] text-slate-400 uppercase font-medium block">Disco C: Libre</span>
          <span class="font-mono text-sm font-semibold text-slate-800 dark:text-white">
            {{ terminal.system.disk_c_percent_free }}%
          </span>
          <span class="text-[10px] text-slate-400 block truncate">
            {{ terminal.system.disk_c_free_gb !== undefined ? `${terminal.system.disk_c_free_gb} GB` : 'N/A' }}
          </span>
        </div>

        <div class="bg-slate-50 dark:bg-slate-800/60 p-2.5 rounded-lg border border-slate-100 dark:border-slate-800">
          <span class="text-[10px] text-slate-400 uppercase font-medium block">SQL Server</span>
          <span :class="['font-mono text-sm font-semibold', terminal.system.sql_service_status === 'Running' ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400']">
            {{ terminal.system.sql_service_status }}
          </span>
        </div>
      </div>

      <!-- Fila de Direcciones IP (LAN y WAN) -->
      <div class="mt-2.5 grid grid-cols-2 gap-2 font-mono text-[11px] pt-2 border-t border-slate-100 dark:border-slate-800">
        <div class="bg-slate-50 dark:bg-slate-800/40 p-1.5 rounded border border-slate-100 dark:border-slate-800">
          <span class="text-[9px] uppercase tracking-wider text-slate-400 block font-sans font-medium">LAN (Privada)</span>
          <span class="text-slate-700 dark:text-slate-300 font-semibold truncate block">
            {{ terminal.system.ip_private || '---' }}
          </span>
        </div>
        <div class="bg-slate-50 dark:bg-slate-800/40 p-1.5 rounded border border-slate-100 dark:border-slate-800 text-right">
          <span class="text-[9px] uppercase tracking-wider text-slate-400 block font-sans font-medium">WAN (Pública)</span>
          <span class="text-[#1976d2] dark:text-blue-400 font-semibold truncate block">
            {{ terminal.system.ip_public || '---' }}
          </span>
        </div>
      </div>
    </div>

    <!-- Pie de la tarjeta -->
    <div class="mt-3 pt-2.5 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-[11px] text-slate-500 dark:text-slate-400">
      <div class="flex items-center gap-1.5">
        <span 
          class="inline-block w-2 h-2 rounded-full" 
          :class="terminal.isOffline ? 'bg-rose-500' : 'bg-emerald-500'"
        ></span>
        <span>Activo:</span>
        <strong class="font-mono text-slate-700 dark:text-slate-200">
          {{ terminal.system.uptime_human || terminal.system.uptime_formatted || 'Desconocido' }}
        </strong>
      </div>

      <span class="text-slate-400">
        {{ terminal.timestamp ? new Date(terminal.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'N/A' }}
      </span>
    </div>
  </div>
</template>