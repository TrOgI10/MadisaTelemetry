<script setup lang="ts">
import { ref } from 'vue'
import { signInWithEmailAndPassword, sendPasswordResetEmail } from 'firebase/auth'
import { auth } from '../firebase'

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
  <div class="min-h-[100dvh] flex items-center justify-center bg-zinc-950 px-4 text-zinc-100">
    <div class="w-full max-w-md bg-zinc-900 border border-zinc-800 rounded-2xl p-8 shadow-2xl">
      <!-- Cabecera -->
      <div class="flex flex-col items-center mb-8">
        <img src="/logoMadisaTelemetry.png" alt="Logo" class="w-16 h-16 mb-3 object-contain" />
        <h1 class="text-xl font-bold tracking-wide">Madisa Telemetry Suite</h1>
        <p class="text-sm text-zinc-400 mt-1">Acceso restringido a personal técnico</p>
      </div>

      <!-- Formulario -->
      <form @submit.prevent="handleLogin" class="space-y-4">
        <div>
          <label class="block text-xs font-semibold uppercase tracking-wider text-zinc-400 mb-2">
            Correo corporativo
          </label>
          <input 
            v-model="email" 
            type="email" 
            required
            autocomplete="email"
            placeholder="tecnico@madisa.com"
            class="w-full px-4 py-3 bg-zinc-950 border border-zinc-700 rounded-lg focus:outline-none focus:border-cyan-500 text-zinc-100 placeholder-zinc-500 text-sm transition-colors"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold uppercase tracking-wider text-zinc-400 mb-2">
            Contraseña
          </label>
          <input 
            v-model="password" 
            type="password" 
            required
            autocomplete="current-password"
            placeholder="••••••••"
            class="w-full px-4 py-3 bg-zinc-950 border border-zinc-700 rounded-lg focus:outline-none focus:border-cyan-500 text-zinc-100 placeholder-zinc-500 text-sm transition-colors"
          />
        </div>

        <!-- Enlace olvidé mi contraseña -->
        <div class="flex justify-end">
          <button 
            type="button" 
            @click="handleForgotPassword" 
            class="text-xs text-zinc-400 hover:text-cyan-400 transition-colors"
          >
            ¿Has olvidado tu contraseña?
          </button>
        </div>

        <!-- Mensajes -->
        <div v-if="errorMsg" class="p-3 bg-red-950/50 border border-red-800/80 rounded-lg text-red-400 text-xs text-center font-medium">
          {{ errorMsg }}
        </div>
        <div v-if="successMsg" class="p-3 bg-emerald-950/50 border border-emerald-800/80 rounded-lg text-emerald-400 text-xs text-center font-medium">
          {{ successMsg }}
        </div>

        <button 
          type="submit" 
          :disabled="loading"
          class="w-full py-3 bg-cyan-600 hover:bg-cyan-500 disabled:opacity-50 text-white font-semibold rounded-lg shadow-lg shadow-cyan-900/30 transition-all text-sm flex justify-center items-center mt-2"
        >
          <span v-if="loading">Verificando...</span>
          <span v-else>Iniciar Sesión</span>
        </button>
      </form>
    </div>
  </div>
</template>