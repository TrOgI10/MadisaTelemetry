<script setup lang="ts">
import { computed } from 'vue';
import type { TerminalTelemetry } from '../types/telemetry';

const props = defineProps<{
  terminal: TerminalTelemetry;
}>();

const emit = defineEmits<{
  (e: 'select', terminal: TerminalTelemetry): void;
}>();

const statusColor = computed(() => {
  if (props.terminal.isOffline) {
    return 'border-rose-600 bg-rose-950/25 text-rose-400 hover:border-rose-500';
  }
  switch (props.terminal.status) {
    case 'green': return 'border-emerald-500/70 bg-emerald-950/20 text-emerald-400 hover:border-emerald-400';
    case 'amber': return 'border-amber-500/70 bg-amber-950/20 text-amber-400 hover:border-amber-400';
    case 'red': return 'border-rose-500/70 bg-rose-950/20 text-rose-400 hover:border-rose-400';
    default: return 'border-zinc-800 bg-zinc-900 text-zinc-400 hover:border-zinc-700';
  }
});
</script>

<template>
  <div 
    @click="emit('select', props.terminal)"
    :class="[
      'rounded-xl border p-4 shadow-lg transition-all cursor-pointer active:scale-[0.99] select-none hover:shadow-cyan-950/10',
      statusColor
    ]"
  >
    <div class="flex items-center justify-between pb-2 border-b border-zinc-800">
      <div>
        <div class="flex items-center gap-2">
          <h3 class="font-bold text-white text-lg leading-tight">{{ terminal.client_name }}</h3>
          <span 
            v-if="terminal.isOffline" 
            class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-rose-900/60 text-rose-300 border border-rose-700 uppercase animate-pulse"
          >
            Offline
          </span>
        </div>
        <span class="text-xs text-zinc-400">{{ terminal.client_id }} • {{ terminal.delegation }}</span>
      </div>
      <span class="text-xs font-semibold px-2 py-1 rounded bg-zinc-800 text-zinc-200">
        {{ terminal.terminal_id }}
      </span>
    </div>

    <div class="mt-4 grid grid-cols-2 gap-3 text-sm">
      <div class="bg-zinc-900/80 p-2.5 rounded-lg border border-zinc-800">
        <span class="text-xs text-zinc-400 block">CPU</span>
        <span class="font-mono text-base font-semibold text-white">{{ terminal.system.cpu_usage_percent }}%</span>
      </div>

      <!-- RAM -->
      <div class="bg-zinc-900/60 p-3 rounded-lg border border-zinc-800">
        <span class="text-[11px] font-medium text-zinc-400 block mb-1">RAM</span>
        <span class="font-mono text-base font-semibold text-white">
          {{ terminal.system.ram_usage_percent ?? Math.round((terminal.system.ram_used_gb / terminal.system.ram_total_gb) * 100) }}%
        </span>
        <span class="text-[10px] text-zinc-500 block">
          {{ terminal.system.ram_used_gb }} / {{ terminal.system.ram_total_gb }} GB
        </span>
      </div>

      <!-- Disco C -->
      <div class="bg-zinc-900/60 p-3 rounded-lg border border-zinc-800">
        <span class="text-[11px] font-medium text-zinc-400 block mb-1">Disco C: Libre</span>
        <span class="font-mono text-base font-semibold text-white">
          {{ terminal.system.disk_c_percent_free }}%
        </span>
        <span class="text-[10px] text-zinc-500 block">
          <template v-if="terminal.system.disk_c_free_gb !== undefined">
            {{ terminal.system.disk_c_free_gb }} GB libres <span v-if="terminal.system.disk_c_total_gb">/ {{ terminal.system.disk_c_total_gb }} GB</span>
          </template>
          <template v-else>
            Espacio no reportado
          </template>
        </span>
      </div>

      <div class="bg-zinc-900/80 p-2.5 rounded-lg border border-zinc-800">
        <span class="text-xs text-zinc-400 block">SQL Server</span>
        <span :class="['font-mono text-base font-semibold', terminal.system.sql_service_status === 'Running' ? 'text-emerald-400' : 'text-rose-400']">
          {{ terminal.system.sql_service_status }}
        </span>
      </div>
    </div>

    <!-- Pie de la tarjeta -->
    <div class="mt-4 pt-3 border-t border-zinc-800/80 flex items-center justify-between text-[11px] text-zinc-400">
      <div class="flex items-center gap-1.5" :title="'Formato exacto: ' + (terminal.system.uptime_formatted || 'N/A')">
        <span 
          class="inline-block w-2 h-2 rounded-full" 
          :class="terminal.isOffline ? 'bg-rose-500' : 'bg-emerald-500'"
        ></span>
        <span>Activo:</span>
        <strong class="font-mono text-zinc-200">
          {{ terminal.system.uptime_human || terminal.system.uptime_formatted || 'Desconocido' }}
        </strong>
      </div>

      <span class="text-zinc-500">
        {{ terminal.timestamp ? new Date(terminal.timestamp).toLocaleTimeString() : 'N/A' }}
      </span>
    </div>
  </div>
</template>