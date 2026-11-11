<script setup lang="ts">
import { ref } from 'vue'
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth'
import { auth } from '../firebase'
import ThemeToggle from './ThemeToggle.vue'

const email = ref('')
const password = ref('')
const errorMsg = ref('')
const successMsg = ref('')
const loading = ref(false)

const handleLogin = async () => {
  errorMsg.value = ''
  successMsg.value = ''
  loading.value = true

  try {
    await signInWithEmailAndPassword(auth, email.value.trim(), password.value)
  } catch (error: any) {
    if (error.code === 'auth/invalid-credential' || error.code === 'auth/user-not-found' || error.code === 'auth/wrong-password') {
      errorMsg.value = 'Credenciales incorrectas o usuario no encontrado.'
    } else {
      errorMsg.value = 'Error al iniciar sesión. Revisa tu conexión.'
    }
  } finally {
    loading.value = false
  }
}

const handleForgotPassword = async () => {
  errorMsg.value = ''
  successMsg.value = ''

  if (!email.value.trim()) {
    errorMsg.value = 'Escribe tu correo arriba para enviarte el enlace.'
    return
  }

  try {
    await sendPasswordResetEmail(auth, email.value.trim())
    successMsg.value = `Enlace de restablecimiento enviado a ${email.value.trim()}`
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      errorMsg.value = 'No existe ningún usuario con ese correo.'
    } else {
      errorMsg.value = 'Error al enviar el correo. Inténtalo de nuevo.'
    }
  }
}
</script>

<template>
  <div class="min-h-[100dvh] flex items-center justify-center bg-[#f8fafc] dark:bg-slate-950 px-4 text-slate-800 dark:text-slate-100 transition-colors duration-200 relative">
    
    <!-- Botón de cambio de tema en esquina superior -->
    <div class="absolute top-4 right-4">
      <ThemeToggle />
    </div>

    <div class="w-full max-w-md bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-8 shadow-xl">
      <!-- Cabecera e Isotipo Corporativo -->
      <div class="flex flex-col items-center mb-6">
        <div class="w-14 h-14 rounded-full flex items-center justify-center shadow-md mb-3"
             style="background: linear-gradient(135deg, #20398c 0%, #3b88c7 100%);">
          <span class="text-white font-extrabold text-2xl tracking-tighter">M</span>
        </div>
        <h1 class="text-xl font-bold tracking-tight text-slate-900 dark:text-white">Madisa Telemetry Suite</h1>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Acceso restringido a personal técnico</p>
      </div>

      <!-- Formulario -->
      <form @submit.prevent="handleLogin" class="space-y-4">
        <div>
          <label class="block text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-2">
            Correo corporativo
          </label>
          <input 
            v-model="email" 
            type="email" 
            required
            autocomplete="email"
            placeholder="tecnico@madisa.com"
            class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-950 border border-slate-300 dark:border-slate-700 rounded-lg focus:outline-none focus:border-[#1976d2] text-slate-900 dark:text-slate-100 placeholder-slate-400 text-sm transition-colors"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-2">
            Contraseña
          </label>
          <input 
            v-model="password" 
            type="password" 
            required
            autocomplete="current-password"
            placeholder="••••••••"
            class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-950 border border-slate-300 dark:border-slate-700 rounded-lg focus:outline-none focus:border-[#1976d2] text-slate-900 dark:text-slate-100 placeholder-slate-400 text-sm transition-colors"
          />
        </div>

        <div class="flex justify-end">
          <button 
            type="button" 
            @click="handleForgotPassword" 
            class="text-xs text-slate-500 dark:text-slate-400 hover:text-[#1976d2] dark:hover:text-blue-400 transition-colors"
          >
            ¿Has olvidado tu contraseña?
          </button>
        </div>

        <!-- Mensajes -->
        <div v-if="errorMsg" class="p-3 bg-rose-50 dark:bg-rose-950/50 border border-rose-200 dark:border-rose-800/80 rounded-lg text-rose-600 dark:text-rose-400 text-xs text-center font-medium">
          {{ errorMsg }}
        </div>
        <div v-if="successMsg" class="p-3 bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800/80 rounded-lg text-emerald-600 dark:text-emerald-400 text-xs text-center font-medium">
          {{ successMsg }}
        </div>

        <!-- Botón de Login Corporativo (#36618e) -->
        <button 
          type="submit" 
          :disabled="loading"
          class="w-full py-3 text-white font-semibold rounded-lg shadow-md transition-opacity hover:opacity-90 disabled:opacity-50 text-sm flex justify-center items-center mt-2"
          style="background-color: #36618e;"
        >
          <span v-if="loading">Verificando...</span>
          <span v-else>Iniciar Sesión</span>
        </button>
      </form>
    </div>
  </div>
</template>