/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        madisa: {
          logo: {
            light: '#3b88c7', // Azul cyan del logo
            dark: '#20398c',  // Azul institucional profundo del logo
          },
          login: '#36618e',   // Azul pizarra botón login
          table: '#1976d2',   // Azul vibrante mesas / botones primarios
          surface: {
            light: '#ffffff',
            subtle: '#f8fafc',
            dark: '#0f172a',
            cardDark: '#1e293b'
          }
        }
      }
    },
  },
  plugins: [],
}