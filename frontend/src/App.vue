<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { collection, onSnapshot, type Unsubscribe } from "firebase/firestore";
import { onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { db, auth } from "./firebase";
import TerminalCard from './components/TerminalCard.vue';
import LoginView from './components/LoginView.vue';
import type { TerminalTelemetry, HealthStatus } from './types/telemetry';

// Control de sesión y autenticación
const currentUser = ref<User | null>(null);
const authChecking = ref(true);

// Control del menú lateral en móvil y del modal de detalle
const isMobileMenuOpen = ref(false);
const selectedTerminalForModal = ref<TerminalTelemetry | null>(null);

// Bloquear el scroll de fondo cuando el menú lateral o el modal están abiertos
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

// Lógica de cálculo de semáforo con comprobación de inactividad (> 15 minutos)
function evaluateStatus(system: any, timestampStr?: string): { status: HealthStatus; isOffline: boolean } {
  let isOffline = false;

  // 1. Regla de desconexión: Si lleva más de 15 min sin emitir snapshot
  if (timestampStr) {
    const lastUpdate = new Date(timestampStr).getTime();
    const now = Date.now();
    const diffMinutes = (now - lastUpdate) / (1000 * 60);

    if (diffMinutes > 15) {
      return { status: 'red', isOffline: true };
    }
  }

  // 2. Reglas del sistema
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
  // Listener de autenticación
  onAuthStateChanged(auth, (user) => {
    currentUser.value = user;
    authChecking.value = false;

    if (user) {
      startTelemetryListener();
    } else if (unsubscribe) {
      unsubscribe();
      unsubscribe = null;
    }
  });

  // Comprobación de actualizaciones PWA al volver a la app en móvil
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
      } catch (e) {
        // Silencioso en modo offline
      }
    }
  });
});

onUnmounted(() => {
  if (unsubscribe) {
    unsubscribe();
  }
  document.body.style.overflow = '';
});

const handleLogout = async () => {
  await signOut(auth);
};

