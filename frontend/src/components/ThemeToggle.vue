<template>
  <button
    @click="toggleTheme"
    type="button"
    class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all border shadow-sm focus:outline-none"
    :class="isDark 
      ? 'bg-slate-800 text-slate-200 border-slate-700 hover:bg-slate-700' 
      : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'"
    :title="isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro'"
  >
    <svg v-if="!isDark" class="w-4 h-4 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
        d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
    </svg>
    <svg v-else class="w-4 h-4 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
        d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
    </svg>
    <span>{{ isDark ? 'Oscuro' : 'Claro' }}</span>
  </button>
</template>

<script setup lang="ts">
import { useTheme } from '../composables/useTheme';
const { isDark, toggleTheme } = useTheme();
</script>