<script setup lang="ts">
import { computed } from 'vue';
import type { TerminalTelemetry } from '../types/telemetry';

const props = defineProps<{
  terminal: TerminalTelemetry;
}>();

const statusColor = computed(() => {
  switch (props.terminal.status) {
    case 'green': return 'border-emerald-500 bg-emerald-950/20 text-emerald-400';
    case 'amber': return 'border-amber-500 bg-amber-950/20 text-amber-400';
    case 'red': return 'border-rose-500 bg-rose-950/20 text-rose-400';
    default: return 'border-zinc-700 bg-zinc-900 text-zinc-400';
  }
});
</script>

<template>
  <div :class="['rounded-xl border p-4 shadow-lg transition-all', statusColor]">
    <div class="flex items-center justify-between pb-2 border-b border-zinc-800">
      <div>
        <h3 class="font-bold text-white text-lg">{{ terminal.client_name }}</h3>
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
      <div class="bg-zinc-900/80 p-2.5 rounded-lg border border-zinc-800">
        <span class="text-xs text-zinc-400 block">RAM</span>
        <span class="font-mono text-base font-semibold text-white">{{ terminal.system.ram_usage_percent }}%</span>
        <span class="text-[10px] text-zinc-500 block">{{ terminal.system.ram_used_gb }} / {{ terminal.system.ram_total_gb }} GB</span>
      </div>
      <div class="bg-zinc-900/80 p-2.5 rounded-lg border border-zinc-800">
        <span class="text-xs text-zinc-400 block">Disco C: Libre</span>
        <span class="font-mono text-base font-semibold text-white">{{ terminal.system.disk_c_percent_free }}%</span>
        <span class="text-[10px] text-zinc-500 block">{{ terminal.system.disk_c_free_gb }} GB libres</span>
      </div>
      <div class="bg-zinc-900/80 p-2.5 rounded-lg border border-zinc-800">
        <span class="text-xs text-zinc-400 block">SQL Server</span>
        <span :class="['font-mono text-base font-semibold', terminal.system.sql_service_status === 'Running' ? 'text-emerald-400' : 'text-rose-400']">
          {{ terminal.system.sql_service_status }}
        </span>
      </div>
    </div>

    <div class="mt-3 flex items-center justify-between text-[11px] text-zinc-400 pt-2 border-t border-zinc-800/80">
      <span>Activo: <strong class="text-zinc-200 font-mono">{{ terminal.system.uptime_formatted }}</strong></span>
      <span>Actualizado: {{ new Date(terminal.timestamp).toLocaleTimeString() }}</span>
    </div>
  </div>
</template>