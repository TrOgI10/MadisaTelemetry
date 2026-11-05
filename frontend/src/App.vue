<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { collection, onSnapshot, type Unsubscribe } from "firebase/firestore";
import { onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { db, auth } from "./firebase";
import TerminalCard from './components/TerminalCard.vue';
import LoginView from './components/LoginView.vue';
import type { TerminalTelemetry, HealthStatus } from './types/telemetry';

// Control de autenticación y sesión
const currentUser = ref<User | null>(null);
const authChecking = ref(true);

// Control del menú lateral en móvil
const isMobileMenuOpen = ref(false);

// Filtros y datos
const selectedDelegation = ref<string>('TODAS');
const searchQuery = ref<string>('');
const delegations = ['TODAS', 'PALMA', 'MADRID', 'BARCELONA', 'IBIZA'];

// Bloquea el scroll del fondo cuando el menú lateral está abierto en móvil
watch(isMobileMenuOpen, (isOpen) => {
  if (isOpen) {
    document.body.style.overflow = 'hidden';
  } else {
    document.body.style.overflow = '';
  }
});

onUnmounted(() => {
  if (unsubscribe) {
    unsubscribe();
  }
  document.body.style.overflow = '';
});

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

function startTelemetryListener() {
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
}

onMounted(() => {
  // Comprobación de autenticación de usuario
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

  // Comprobación de actualizaciones al volver a la app en móvil
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
        // Modo sin conexión silencioso
      }
    }
  });
});

onUnmounted(() => {
  if (unsubscribe) {
    unsubscribe();
  }
});

const handleLogout = async () => {
  await signOut(auth);
};

// Filtro en memoria: Delegación + Buscador reactivo
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
  <!-- Pantalla de carga mientras comprueba la sesión -->
  <div v-if="authChecking" class="min-h-screen flex items-center justify-center bg-zinc-950 text-zinc-400 text-sm">
    Cargando sesión...
  </div>

  <!-- Si NO hay sesión activa, muestra la pantalla de inicio de sesión -->
  <LoginView v-else-if="!currentUser" />

  <!-- Si la sesión es válida, muestra el Dashboard -->
  <div v-else class="min-h-screen bg-zinc-950 text-zinc-100 font-sans">
    
    <!-- BARRA SUPERIOR FIJA -->
    <header class="fixed top-0 left-0 right-0 w-full px-4 sm:px-6 py-3 border-b border-zinc-800 bg-zinc-950/80 backdrop-blur-md z-30">
      <div class="flex justify-between items-center">
        <!-- Logo corporativo y título -->
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

      <!-- MENÚ LATERAL DESLIZABLE (DRAWER) PARA MÓVIL -->
      <Teleport to="body">
        <!-- Fondo oscurecido con desenfoque -->
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

        <!-- Panel lateral derecho con márgenes seguros para iOS -->
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
            <!-- Cabecera del lateral -->
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

              <!-- Información del técnico conectado -->
              <div class="mt-6 flex flex-col gap-2">
                <span class="text-[11px] text-zinc-500 font-medium">Técnico activo</span>
                <div class="flex items-center gap-2.5 text-xs text-zinc-200 bg-zinc-900/90 border border-zinc-800/80 p-3 rounded-xl">
                  <span class="w-2.5 h-2.5 rounded-full bg-emerald-400 flex-shrink-0 animate-pulse"></span>
                  <span class="truncate font-medium">{{ currentUser?.email }}</span>
                </div>
              </div>
            </div>

            <!-- Botón de desconexión -->
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

    <!-- CONTENIDO PRINCIPAL (con relleno superior para compensar la barra fija) -->
    <main class="pt-20 px-6 pb-6 md:px-10 md:pb-10">
      <!-- Encabezado con buscador y selectores de delegación -->
      <div class="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-zinc-800 gap-4">
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

          <!-- Botones de delegación con scroll táctil sin barra visible -->
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

      <!-- Tarjetas de resumen de estado -->
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

      <!-- Rejilla de tarjetas de terminales -->
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
  </div>
</template>