// Filtro en memoria
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
  <!-- Carga inicial de sesión -->
  <div v-if="authChecking" class="min-h-screen flex items-center justify-center bg-zinc-950 text-zinc-400 text-sm">
    Cargando sesión...
  </div>

  <!-- Vista Login -->
  <LoginView v-else-if="!currentUser" />

  <!-- Dashboard Principal -->
  <div v-else class="min-h-screen bg-zinc-950 text-zinc-100 font-sans">
    
    <!-- BARRA SUPERIOR FIJA ADAPTADA A NOTCH / DYNAMIC ISLAND -->
    <header class="fixed top-0 left-0 right-0 w-full pt-[env(safe-area-inset-top)] px-4 sm:px-6 pb-3 border-b border-zinc-800 bg-zinc-950/85 backdrop-blur-md z-30">
      <div class="flex justify-between items-center pt-2">
        <!-- Logo corporativo -->
        <div class="flex items-center gap-3">
          <img src="/logoMadisaTelemetry.png" alt="Logo" class="w-8 h-8 object-contain" />
          <span class="font-bold tracking-wide text-sm sm:text-base text-zinc-100">Madisa Telemetry</span>
        </div>

        <!-- MODO ESCRITORIO (>= 640px) -->
        <div class="hidden sm:flex items-center gap-4">
          <div class="flex items-center gap-2 text-xs text-zinc-400 bg-zinc-900 border border-zinc-800 px-3 py-1.5 rounded-lg">
            <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
            <span class="text-zinc-200 font-medium">{{ currentUser?.email }}</span>
          </div>

          <button 
            @click="handleLogout" 
            class="text-xs bg-zinc-800 hover:bg-zinc-700 hover:text-white text-zinc-300 px-3 py-1.5 rounded-lg border border-zinc-700 transition-colors"
          >
            Cerrar Sesión
          </button>
        </div>

        <!-- MODO MÓVIL: Botón Hamburguesa (< 640px) -->
        <button 
          @click="isMobileMenuOpen = true"
          type="button"
          aria-label="Abrir menú"
          class="sm:hidden p-2 rounded-lg bg-zinc-800 border border-zinc-700 text-zinc-300 hover:text-white transition-colors focus:outline-none"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
      </div>

      <!-- MENÚ LATERAL DESLIZABLE (DRAWER) -->
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
            class="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 sm:hidden"
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
            class="fixed top-0 right-0 h-[100dvh] w-72 max-w-[80vw] bg-zinc-950 border-l border-zinc-800 px-5 pt-[max(1.25rem,env(safe-area-inset-top))] pb-[max(1.5rem,env(safe-area-inset-bottom))] flex flex-col justify-between z-50 sm:hidden shadow-2xl"
          >
            <div>
              <div class="flex items-center justify-between pb-4 border-b border-zinc-800/80">
                <span class="text-xs uppercase tracking-wider text-zinc-500 font-semibold">Usuario</span>
                <button 
                  @click="isMobileMenuOpen = false"
                  aria-label="Cerrar menú"
                  class="p-2 rounded-lg bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-white transition-colors"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <div class="mt-6 flex flex-col gap-2">
                <span class="text-[11px] text-zinc-500 font-medium">Técnico activo</span>
                <div class="flex items-center gap-2.5 text-xs text-zinc-200 bg-zinc-900/90 border border-zinc-800/80 p-3 rounded-xl">
                  <span class="w-2.5 h-2.5 rounded-full bg-emerald-400 flex-shrink-0 animate-pulse"></span>
                  <span class="truncate font-medium">{{ currentUser?.email }}</span>
                </div>
              </div>
            </div>

            <div>
              <button 
                @click="() => { isMobileMenuOpen = false; handleLogout(); }" 
                class="w-full text-xs font-semibold bg-rose-950/40 hover:bg-rose-900/60 text-rose-300 border border-rose-900/70 py-3 px-4 rounded-xl transition-colors flex items-center justify-center gap-2"
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
    <main class="pt-[calc(env(safe-area-inset-top)+4.5rem)] px-6 pb-6 md:px-10 md:pb-10">
      <!-- Encabezado con buscador y delegaciones -->
      <div class="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-zinc-800 gap-4">
        <div>
          <h1 class="text-2xl font-black tracking-tight text-white flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-emerald-500 animate-pulse"></span>
            Madisa Telemetry Suite
          </h1>
          <p class="text-xs text-zinc-400 mt-1">Monitorización continua de terminales TPV y servidores</p>
        </div>

        <div class="flex flex-col sm:flex-row items-center gap-3">
          <!-- Input de búsqueda -->
          <div class="relative w-full sm:w-64">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar por cliente o TPV..."
              class="w-full bg-zinc-900 border border-zinc-700 text-base sm:text-xs rounded-lg px-3 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-blue-500 transition-colors"
            />
            <button
              v-if="searchQuery"
              @click="searchQuery = ''"
              class="absolute right-2.5 top-2 text-xs text-zinc-400 hover:text-white"
            >
              ✕
            </button>
          </div>

          <!-- Filtro de delegaciones -->
          <div class="flex items-center gap-1.5 overflow-x-auto no-scrollbar [-webkit-overflow-scrolling:touch] w-full sm:w-auto pb-1">
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
      </div>

      <!-- Tarjetas de resumen -->
      <section class="grid grid-cols-3 gap-4 my-6">
        <div class="p-3 bg-zinc-900 rounded-xl border border-zinc-800 text-center">
          <span class="text-xs text-zinc-500 block">Total Mostrados</span>
          <span class="text-xl font-bold">{{ filteredTerminals.length }}</span>
        </div>
        <div class="p-3 bg-emerald-950/30 rounded-xl border border-emerald-900/50 text-center text-emerald-400">
          <span class="text-xs opacity-75 block">Óptimos</span>
          <span class="text-xl font-bold">{{ filteredTerminals.filter(t => t.status === 'green' && !t.isOffline).length }}</span>
        </div>
        <div class="p-3 bg-rose-950/30 rounded-xl border border-rose-900/50 text-center text-rose-400">
          <span class="text-xs opacity-75 block">Atención Requerida</span>
          <span class="text-xl font-bold">{{ filteredTerminals.filter(t => t.status !== 'green' || t.isOffline).length }}</span>
        </div>
      </section>

      <!-- Rejilla de terminales -->
      <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        <div v-if="filteredTerminals.length === 0" class="col-span-full text-center py-16 text-zinc-500 text-sm">
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

    <!-- MODAL DE DETALLE DEL TERMINAL SELECCIONADO -->
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
          class="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4"
          @click.self="selectedTerminalForModal = null"
        >
          <div class="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-lg p-6 shadow-2xl relative max-h-[90dvh] overflow-y-auto no-scrollbar">
            
            <!-- Cabecera del modal -->
            <div class="flex items-start justify-between border-b border-zinc-800 pb-4">
              <div>
                <div class="flex items-center gap-2">
                  <span 
                    class="w-2.5 h-2.5 rounded-full"
                    :class="{
                      'bg-emerald-400': selectedTerminalForModal.status === 'green' && !selectedTerminalForModal.isOffline,
                      'bg-amber-400': selectedTerminalForModal.status === 'amber' && !selectedTerminalForModal.isOffline,
                      'bg-rose-500 animate-pulse': selectedTerminalForModal.status === 'red' || selectedTerminalForModal.isOffline
                    }"
                  ></span>
                  <h3 class="text-lg font-bold text-white">{{ selectedTerminalForModal.client_name }}</h3>
                </div>
                <p class="text-xs text-zinc-400 mt-0.5">
                  {{ selectedTerminalForModal.client_id }} · {{ selectedTerminalForModal.delegation }} · Terminal: {{ selectedTerminalForModal.terminal_id }}
                </p>
              </div>
              <button 
                @click="selectedTerminalForModal = null"
                aria-label="Cerrar modal"
                class="p-1.5 rounded-lg bg-zinc-800 text-zinc-400 hover:text-white"
              >
                ✕
              </button>
            </div>

            <!-- Aviso si está caído (> 15 min) -->
            <div 
              v-if="selectedTerminalForModal.isOffline" 
              class="mt-4 p-3 rounded-xl bg-rose-950/40 border border-rose-900/60 text-rose-300 text-xs flex items-center gap-2"
            >
              <span class="font-bold">⚠️ Sin respuesta:</span> El TPV no emite telemetría desde hace más de 15 minutos (posiblemente apagado o sin conexión a internet).
            </div>

            <!-- Fila: IP Privada y Estado SQL -->
            <!-- Sección de Red / Direcciones IP -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-4">
              <!-- IP Privada -->
              <div class="bg-slate-800/60 p-3 rounded-lg border border-slate-700/60">
                <div class="text-xs text-slate-400 font-medium mb-1 flex items-center gap-1.5">
                  <span class="w-2 h-2 rounded-full bg-blue-500"></span>
                  IP Privada (Local)
                </div>
                <div class="font-mono text-sm text-slate-200 font-semibold">
                  {{ selectedTerminalForModal.system.ip_private || 'No disponible' }}
                </div>
              </div>

              <!-- IP Pública -->
              <div class="bg-slate-800/60 p-3 rounded-lg border border-slate-700/60">
                <div class="text-xs text-slate-400 font-medium mb-1 flex items-center gap-1.5">
                  <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
                  IP Pública (Router / WAN)
                </div>
                <div class="font-mono text-sm text-slate-200 font-semibold">
                  {{ selectedTerminalForModal.system.ip_public || 'No disponible' }}
                </div>
              </div>
            </div>

            <!-- Top 3 Procesos por RAM -->
            <div class="mt-5">
              <h4 class="text-xs uppercase tracking-wider text-zinc-400 font-semibold mb-2">
                Top 3 Procesos (Consumo RAM)
              </h4>
              <div class="space-y-1.5">
                <div 
                  v-for="(proc, index) in selectedTerminalForModal.system.top_ram_processes || []" 
                  :key="'ram_' + index"
                  class="flex items-center justify-between text-xs bg-zinc-950/60 px-3 py-2 rounded-lg border border-zinc-800/60"
                >
                  <span class="font-mono text-zinc-200">{{ proc.name }}</span>
                  <span class="text-cyan-300 font-semibold">{{ proc.ram_mb }} MB</span>
                </div>
                <p v-if="!selectedTerminalForModal.system.top_ram_processes?.length" class="text-xs text-zinc-500 italic">
                  Sin datos de procesos en este reporte.
                </p>
              </div>
            </div>

            <!-- Top 3 Procesos por CPU -->
            <div class="mt-5">
              <h4 class="text-xs uppercase tracking-wider text-zinc-400 font-semibold mb-2">
                Top 3 Procesos (Carga CPU acumulada)
              </h4>
              <div class="space-y-1.5">
                <div 
                  v-for="(proc, index) in selectedTerminalForModal.system.top_cpu_processes || []" 
                  :key="'cpu_' + index"
                  class="flex items-center justify-between text-xs bg-zinc-950/60 px-3 py-2 rounded-lg border border-zinc-800/60"
                >
                  <span class="font-mono text-zinc-200">{{ proc.name }}</span>
                  <span class="text-amber-300 font-semibold">{{ proc.cpu_seconds }} s</span>
                </div>
                <p v-if="!selectedTerminalForModal.system.top_cpu_processes?.length" class="text-xs text-zinc-500 italic">
                  Sin datos de procesos en este reporte.
                </p>
              </div>
            </div>

            <!-- Pie del modal -->
            <div class="mt-6 pt-4 border-t border-zinc-800 text-right">
              <button 
                @click="selectedTerminalForModal = null"
                class="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-zinc-200 rounded-lg text-xs font-medium transition-colors"
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