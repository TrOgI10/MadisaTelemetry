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
const delegations = ['TODAS', 'PALMA', 'MADRID', 'BARCELONA', 'IBIZA'];

const terminals = ref<TerminalTelemetry[]>([]);
let unsubscribe: Unsubscribe | null = null;

function evaluateStatus(system: any, timestampStr?: string): { status: HealthStatus; isOffline: boolean } {
  let isOffline = false;

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
      // 1. Cancelar la conexión en tiempo real
      if (unsubscribe) {
        unsubscribe();
        unsubscribe = null;
      }
      // 2. VACIA LA MEMORIA para que no quede rastro de los clientes
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
        <!-- Logo corporativo e Isotipo V3.0 -->
        <div class="flex items-center gap-3">
          <div class="w-9 h-9 rounded-full flex items-center justify-center shadow-sm flex-shrink-0"
               style="background: linear-gradient(135deg, #20398c 0%, #3b88c7 100%);">
            <span class="text-white font-extrabold text-base tracking-tighter">M</span>
          </div>
          <div>
            <div class="flex items-center gap-2">
              <span class="font-bold text-base sm:text-lg text-slate-900 dark:text-white tracking-tight">MADISA</span>
              <span class="text-[10px] uppercase font-bold tracking-wider px-1.5 py-0.5 rounded bg-blue-50 dark:bg-blue-950 text-[#1976d2] dark:text-blue-400 border border-blue-200/50 dark:border-blue-800/50">
                v3.0
              </span>
            </div>
            <p class="text-[10px] text-slate-500 dark:text-slate-400 font-medium leading-none hidden sm:block">Full Retail Control</p>
          </div>
        </div>

        <!-- MODO ESCRITORIO (>= 640px) -->
        <div class="hidden sm:flex items-center gap-3">
          <!-- Selector de Modo Claro/Oscuro -->
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
      <!-- Encabezado con buscador y delegaciones -->
      <div class="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-slate-200 dark:border-slate-800 gap-4">
        <div>
          <h1 class="text-2xl font-black tracking-tight text-slate-900 dark:text-white flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-emerald-500 animate-pulse"></span>
            Madisa Telemetry Suite
          </h1>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Supervisión en tiempo real de terminales TPV y servidores</p>
        </div>

        <div class="flex flex-col sm:flex-row items-center gap-3">
          <!-- Input de búsqueda -->
          <div class="relative w-full sm:w-64">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar por cliente o TPV..."
              class="w-full bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 text-sm sm:text-xs rounded-lg px-3 py-2 text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:border-[#1976d2] transition-colors shadow-sm"
            />
            <button
              v-if="searchQuery"
              @click="searchQuery = ''"
              class="absolute right-2.5 top-2 text-xs text-slate-400 hover:text-slate-700 dark:hover:text-white"
            >
              ✕
            </button>
          </div>

          <!-- Filtro de delegaciones estilo V3.0 (#1976d2) -->
          <div class="flex items-center gap-1.5 overflow-x-auto no-scrollbar w-full sm:w-auto pb-1">
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
      </div>

      <!-- Tarjetas de resumen (KPIs) -->
      <section class="grid grid-cols-3 gap-4 my-6">
        <div class="p-4 bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 text-center shadow-sm">
          <span class="text-xs text-slate-500 dark:text-slate-400 block font-medium">Total Mostrados</span>
          <span class="text-2xl font-bold text-slate-900 dark:text-white">{{ filteredTerminals.length }}</span>
        </div>
        <div class="p-4 bg-emerald-50 dark:bg-emerald-950/20 rounded-xl border border-emerald-200 dark:border-emerald-800/40 text-center text-emerald-700 dark:text-emerald-400 shadow-sm">
          <span class="text-xs opacity-80 block font-medium">Óptimos</span>
          <span class="text-2xl font-bold">{{ filteredTerminals.filter(t => t.status === 'green' && !t.isOffline).length }}</span>
        </div>
        <div class="p-4 bg-rose-50 dark:bg-rose-950/20 rounded-xl border border-rose-200 dark:border-rose-800/40 text-center text-rose-700 dark:text-rose-400 shadow-sm">
          <span class="text-xs opacity-80 block font-medium">Atención Requerida</span>
          <span class="text-2xl font-bold">{{ filteredTerminals.filter(t => t.status !== 'green' || t.isOffline).length }}</span>
        </div>
      </section>

      <!-- Rejilla de terminales -->
      <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        <div v-if="filteredTerminals.length === 0" class="col-span-full text-center py-16 text-slate-400 dark:text-slate-500 text-sm">
          No se encontraron terminales para los filtros seleccionados.
        </div>
        <TerminalCard
          v-for="terminal in filteredTerminals"
          :key="terminal.client_id + '_' + terminal.terminal_id"
          :terminal="terminal"
          @select="selectedTerminalForModal = $event"
        />
      </section>
    </main>

    <!-- MODAL DE DETALLE -->
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
            <div class="flex items-start justify-between border-b border-slate-200 dark:border-slate-800 pb-4">
              <div>
                <div class="flex items-center gap-2">
                  <span 
                    class="w-2.5 h-2.5 rounded-full"
                    :class="{
                      'bg-emerald-500': selectedTerminalForModal.status === 'green' && !selectedTerminalForModal.isOffline,
                      'bg-amber-500': selectedTerminalForModal.status === 'amber' && !selectedTerminalForModal.isOffline,
                      'bg-rose-500 animate-pulse': selectedTerminalForModal.status === 'red' || selectedTerminalForModal.isOffline
                    }"
                  ></span>
                  <h3 class="text-lg font-bold text-slate-900 dark:text-white">{{ selectedTerminalForModal.client_name }}</h3>
                </div>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                  {{ selectedTerminalForModal.client_id }} · {{ selectedTerminalForModal.delegation }} · Terminal: {{ selectedTerminalForModal.terminal_id }}
                </p>
              </div>
              <button 
                @click="selectedTerminalForModal = null"
                class="p-1.5 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-400 hover:text-slate-700 dark:hover:text-white transition-colors"
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