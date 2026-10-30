<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import TerminalCard from './components/TerminalCard.vue';
import type { TerminalTelemetry, HealthStatus } from './types/telemetry';

const selectedDelegation = ref<string>('TODAS');
const delegations = ['TODAS', 'PALMA', 'MADRID', 'BARCELONA', 'IBIZA'];

// Array de terminales
const terminals = ref<TerminalTelemetry[]>([]);

// Evaluación de semáforo
function evaluateStatus(system: any): HealthStatus {
  if (system.sql_service_status !== 'Running' && system.sql_service_status !== 'NotInstalled') {
    return 'red';
  }
  if (system.disk_c_percent_free < 5) return 'red';
  if (system.disk_c_percent_free <= 15 || system.cpu_usage_percent > 85) return 'amber';
  return 'green';
}

// Carga del JSON local de public/
async function loadSnapshot() {
  try {
    const res = await fetch('/snapshot.json?t=' + Date.now());
    if (!res.ok) {
      console.warn('Esperando snapshot.json en public/...');
      return;
    }
    const data = await res.json();

    terminals.value = [
      {
        client_id: 'MAD-LOCAL',
        client_name: 'EQUIPO DE DESARROLLO',
        delegation: 'PALMA',
        zone: 1,
        terminal_id: data.terminal_id || 'PC-TEST',
        timestamp: data.timestamp || new Date().toISOString(),
        system: data.system,
        status: evaluateStatus(data.system)
      }
    ];
  } catch (error) {
    console.error('Error cargando snapshot.json:', error);
  }
}

onMounted(() => {
  loadSnapshot();
  setInterval(loadSnapshot, 5000);
});

const filteredTerminals = computed(() => {
  if (selectedDelegation.value === 'TODAS') return terminals.value;
  return terminals.value.filter(t => t.delegation === selectedDelegation.value);
});
</script>

<template>
  <main class="min-h-screen bg-zinc-950 text-zinc-100 p-6 md:p-10 font-sans">
    <!-- Cabecera -->
    <header class="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-zinc-800 gap-4">
      <div>
        <h1 class="text-2xl font-black tracking-tight text-white flex items-center gap-2">
          <span class="w-3 h-3 rounded-full bg-emerald-500 animate-pulse"></span>
          Madisa Telemetry Suite
        </h1>
        <p class="text-xs text-zinc-400 mt-1">Monitorización continua de terminales TPV y servidores locales</p>
      </div>

      <!-- Filtro por delegación -->
      <div class="flex items-center gap-2 overflow-x-auto pb-2 md:pb-0">
        <button
          v-for="del in delegations"
          :key="del"
          @click="selectedDelegation = del"
          :class="[
            'px-3 py-1.5 rounded-lg text-xs font-semibold tracking-wide transition-colors',
            selectedDelegation === del
              ? 'bg-blue-600 text-white shadow'
              : 'bg-zinc-900 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'
          ]"
        >
          {{ del }}
        </button>
      </div>
    </header>

    <!-- Resumen de Contadores -->
    <section class="grid grid-cols-3 gap-4 my-6">
      <div class="p-3 bg-zinc-900 rounded-xl border border-zinc-800 text-center">
        <span class="text-xs text-zinc-500 block">Total Terminales</span>
        <span class="text-xl font-bold">{{ filteredTerminals.length }}</span>
      </div>
      <div class="p-3 bg-emerald-950/30 rounded-xl border border-emerald-900/50 text-center text-emerald-400">
        <span class="text-xs opacity-75 block">Óptimos</span>
        <span class="text-xl font-bold">{{ filteredTerminals.filter(t => t.status === 'green').length }}</span>
      </div>
      <div class="p-3 bg-rose-950/30 rounded-xl border border-rose-900/50 text-center text-rose-400">
        <span class="text-xs opacity-75 block">Atención Requerida</span>
        <span class="text-xl font-bold">{{ filteredTerminals.filter(t => t.status !== 'green').length }}</span>
      </div>
    </section>

    <!-- Cuadrícula de Terminales -->
    <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
      <div v-if="filteredTerminals.length === 0" class="col-span-full text-center py-12 text-zinc-500 text-sm">
        No se han encontrado datos. Asegúrate de haber ejecutado <code>agent-snapshot.ps1</code> para generar el snapshot.
      </div>
      <TerminalCard
        v-for="terminal in filteredTerminals"
        :key="terminal.client_id + terminal.terminal_id"
        :terminal="terminal"
      />
    </section>
  </main>
</template>