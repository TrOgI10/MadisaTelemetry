import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyBwlTLtaMVHfa-vimSjUGyNfLUudImPzeU",
  authDomain: "loho-3ca05.firebaseapp.com",
  databaseURL: "https://loho-3ca05.firebaseio.com",
  projectId: "loho-3ca05",
  storageBucket: "loho-3ca05.firebasestorage.app",
  messagingSenderId: "151706914027",
  appId: "1:151706914027:web:ac0d694201315a018f42ae",
  measurementId: "G-GP0FXQTNYB"
};

// Inicializar Firebase
const app = initializeApp(firebaseConfig);

// Exportar la instancia de Firestore para App.vue
export const db = getFirestore(app);