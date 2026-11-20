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
      return 'border-emerald-300 dark:border-emerald-900 bg-emerald-50/40 dark:bg-emerald-950/20 hover:border-emerald-400';
    case 'amber':
      return 'border-amber-300 dark:border-amber-900 bg-amber-50/40 dark:bg-amber-950/20 hover:border-amber-400';
    case 'red':
      return 'border-rose-300 dark:border-rose-900 bg-rose-50/40 dark:bg-rose-950/20 hover:border-rose-400';
    default:
      return 'border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900';
  }
});

const statusDotClasses = computed(() => {
  if (props.terminal.isOffline || props.terminal.status === 'red') {
    return 'bg-rose-500 animate-pulse';
  }
  if (props.terminal.status === 'amber') {
    return 'bg-amber-500';
  }
  return 'bg-emerald-500';
});

const statusLabel = computed(() => {
  if (props.terminal.isOffline) return 'Offline';
  if (props.terminal.status === 'red') return 'Crítico';
  if (props.terminal.status === 'amber') return 'Revisión';
  return 'Óptimo';
});
</script>

<template>
  <div
    @click="emit('select', props.terminal)"
    :class="[
      'rounded-xl border p-4 shadow-sm hover:shadow-md transition-all cursor-pointer active:scale-[0.99] select-none flex items-center justify-between gap-3',
      statusCardClasses
    ]"
  >
    <!-- Dispositivo y Cliente -->
    <div class="min-w-0 flex-1">
      <div class="flex items-center gap-2 min-w-0">
        <span class="text-xs font-mono font-bold px-2 py-0.5 rounded bg-white/80 dark:bg-slate-800 text-[#1976d2] dark:text-blue-400 border border-slate-200/80 dark:border-slate-700 shrink-0">
          {{ terminal.terminal_id }}
        </span>
        <span class="text-[11px] text-slate-500 dark:text-slate-400 truncate">
          {{ terminal.client_id }} · {{ terminal.delegation }}
        </span>
        <span
          v-if="terminal.hasClockSkew"
          class="inline-flex items-center justify-center w-5 h-5 rounded-md bg-amber-50 dark:bg-amber-950/40 border border-amber-300/80 dark:border-amber-800/70 text-amber-600 dark:text-amber-400 shrink-0"
          title="Este cliente tiene la hora mal puesta"
          aria-label="Este cliente tiene la hora mal puesta"
        >
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </span>
      </div>

      <h3 class="font-bold text-slate-900 dark:text-white text-base leading-snug truncate mt-1.5">
        {{ terminal.client_name }}
      </h3>
    </div>

    <!-- Indicador Visual de Estado -->
    <div class="flex flex-col items-end shrink-0 gap-1">
      <span
        class="inline-block w-3.5 h-3.5 rounded-full shadow-sm"
        :class="statusDotClasses"
        :title="statusLabel"
      ></span>
      <span
        class="text-[10px] font-bold uppercase tracking-wider"
        :class="{
          'text-emerald-700 dark:text-emerald-400': terminal.status === 'green' && !terminal.isOffline,
          'text-amber-700 dark:text-amber-400': terminal.status === 'amber' && !terminal.isOffline,
          'text-rose-700 dark:text-rose-400': terminal.status === 'red' || terminal.isOffline
        }"
      >
        {{ statusLabel }}
      </span>
    </div>
  </div>
</template>