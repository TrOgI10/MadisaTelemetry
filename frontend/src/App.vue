<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { collection, onSnapshot, type Unsubscribe } from "firebase/firestore";
import { onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { db, auth } from "./firebase";
import TerminalCard from './components/TerminalCard.vue';
import LoginView from './components/LoginView.vue';
import ThemeToggle from './components/ThemeToggle.vue';
import type { TerminalTelemetry, HealthStatus } from './types/telemetry';

// Control de sesión y autenticación
const currentUser = ref<User | null>(null);
const authChecking = ref(true);

// Control del menú lateral en móvil y modal
const isMobileMenuOpen = ref(false);
const selectedTerminalForModal = ref<TerminalTelemetry | null>(null);

// Bloquear el scroll de fondo
watch([isMobileMenuOpen, selectedTerminalForModal], ([drawerOpen, modalData]) => {
  if (drawerOpen || modalData !== null) {
    document.body.style.overflow = 'hidden';
  } else {
    document.body.style.overflow = '';
  }
});

// Filtros y datos
const selectedDelegation = ref<string>('TODAS');
const searchQuery = ref<string>('');
const statusFilter = ref<'all' | 'optimal' | 'attention'>('all');
const delegations = ['TODAS', 'PALMA', 'MADRID', 'BARCELONA', 'IBIZA'];

const terminals = ref<TerminalTelemetry[]>([]);
let unsubscribe: Unsubscribe | null = null;

function evaluateStatus(system: any, timestampStr?: string): { status: HealthStatus; isOffline: boolean } {
  if (timestampStr) {
    const lastUpdate = new Date(timestampStr).getTime();
    const now = Date.now();
    const diffMinutes = (now - lastUpdate) / (1000 * 60);

    if (diffMinutes > 15) {
      return { status: 'red', isOffline: true };
    }
  }

  if (!system) return { status: 'red', isOffline: false };
  if (system.sql_service_status !== 'Running' && system.sql_service_status !== 'NotInstalled') {
    return { status: 'red', isOffline: false };
  }
  if (system.disk_c_percent_free < 5) return { status: 'red', isOffline: false };
  if (system.disk_c_percent_free <= 15 || system.cpu_usage_percent > 85) {
    return { status: 'amber', isOffline: false };
  }

  return { status: 'green', isOffline: false };
}

function startTelemetryListener() {
  const terminalsCol = collection(db, 'terminals');
  unsubscribe = onSnapshot(terminalsCol, (snapshot) => {
    terminals.value = snapshot.docs.map((docSnap) => {
      const data = docSnap.data();
      const evaluation = evaluateStatus(data.system, data.timestamp);

      return {
        id: docSnap.id,
        client_id: data.client_id,
        client_name: data.client_name,
        delegation: data.delegation,
        zone: data.zone,
        terminal_id: data.terminal_id,
        timestamp: data.timestamp,
        system: data.system,
        status: evaluation.status,
        isOffline: evaluation.isOffline
      } as TerminalTelemetry;
    });
  }, (error) => {
    console.error("Error al escuchar Firestore:", error);
  });
}

onMounted(() => {
  onAuthStateChanged(auth, (user) => {
    currentUser.value = user;
    authChecking.value = false;

    if (user) {
      startTelemetryListener();
    } else {
      if (unsubscribe) {
        unsubscribe();
        unsubscribe = null;
      }
      terminals.value = [];
      selectedTerminalForModal.value = null;
    }
  });

  document.addEventListener('visibilitychange', async () => {
    if (document.visibilityState === 'visible') {
      try {
        const res = await fetch(`/index.html?t=${Date.now()}`, { method: 'HEAD' });
        const etag = res.headers.get('ETag');
        const savedEtag = localStorage.getItem('app_version_etag');

        if (savedEtag && etag && savedEtag !== etag) {
          localStorage.setItem('app_version_etag', etag);
          window.location.reload();
        } else if (etag) {
          localStorage.setItem('app_version_etag', etag);
        }
      } catch (e) {}
    }
  });
});

onUnmounted(() => {
  if (unsubscribe) unsubscribe();
  document.body.style.overflow = '';
});

const handleLogout = async () => {
  await signOut(auth);
};

const toggleStatusFilter = (target: 'optimal' | 'attention') => {
  statusFilter.value = statusFilter.value === target ? 'all' : target;
};

// Terminales filtrados por delegación (alimenta los KPIs globales/por delegación)
const delegationTerminals = computed(() => {
  return terminals.value.filter((t) => {
    return selectedDelegation.value === 'TODAS' || t.delegation === selectedDelegation.value;
  });
});

// Listados separados reutilizando exactamente los mismos criterios
const optimalTerminals = computed(() => {
  return delegationTerminals.value.filter((t) => t.status === 'green' && !t.isOffline);
});

const attentionTerminals = computed(() => {
  return delegationTerminals.value.filter((t) => t.status !== 'green' || t.isOffline);
});

const hasActiveSearch = computed(() => searchQuery.value.trim().length > 0);
const shouldShowResults = computed(() => hasActiveSearch.value || statusFilter.value !== 'all');

// Equipos a mostrar según el estado seleccionado y/o el buscador
const filteredTerminals = computed(() => {
  if (!shouldShowResults.value) return [];

  let baseList = delegationTerminals.value;
  if (statusFilter.value === 'optimal') {
    baseList = optimalTerminals.value;
  } else if (statusFilter.value === 'attention') {
    baseList = attentionTerminals.value;
  }

  const query = searchQuery.value.toLowerCase().trim();
  if (!query) return baseList;

  return baseList.filter((t) => {
    return (
      (t.client_name && t.client_name.toLowerCase().includes(query)) ||
      (t.client_id && t.client_id.toLowerCase().includes(query)) ||
      (t.terminal_id && t.terminal_id.toLowerCase().includes(query))
    );
  });
});

const activeFilterLabel = computed(() => {
  if (statusFilter.value === 'optimal') return 'Óptimos';
  if (statusFilter.value === 'attention') return 'Atención Requerida';
  return '';
});
</script>

<template>
  <!-- Carga inicial -->
  <div v-if="authChecking" class="min-h-screen flex items-center justify-center bg-[#f8fafc] dark:bg-slate-950 text-slate-500 dark:text-slate-400 text-sm">
    Cargando sesión...
  </div>

  <!-- Vista Login -->
  <LoginView v-else-if="!currentUser" />

  <!-- Dashboard Principal -->
  <div v-else class="min-h-screen bg-[#f8fafc] dark:bg-slate-950 text-slate-800 dark:text-slate-100 font-sans transition-colors duration-200">
    
    <!-- BARRA SUPERIOR FIJA -->
    <header class="fixed top-0 left-0 right-0 w-full pt-[env(safe-area-inset-top)] px-4 sm:px-6 pb-3 border-b border-slate-200 dark:border-slate-800 bg-white/95 dark:bg-slate-900/95 backdrop-blur-md z-30 transition-colors duration-200 shadow-sm">
      <div class="flex justify-between items-center pt-2 max-w-7xl mx-auto">
        <!-- Logo corporativo e Isotipo V1.2.6 -->
        <div class="flex items-center gap-3">
          <img src="./assets/madisaLogo.jpg" alt="Logo MADISA" class="w-9 h-9 flex-shrink-0 rounded-full object-cover"/>
          <div>
            <div class="flex items-center gap-2">
              <span class="font-bold text-base sm:text-lg text-slate-900 dark:text-white tracking-tight">MADISA</span>
              <span class="text-[10px] uppercase font-bold tracking-wider px-1.5 py-0.5 rounded bg-blue-50 dark:bg-blue-950 text-[#1976d2] dark:text-blue-400 border border-blue-200/50 dark:border-blue-800/50">
                v1.2.6
              </span>
            </div>
            <p class="text-[10px] text-slate-500 dark:text-slate-400 font-medium leading-none hidden sm:block">Telemetry Control</p>
          </div>
        </div>

        <!-- MODO ESCRITORIO (>= 640px) -->
        <div class="hidden sm:flex items-center gap-3">
          <ThemeToggle />

          <div class="flex items-center gap-2 text-xs text-slate-600 dark:text-slate-300 bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 px-3 py-1.5 rounded-lg">
            <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
            <span class="font-medium truncate max-w-[160px]">{{ currentUser?.email }}</span>
          </div>

          <button 
            @click="handleLogout" 
            class="text-xs text-white px-3.5 py-1.5 rounded-lg shadow-sm transition-opacity hover:opacity-90 font-medium"
            style="background-color: #36618e;"
          >
            Cerrar Sesión
          </button>
        </div>

        <!-- MODO MÓVIL (< 640px) -->
        <div class="flex sm:hidden items-center gap-2">
          <ThemeToggle />
          <button 
            @click="isMobileMenuOpen = true"
            type="button"
            aria-label="Abrir menú"
            class="p-2 rounded-lg bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 focus:outline-none"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
        </div>
      </div>

      <!-- MENÚ LATERAL MÓVIL -->
      <Teleport to="body">
        <transition
          enter-active-class="transition-opacity duration-300 ease-out"
          enter-from-class="opacity-0"
          enter-to-class="opacity-100"
          leave-active-class="transition-opacity duration-200 ease-in"
          leave-from-class="opacity-100"
          leave-to-class="opacity-0"
        >
          <div 
            v-if="isMobileMenuOpen" 
            @click="isMobileMenuOpen = false" 
            class="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 sm:hidden"
          ></div>
        </transition>

        <transition
          enter-active-class="transition-transform duration-300 ease-out"
          enter-from-class="translate-x-full"
          enter-to-class="translate-x-0"
          leave-active-class="transition-transform duration-200 ease-in"
          leave-from-class="translate-x-0"
          leave-to-class="translate-x-full"
        >
          <div 
            v-if="isMobileMenuOpen"
            class="fixed top-0 right-0 h-[100dvh] w-72 max-w-[80vw] bg-white dark:bg-slate-900 border-l border-slate-200 dark:border-slate-800 px-5 pt-[max(1.25rem,env(safe-area-inset-top))] pb-[max(1.5rem,env(safe-area-inset-bottom))] flex flex-col justify-between z-50 sm:hidden shadow-2xl"
          >
            <div>
              <div class="flex items-center justify-between pb-4 border-b border-slate-200 dark:border-slate-800">
                <span class="text-xs uppercase tracking-wider text-slate-400 font-semibold">Usuario Activo</span>
                <button 
                  @click="isMobileMenuOpen = false"
                  class="p-2 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-white"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <div class="mt-6 flex flex-col gap-2">
                <span class="text-[11px] text-slate-400 font-medium">Técnico</span>
                <div class="flex items-center gap-2.5 text-xs text-slate-800 dark:text-slate-200 bg-slate-100 dark:bg-slate-800 p-3 rounded-xl border border-slate-200 dark:border-slate-700">
                  <span class="w-2.5 h-2.5 rounded-full bg-emerald-500 flex-shrink-0 animate-pulse"></span>
                  <span class="truncate font-semibold">{{ currentUser?.email }}</span>
                </div>
              </div>
            </div>

            <div>
              <button 
                @click="() => { isMobileMenuOpen = false; handleLogout(); }" 
                class="w-full text-xs font-semibold text-white py-3 px-4 rounded-xl transition-opacity hover:opacity-90 flex items-center justify-center gap-2 shadow-sm"
                style="background-color: #36618e;"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
                <span>Cerrar Sesión</span>
              </button>
            </div>
          </div>
        </transition>
      </Teleport>
    </header>

    <!-- CONTENIDO PRINCIPAL -->
    <main class="max-w-7xl mx-auto pt-[calc(env(safe-area-inset-top)+4.75rem)] px-4 sm:px-6 lg:px-8 pb-10">
      <!-- Encabezado y delegaciones -->
      <div class="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-slate-200 dark:border-slate-800 gap-4">
        <div>
          <h1 class="text-2xl font-black tracking-tight text-slate-900 dark:text-white flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-emerald-500 animate-pulse"></span>
            Madisa Telemetry Suite
          </h1>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Supervisión en tiempo real de terminales TPV y servidores</p>
        </div>

        <!-- Filtro de delegaciones estilo V1.2.6 (#1976d2) -->
        <div class="flex items-center gap-1.5 overflow-x-auto no-scrollbar w-full md:w-auto pb-1">
          <button
            v-for="del in delegations"
            :key="del"
            @click="selectedDelegation = del"
            :class="[
              'px-3 py-1.5 rounded-lg text-xs font-semibold tracking-wide transition-all whitespace-nowrap border',
              selectedDelegation === del
                ? 'bg-[#1976d2] text-white border-[#1976d2] shadow-sm'
                : 'bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800'
            ]"
          >
            {{ del }}
          </button>
        </div>
      </div>

      <!-- Tarjetas de resumen interactivas (KPIs) -->
      <section class="grid grid-cols-3 gap-4 my-6">
        <button
          type="button"
          @click="statusFilter = 'all'"
          :class="[
            'p-4 bg-white dark:bg-slate-900 rounded-xl border text-center shadow-sm transition-all cursor-pointer focus:outline-none',
            statusFilter === 'all'
              ? 'border-slate-300 dark:border-slate-700'
              : 'border-slate-200 dark:border-slate-800 opacity-75 hover:opacity-100'
          ]"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400 block font-medium">Total Registrados</span>
          <span class="text-2xl font-bold text-slate-900 dark:text-white">{{ delegationTerminals.length }}</span>
        </button>

        <button
          type="button"
          @click="toggleStatusFilter('optimal')"
          :aria-pressed="statusFilter === 'optimal'"
          :class="[
            'p-4 bg-emerald-50 dark:bg-emerald-950/20 rounded-xl border text-center text-emerald-700 dark:text-emerald-400 shadow-sm transition-all cursor-pointer active:scale-[0.99] focus:outline-none',
            statusFilter === 'optimal'
              ? 'border-emerald-500 dark:border-emerald-500 ring-2 ring-emerald-500/30 shadow-md'
              : 'border-emerald-200 dark:border-emerald-800/40 hover:border-emerald-400 dark:hover:border-emerald-700'
          ]"
        >
          <span class="text-xs opacity-80 block font-medium">Óptimos</span>
          <span class="text-2xl font-bold">{{ optimalTerminals.length }}</span>
          <span class="text-[10px] font-semibold uppercase tracking-wider mt-1 block opacity-75">
            {{ statusFilter === 'optimal' ? 'Viendo listado' : 'Ver equipos' }}
          </span>
        </button>

        <button
          type="button"
          @click="toggleStatusFilter('attention')"
          :aria-pressed="statusFilter === 'attention'"
          :class="[
            'p-4 bg-rose-50 dark:bg-rose-950/20 rounded-xl border text-center text-rose-700 dark:text-rose-400 shadow-sm transition-all cursor-pointer active:scale-[0.99] focus:outline-none',
            statusFilter === 'attention'
              ? 'border-rose-500 dark:border-rose-500 ring-2 ring-rose-500/30 shadow-md'
              : 'border-rose-200 dark:border-rose-800/40 hover:border-rose-400 dark:hover:border-rose-700'
          ]"
        >
          <span class="text-xs opacity-80 block font-medium">Atención Requerida</span>
          <span class="text-2xl font-bold">{{ attentionTerminals.length }}</span>
          <span class="text-[10px] font-semibold uppercase tracking-wider mt-1 block opacity-75">
            {{ statusFilter === 'attention' ? 'Viendo listado' : 'Ver equipos' }}
          </span>
        </button>
      </section>

      <!-- BUSCADOR PRINCIPAL DE CLIENTES -->
      <section class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-5 sm:p-6 shadow-sm mb-6">
        <div class="flex items-center justify-between gap-2 mb-2">
          <label for="client-search" class="block text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">
            Consulta de Equipos por Cliente
          </label>

          <!-- Indicador de filtro de estado activo -->
          <div v-if="statusFilter !== 'all'" class="flex items-center gap-2">
            <span
              class="inline-flex items-center gap-1.5 text-[11px] font-semibold px-2.5 py-0.5 rounded-full border"
              :class="statusFilter === 'optimal'
                ? 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800'
                : 'bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-800'"
            >
              <span
                class="w-1.5 h-1.5 rounded-full"
                :class="statusFilter === 'optimal' ? 'bg-emerald-500' : 'bg-rose-500'"
              ></span>
              Filtro: {{ activeFilterLabel }}
            </span>
            <button
              type="button"
              @click="statusFilter = 'all'"
              class="text-xs text-slate-400 hover:text-slate-700 dark:hover:text-white underline"
            >
              Quitar filtro
            </button>
          </div>
        </div>

        <div class="relative">
          <svg class="w-5 h-5 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            id="client-search"
            v-model="searchQuery"
            type="text"
            placeholder="Escribe el nombre del cliente, código (ej. A9C...) o ID de terminal..."
            class="w-full bg-slate-50 dark:bg-slate-950 border border-slate-300 dark:border-slate-700 text-sm rounded-xl pl-11 pr-10 py-3 text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:border-[#1976d2] focus:ring-2 focus:ring-[#1976d2]/15 transition-all"
          />
          <button
            v-if="searchQuery"
            @click="searchQuery = ''"
            type="button"
            aria-label="Limpiar búsqueda"
            class="absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-lg text-slate-400 hover:text-slate-700 dark:hover:text-white hover:bg-slate-200/60 dark:hover:bg-slate-800 transition-colors"
          >
            ✕
          </button>
        </div>

        <div v-if="shouldShowResults" class="mt-3 flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
          <span>
            Mostrando <strong class="text-slate-800 dark:text-slate-200">{{ filteredTerminals.length }}</strong>
            {{ filteredTerminals.length === 1 ? 'equipo' : 'equipos' }}
            <template v-if="statusFilter !== 'all'"> en estado <strong>{{ activeFilterLabel }}</strong></template>
            <template v-if="selectedDelegation !== 'TODAS'"> ({{ selectedDelegation }})</template>
          </span>
        </div>
      </section>

      <!-- RESULTADOS DE BÚSQUEDA O FILTRO DE ESTADO -->
      <section v-if="!shouldShowResults" class="text-center py-14 px-4 bg-white/60 dark:bg-slate-900/40 rounded-2xl border border-dashed border-slate-300 dark:border-slate-800">
        <div class="w-12 h-12 rounded-full bg-blue-50 dark:bg-blue-950/60 text-[#1976d2] dark:text-blue-400 flex items-center justify-center mx-auto mb-3 border border-blue-200/60 dark:border-blue-800/60">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </div>
        <h2 class="text-sm font-bold text-slate-800 dark:text-slate-200">Busca un cliente o selecciona un estado</h2>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1 max-w-md mx-auto">
          Introduce el nombre comercial o código de cliente en el buscador superior, o haz clic en <strong>Óptimos</strong> / <strong>Atención Requerida</strong> para listar sus equipos.
        </p>
      </section>

      <section v-else-if="filteredTerminals.length === 0" class="text-center py-14 px-4 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 text-slate-400 dark:text-slate-500 text-sm">
        <template v-if="hasActiveSearch">
          No se encontraron equipos para "<span class="font-semibold text-slate-600 dark:text-slate-300">{{ searchQuery }}</span>"
          <template v-if="statusFilter !== 'all'"> en estado {{ activeFilterLabel }}</template>
          <template v-if="selectedDelegation !== 'TODAS'"> ({{ selectedDelegation }})</template>.
        </template>
        <template v-else>
          No hay equipos disponibles en estado <span class="font-semibold text-slate-600 dark:text-slate-300">{{ activeFilterLabel }}</span>
          <template v-if="selectedDelegation !== 'TODAS'"> en {{ selectedDelegation }}</template>.
        </template>
      </section>

      <section v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <TerminalCard
          v-for="terminal in filteredTerminals"
          :key="terminal.client_id + '_' + terminal.terminal_id"
          :terminal="terminal"
          @select="selectedTerminalForModal = $event"
        />
      </section>
    </main>

    <!-- MODAL DE DETALLE COMPLETO DEL EQUIPO -->
    <Teleport to="body">
      <transition
        enter-active-class="transition duration-200 ease-out"
        enter-from-class="opacity-0 scale-95"
        enter-to-class="opacity-100 scale-100"
        leave-active-class="transition duration-150 ease-in"
        leave-from-class="opacity-100 scale-100"
        leave-to-class="opacity-0 scale-95"
      >
        <div 
          v-if="selectedTerminalForModal" 
          class="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4"
          @click.self="selectedTerminalForModal = null"
        >
          <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl w-full max-w-lg p-6 shadow-2xl relative max-h-[90dvh] overflow-y-auto no-scrollbar">
            
            <!-- Cabecera del modal -->
            <div class="flex items-start justify-between border-b border-slate-200 dark:border-slate-800 pb-4 gap-3">
              <div>
                <div class="flex items-center gap-2 flex-wrap">
                  <span 
                    class="w-2.5 h-2.5 rounded-full shrink-0"
                    :class="{
                      'bg-emerald-500': selectedTerminalForModal.status === 'green' && !selectedTerminalForModal.isOffline,
                      'bg-amber-500': selectedTerminalForModal.status === 'amber' && !selectedTerminalForModal.isOffline,
                      'bg-rose-500 animate-pulse': selectedTerminalForModal.status === 'red' || selectedTerminalForModal.isOffline
                    }"
                  ></span>
                  <h3 class="text-lg font-bold text-slate-900 dark:text-white">{{ selectedTerminalForModal.client_name }}</h3>
                  <span 
                    v-if="selectedTerminalForModal.isOffline" 
                    class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-rose-100 dark:bg-rose-900/60 text-rose-700 dark:text-rose-300 border border-rose-300 dark:border-rose-700 uppercase animate-pulse"
                  >
                    Offline
                  </span>
                </div>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                  {{ selectedTerminalForModal.client_id }} · {{ selectedTerminalForModal.delegation }} · Terminal:
                  <span class="font-mono font-bold text-[#1976d2] dark:text-blue-400">{{ selectedTerminalForModal.terminal_id }}</span>
                </p>
              </div>
              <button 
                @click="selectedTerminalForModal = null"
                aria-label="Cerrar modal"
                class="p-1.5 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-400 hover:text-slate-700 dark:hover:text-white transition-colors shrink-0"
              >
                ✕
              </button>
            </div>

            <!-- Aviso Offline -->
            <div 
              v-if="selectedTerminalForModal.isOffline" 
              class="mt-4 p-3 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900/60 text-rose-700 dark:text-rose-300 text-xs flex items-center gap-2"
            >
              <span class="font-bold">⚠️ Sin respuesta:</span> El TPV no emite telemetría desde hace más de 15 minutos (apagado o sin conexión a internet).
            </div>

            <!-- Métricas de Hardware y Servicio -->
            <div class="mt-4 grid grid-cols-2 gap-2.5 text-xs">
              <div class="bg-slate-50 dark:bg-slate-800/60 p-3 rounded-xl border border-slate-200/70 dark:border-slate-700/60">
                <span class="text-[10px] text-slate-400 uppercase font-semibold block">CPU</span>
                <span class="font-mono text-base font-bold text-slate-800 dark:text-white">
                  {{ selectedTerminalForModal.system.cpu_usage_percent }}%
                </span>
              </div>

              <div class="bg-slate-50 dark:bg-slate-800/60 p-3 rounded-xl border border-slate-200/70 dark:border-slate-700/60">
                <span class="text-[10px] text-slate-400 uppercase font-semibold block">RAM</span>
                <span class="font-mono text-base font-bold text-slate-800 dark:text-white">
                  {{ selectedTerminalForModal.system.ram_usage_percent ?? Math.round((selectedTerminalForModal.system.ram_used_gb / selectedTerminalForModal.system.ram_total_gb) * 100) }}%
                </span>
                <span class="text-[11px] text-slate-400 block truncate">
                  {{ selectedTerminalForModal.system.ram_used_gb }}/{{ selectedTerminalForModal.system.ram_total_gb }} GB
                </span>
              </div>

              <div class="bg-slate-50 dark:bg-slate-800/60 p-3 rounded-xl border border-slate-200/70 dark:border-slate-700/60">
                <span class="text-[10px] text-slate-400 uppercase font-semibold block">Disco C: Libre</span>
                <span class="font-mono text-base font-bold text-slate-800 dark:text-white">
                  {{ selectedTerminalForModal.system.disk_c_percent_free }}%
                </span>
                <span class="text-[11px] text-slate-400 block truncate">
                  {{ selectedTerminalForModal.system.disk_c_free_gb !== undefined ? `${selectedTerminalForModal.system.disk_c_free_gb} GB` : 'N/A' }}
                </span>
              </div>

              <div class="bg-slate-50 dark:bg-slate-800/60 p-3 rounded-xl border border-slate-200/70 dark:border-slate-700/60">
                <span class="text-[10px] text-slate-400 uppercase font-semibold block">SQL Server</span>
                <span
                  :class="[
                    'font-mono text-base font-bold',
                    selectedTerminalForModal.system.sql_service_status === 'Running'
                      ? 'text-emerald-600 dark:text-emerald-400'
                      : 'text-rose-600 dark:text-rose-400'
                  ]"
                >
                  {{ selectedTerminalForModal.system.sql_service_status }}
                </span>
              </div>
            </div>

            <!-- Estado de actividad y hora del último reporte -->
            <div class="mt-3 bg-slate-50 dark:bg-slate-800/40 px-3.5 py-2.5 rounded-xl border border-slate-200/70 dark:border-slate-700/60 flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
              <div class="flex items-center gap-1.5">
                <span
                  class="inline-block w-2 h-2 rounded-full"
                  :class="{
                    'bg-emerald-500': selectedTerminalForModal.status === 'green' && !selectedTerminalForModal.isOffline,
                    'bg-amber-500': selectedTerminalForModal.status === 'amber' && !selectedTerminalForModal.isOffline,
                    'bg-rose-500 animate-pulse': selectedTerminalForModal.status === 'red' || selectedTerminalForModal.isOffline
                  }"
                ></span>
                <span>Activo:</span>
                <strong class="font-mono text-slate-700 dark:text-slate-200">
                  {{ selectedTerminalForModal.system.uptime_human || selectedTerminalForModal.system.uptime_formatted || 'Desconocido' }}
                </strong>
              </div>
              <span>
                Último reporte:
                <strong class="font-mono text-slate-700 dark:text-slate-200">
                  {{ selectedTerminalForModal.timestamp ? new Date(selectedTerminalForModal.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'N/A' }}
                </strong>
              </span>
            </div>

            <!-- Red: IP Privada y Pública lado a lado -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 my-4">
              <div class="bg-slate-50 dark:bg-slate-800/60 p-3 rounded-xl border border-slate-200 dark:border-slate-700/60">
                <div class="text-[11px] text-slate-500 dark:text-slate-400 font-medium mb-1 flex items-center gap-1.5">
                  <span class="w-2 h-2 rounded-full bg-[#1976d2]"></span>
                  IP Privada (Local)
                </div>
                <div class="font-mono text-sm text-slate-800 dark:text-slate-200 font-semibold">
                  {{ selectedTerminalForModal.system.ip_private || 'No disponible' }}
                </div>
              </div>

              <div class="bg-slate-50 dark:bg-slate-800/60 p-3 rounded-xl border border-slate-200 dark:border-slate-700/60">
                <div class="text-[11px] text-slate-500 dark:text-slate-400 font-medium mb-1 flex items-center gap-1.5">
                  <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
                  IP Pública (Router / WAN)
                </div>
                <div class="font-mono text-sm text-[#1976d2] dark:text-blue-400 font-semibold">
                  {{ selectedTerminalForModal.system.ip_public || 'No disponible' }}
                </div>
              </div>
            </div>

            <!-- Top 3 Procesos por RAM -->
            <div class="mt-4">
              <h4 class="text-xs uppercase tracking-wider text-slate-500 dark:text-slate-400 font-semibold mb-2">
                Top 3 Procesos (Consumo RAM)
              </h4>
              <div class="space-y-1.5">
                <div 
                  v-for="(proc, index) in selectedTerminalForModal.system.top_ram_processes || []" 
                  :key="'ram_' + index"
                  class="flex items-center justify-between text-xs bg-slate-50 dark:bg-slate-950/60 px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-800"
                >
                  <span class="font-mono text-slate-700 dark:text-slate-300">{{ proc.name }}</span>
                  <span class="text-[#1976d2] dark:text-blue-400 font-semibold">{{ proc.ram_mb }} MB</span>
                </div>
                <p v-if="!selectedTerminalForModal.system.top_ram_processes?.length" class="text-xs text-slate-400 italic">
                  Sin datos de procesos en este reporte.
                </p>
              </div>
            </div>

            <!-- Top 3 Procesos por CPU -->
            <div class="mt-4">
              <h4 class="text-xs uppercase tracking-wider text-slate-500 dark:text-slate-400 font-semibold mb-2">
                Top 3 Procesos (Carga CPU acumulada)
              </h4>
              <div class="space-y-1.5">
                <div 
                  v-for="(proc, index) in selectedTerminalForModal.system.top_cpu_processes || []" 
                  :key="'cpu_' + index"
                  class="flex items-center justify-between text-xs bg-slate-50 dark:bg-slate-950/60 px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-800"
                >
                  <span class="font-mono text-slate-700 dark:text-slate-300">{{ proc.name }}</span>
                  <span class="text-amber-600 dark:text-amber-400 font-semibold">{{ proc.cpu_seconds }} s</span>
                </div>
                <p v-if="!selectedTerminalForModal.system.top_cpu_processes?.length" class="text-xs text-slate-400 italic">
                  Sin datos de procesos en este reporte.
                </p>
              </div>
            </div>

            <!-- Pie del modal -->
            <div class="mt-6 pt-4 border-t border-slate-200 dark:border-slate-800 text-right">
              <button 
                @click="selectedTerminalForModal = null"
                class="px-4 py-2 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 rounded-lg text-xs font-semibold transition-colors"
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      </transition>
    </Teleport>
  </div>
</template>