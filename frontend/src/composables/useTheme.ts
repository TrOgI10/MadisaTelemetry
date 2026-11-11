import { ref } from 'vue';

const getInitialTheme = (): boolean => {
  if (typeof window === 'undefined') return false;
  const saved = localStorage.getItem('madisa_theme');
  if (saved) {
    return saved === 'dark';
  }
  return window.matchMedia('(prefers-color-scheme: dark)').matches;
};

const isDark = ref<boolean>(getInitialTheme());

// Aplica la clase al HTML en cuanto arranca la app
if (typeof document !== 'undefined') {
  if (isDark.value) {
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
  }
}

export function useTheme() {
  const toggleTheme = () => {
    isDark.value = !isDark.value;
    if (isDark.value) {
      document.documentElement.classList.add('dark');
      localStorage.setItem('madisa_theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('madisa_theme', 'light');
    }
  };

  return {
    isDark,
    toggleTheme
  };
}