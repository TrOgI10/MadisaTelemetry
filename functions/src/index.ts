import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// Clave secreta que compartirá el agente y la API
const MADISA_API_KEY = "api__sbJXXUA8yR3hroeLFgTrx4cg7QoIny06";

export const reportTelemetry = onRequest(async (req, res) => {
  // Solo admitir peticiones POST
  if (req.method !== "POST") {
    res.status(405).send({ error: "Método no permitido" });
    return;
  }

  // Validar clave de seguridad
  const clientKey = req.headers["x-madisa-key"];
  if (clientKey !== MADISA_API_KEY) {
    res.status(401).send({ error: "No autorizado" });
    return;
  }

  try {
    const payload = req.body;

    if (!payload.client_id || !payload.terminal_id) {
      res.status(400).send({ error: "Faltan campos obligatorios: client_id o terminal_id" });
      return;
    }

    // ID único de documento: CLIENTE_TERMINAL (ej: CLI-001_TPV-BARRA)
    const docId = `${payload.client_id}_${payload.terminal_id}`.toUpperCase();

    // Guardar o actualizar en Firestore
    await db.collection("terminals").doc(docId).set(
      {
        client_id: payload.client_id,
        client_name: payload.client_name || "Cliente Sin Nombre",
        delegation: payload.delegation || "PALMA",
        zone: payload.zone || 1,
        terminal_id: payload.terminal_id,
        agent_version: payload.agent_version || "1.0.0",
        timestamp: payload.timestamp || new Date().toISOString(),
        last_seen: admin.firestore.FieldValue.serverTimestamp(),
        system: payload.system || {},
        database: payload.database || {}
      },
      { merge: true }
    );

    res.status(200).send({ status: "ok", docId });
  } catch (error: any) {
    console.error("Error guardando telemetría:", error);
    res.status(500).send({ error: error.message });
  }
});