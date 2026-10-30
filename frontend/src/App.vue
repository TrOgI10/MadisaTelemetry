<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { collection, onSnapshot, type Unsubscribe } from "firebase/firestore";
import { db } from "./firebase";
import TerminalCard from './components/TerminalCard.vue';
import type { TerminalTelemetry, HealthStatus } from './types/telemetry';

const selectedDelegation = ref<string>('TODAS');
const searchQuery = ref<string>('');
const delegations = ['TODAS', 'PALMA', 'MADRID', 'BARCELONA', 'IBIZA'];

const terminals = ref<TerminalTelemetry[]>([]);
let unsubscribe: Unsubscribe | null = null;

// Lógica de semáforo según el estado del sistema
function evaluateStatus(system: any): HealthStatus {
  if (!system) return 'red';
  if (system.sql_service_status !== 'Running' && system.sql_service_status !== 'NotInstalled') return 'red';
  if (system.disk_c_percent_free < 5) return 'red';
  if (system.disk_c_percent_free <= 15 || system.cpu_usage_percent > 85) return 'amber';
  return 'green';
}

onMounted(() => {
  // Suscripción reactiva en tiempo real a la colección 'terminals'
  const terminalsCol = collection(db, 'terminals');
  
  unsubscribe = onSnapshot(terminalsCol, (snapshot) => {
    terminals.value = snapshot.docs.map((docSnap) => {
      const data = docSnap.data();
      return {
        id: docSnap.id,
        client_id: data.client_id,
        client_name: data.client_name,
        delegation: data.delegation,
        zone: data.zone,
        terminal_id: data.terminal_id,
        timestamp: data.timestamp,
        system: data.system,
        status: evaluateStatus(data.system)
      } as TerminalTelemetry;
    });
  }, (error) => {
    console.error("Error al escuchar Firestore:", error);
  });
});

onUnmounted(() => {
  // Limpiar el listener al desmontar el componente
  if (unsubscribe) {
    unsubscribe();
  }
});

// Filtro en memoria: Delegación + Buscador reactivo por nombre o ID
const filteredTerminals = computed(() => {
  return terminals.value.filter((t) => {
    const matchesDelegation =
      selectedDelegation.value === 'TODAS' || t.delegation === selectedDelegation.value;

    const query = searchQuery.value.toLowerCase().trim();
    const matchesSearch =
      query === '' ||
      (t.client_name && t.client_name.toLowerCase().includes(query)) ||
      (t.client_id && t.client_id.toLowerCase().includes(query)) ||
      (t.terminal_id && t.terminal_id.toLowerCase().includes(query));

    return matchesDelegation && matchesSearch;
  });
});
</script>

<template>
  <main class="min-h-screen bg-zinc-950 text-zinc-100 p-6 md:p-10 font-sans">
    <!-- Encabezado con buscador y selectores -->
    <header class="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-zinc-800 gap-4">
      <div>
        <h1 class="text-2xl font-black tracking-tight text-white flex items-center gap-2">
          <span class="w-3 h-3 rounded-full bg-emerald-500 animate-pulse"></span>
          Madisa Telemetry Suite
        </h1>
        <p class="text-xs text-zinc-400 mt-1">Monitorización continua de terminales TPV y servidores</p>
      </div>

      <div class="flex flex-col sm:flex-row items-center gap-3">
        <!-- Input de búsqueda reactivo -->
        <div class="relative w-full sm:w-64">
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar por cliente o TPV..."
            class="w-full bg-zinc-900 border border-zinc-700 text-xs rounded-lg px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-blue-500 transition-colors"
          />
          <button
            v-if="searchQuery"
            @click="searchQuery = ''"
            class="absolute right-2.5 top-2 text-xs text-zinc-400 hover:text-white"
          >
            ✕
          </button>
        </div>

        <!-- Botones de delegación -->
        <div class="flex items-center gap-1.5 overflow-x-auto w-full sm:w-auto">
          <button
            v-for="del in delegations"
            :key="del"
            @click="selectedDelegation = del"
            :class="[
              'px-3 py-1.5 rounded-lg text-xs font-semibold tracking-wide transition-colors whitespace-nowrap',
              selectedDelegation === del
                ? 'bg-blue-600 text-white shadow'
                : 'bg-zinc-900 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'
            ]"
          >
            {{ del }}
          </button>
        </div>
      </div>
    </header>

    <!-- Indicadores de estado -->
    <section class="grid grid-cols-3 gap-4 my-6">
      <div class="p-3 bg-zinc-900 rounded-xl border border-zinc-800 text-center">
        <span class="text-xs text-zinc-500 block">Total Mostrados</span>
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

    <!-- Listado de tarjetas de terminales -->
    <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
      <div v-if="filteredTerminals.length === 0" class="col-span-full text-center py-16 text-zinc-500 text-sm">
        No se encontraron terminales para los filtros seleccionados.
      </div>
      <TerminalCard
        v-for="terminal in filteredTerminals"
        :key="terminal.client_id + '_' + terminal.terminal_id"
        :terminal="terminal"
      />
    </section>
  </main>
</template>