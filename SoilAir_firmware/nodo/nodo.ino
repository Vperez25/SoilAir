/*
 * ═══════════════════════════════════════════════════════════════
 *  soilAir - Sistema Distribuido Escalable
 *  NODO GENERICO
 *  Desarrollador: Vincent Perez Adriano
 *  Fecha: 20/05/2026
 * ═══════════════════════════════════════════════════════════════
 *  Compatible con:
 *    - Arduino IDE  + ESP32 core v2.x y v3.x
 *    - PlatformIO   + espressif32 @ 6.x y 6.9+
 *    - ArduinoJson  v6.x  Y  v7.x  (deteccion automatica)
 * ═══════════════════════════════════════════════════════════════
 */

#include <Arduino.h>
#include <LittleFS.h>
#include <ArduinoJson.h>
#include <WiFi.h>
#include <WebServer.h>
#include <esp_now.h>
#include "tipos.h"   // structs defined HERE so auto-prototypes see the types

// ──────────────────────────────────────────────────────────────
//  Deteccion de version ArduinoJson (v6 vs v7)
// ──────────────────────────────────────────────────────────────
#ifndef ARDUINOJSON_VERSION_MAJOR
  #define ARDUINOJSON_VERSION_MAJOR 6
#endif

// ──────────────────────────────────────────────────────────────
//  Deteccion de version del core ESP32 (v2 vs v3)
// ──────────────────────────────────────────────────────────────
#ifndef ESP_ARDUINO_VERSION_MAJOR
  #define ESP_ARDUINO_VERSION_MAJOR 2
#endif

// ══════════════════════════════════════════════════════════════
//  CONFIGURACION DEL NODO
// ══════════════════════════════════════════════════════════════
#define NODO_ID      1
#define NODO_NOMBRE  "NODO"
#define AP_SSID      "SOILAIR_NODO"
#define AP_PASS      "soilair1"

#define MAX_NODOS          32
#define TTL_SALTOS          5
#define INTERVALO_ENVIO    10000   // ms entre transmisiones mesh
#define INTERVALO_GUARDADO 10000   // ms entre guardados en disco
#define TIMEOUT_NODO     60000    // ms para considerar nodo offline
#define MAX_ARCHIVOS          6   // demo: limpieza rápida de espacio
#define CSMA_TIMEOUT_MS      60   // ms max esperando canal libre
#define CSMA_SILENCIO_MS     15   // ms de silencio requerido antes de tx

WebServer server(80);

// ══════════════════════════════════════════════════════════════
//  VARIABLES GLOBALES
// ══════════════════════════════════════════════════════════════
DatosNodo     baseDatos[MAX_NODOS];
uint8_t       nodosConocidos      = 0;
uint32_t      secuenciaLocal      = 0;
uint8_t       macBroadcast[]      = {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};
unsigned long ultimoEnvio         = 0;
unsigned long ultimoGuardado      = 0;
unsigned long ultimoEstado        = 0;
volatile unsigned long ultimoRx   = 0;  // ultimo instante en que se recibio algo (CSMA)
String        claimToken          = "";
String        cultivoNombre       = "";  // nombre del cultivo asignado desde la app
long          timeOffset          = 0;  // epoch - millis()/1000
bool          tieneHoraReal       = false;

// ══════════════════════════════════════════════════════════════
//  TIMESTAMP — epoch real si fue sincronizado, millis() si no
// ══════════════════════════════════════════════════════════════
unsigned long getTimestamp() {
  if (tieneHoraReal) return (unsigned long)((long)(millis() / 1000) + timeOffset);
  return millis() / 1000;
}

// ══════════════════════════════════════════════════════════════
//  AUXILIARES
// ══════════════════════════════════════════════════════════════
float randomFloat(float mn, float mx) {
  return mn + (float)random(0, 10000) / 10000.0 * (mx - mn);
}

int obtenerIndiceNodo(uint8_t nodoId) {
  for (int i = 0; i < MAX_NODOS; i++)
    if (baseDatos[i].activo && i == (nodoId - 1)) return i;
  if (nodoId > 0 && nodoId <= MAX_NODOS) {
    int idx = nodoId - 1;
    baseDatos[idx].activo    = true;
    baseDatos[idx].conectado = false;  // empieza desconectado hasta confirmar
    baseDatos[idx].secuencia = 0;
    nodosConocidos++;
    Serial.printf("\n🆕 NUEVO NODO DESCUBIERTO: ID=%d\n", nodoId);
    return idx;
  }
  return -1;
}

void contarNodos(int &activos, int &conectados) {
  activos = conectados = 0;
  unsigned long ahora = millis();
  for (int i = 0; i < MAX_NODOS; i++) {
    if (baseDatos[i].activo) {
      activos++;
      if (i == NODO_ID - 1 || (ahora - baseDatos[i].ultimoContacto) < TIMEOUT_NODO) {
        baseDatos[i].conectado = true;  conectados++;
      } else {
        baseDatos[i].conectado = false;
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  GESTION DE ESPACIO LITTLEFS
// ══════════════════════════════════════════════════════════════
void limpiarArchivosViejos() {
  int count = 0;
  File root = LittleFS.open("/");
  File f = root.openNextFile();
  while (f) {
    if (String(f.name()).endsWith(".json")) count++;
    f = root.openNextFile();
  }
  if (count < MAX_ARCHIVOS) return;

  String masViejo = "";
  uint32_t tsMin  = 0xFFFFFFFF;
  root = LittleFS.open("/");
  f    = root.openNextFile();
  while (f) {
    String name = f.name();
    if (!name.startsWith("/")) name = "/" + name;
    if (name.startsWith("/medicion_") && name.endsWith(".json")) {
      uint32_t ts = (uint32_t)name.substring(10, name.length() - 5).toInt();
      if (ts > 0 && ts < tsMin) { tsMin = ts; masViejo = name; }
    }
    f = root.openNextFile();
  }
  if (masViejo != "") {
    LittleFS.remove(masViejo);
    Serial.printf("🗑️  Borrado por espacio: %s\n", masViejo.c_str());
  }
}

// ══════════════════════════════════════════════════════════════
//  CALLBACKS ESP-NOW — compatibles con core v2.x y v3.x
// ══════════════════════════════════════════════════════════════
#if ESP_ARDUINO_VERSION_MAJOR >= 3
void onDataSent(const wifi_tx_info_t *info, esp_now_send_status_t status) {}
void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
#else
void onDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {}
void onDataRecv(const uint8_t *mac_addr, const uint8_t *data, int len) {
#endif

  // CSMA: registrar actividad en el canal para que otros nodos esperen
  ultimoRx = millis();

  MensajeESPNOW msg;
  memcpy(&msg, data, sizeof(msg));
  if (msg.nodoId == NODO_ID) return;

  int idx = obtenerIndiceNodo(msg.nodoId);
  if (idx < 0) return;

  // ── FIX RECONEXION ──────────────────────────────────────────
  // Si el nodo estaba marcado offline y llega un mensaje suyo,
  // resetear su secuencia para aceptarlo de inmediato sin esperar
  // a que su contador supere el valor previo guardado.
  if (!baseDatos[idx].conectado) {
    baseDatos[idx].secuencia = 0;
    Serial.printf("🔄 NODO RECONECTADO: %s (ID:%d)\n",
                  msg.cultivo, msg.nodoId);
  }
  // ────────────────────────────────────────────────────────────

  if (msg.secuencia <= baseDatos[idx].secuencia) return;

  // Actualizar estado
  baseDatos[idx].ultimoContacto = millis();
  baseDatos[idx].timestamp      = msg.timestamp;
  baseDatos[idx].secuencia      = msg.secuencia;
  baseDatos[idx].conectado      = true;
  strncpy(baseDatos[idx].cultivo, msg.cultivo, 11);
  baseDatos[idx].cultivo[11]    = '\0';

  switch (msg.tipo) {
    case 1:
      baseDatos[idx].priHumedad     = msg.valor1; baseDatos[idx].priTemperatura = msg.valor2;
      baseDatos[idx].priPh          = msg.valor3; baseDatos[idx].priEc          = msg.valor4; break;
    case 2:
      baseDatos[idx].sec1Humedad     = msg.valor1; baseDatos[idx].sec1Temperatura = msg.valor2;
      baseDatos[idx].sec1Ec          = msg.valor3; baseDatos[idx].sec2Ec          = msg.valor4; break;
    case 3:
      baseDatos[idx].ambTemperatura = msg.valor1; baseDatos[idx].ambHumedad    = msg.valor2;
      baseDatos[idx].priRadiacion   = msg.valor3; baseDatos[idx].priN          = msg.valor4; break;
    case 4:
      baseDatos[idx].priP            = msg.valor1; baseDatos[idx].priK            = msg.valor2;
      baseDatos[idx].sec2Humedad     = msg.valor3; baseDatos[idx].sec2Temperatura = msg.valor4; break;
  }

  // Reenvio mesh
  if (msg.saltos < TTL_SALTOS) {
    MensajeESPNOW r = msg; r.saltos++;
    esp_now_send(macBroadcast, (uint8_t*)&r, sizeof(r));
  }
}

// ══════════════════════════════════════════════════════════════
//  DATOS SIMULADOS
// ══════════════════════════════════════════════════════════════
void generarDatosSimulados() {
  secuenciaLocal++;
  int idx = NODO_ID - 1;
  baseDatos[idx].activo         = true;
  baseDatos[idx].conectado      = true;
  baseDatos[idx].ultimoContacto = millis();
  baseDatos[idx].timestamp      = getTimestamp();
  baseDatos[idx].secuencia      = secuenciaLocal;
  strncpy(baseDatos[idx].cultivo, cultivoNombre.length() > 0 ? cultivoNombre.c_str() : NODO_NOMBRE, 11);
  baseDatos[idx].ambTemperatura  = randomFloat(25, 35);
  baseDatos[idx].ambHumedad      = randomFloat(50, 70);
  baseDatos[idx].priRadiacion    = random(800, 1200);
  baseDatos[idx].priPh           = randomFloat(5.8, 7.0);
  baseDatos[idx].priTemperatura  = randomFloat(25, 30);
  baseDatos[idx].priEc           = randomFloat(1.5, 2.5);
  baseDatos[idx].priHumedad      = randomFloat(50, 70);
  baseDatos[idx].priN            = random(180, 250);
  baseDatos[idx].priP            = random(30, 50);
  baseDatos[idx].priK            = random(150, 220);
  baseDatos[idx].sec1Temperatura = randomFloat(25, 30); baseDatos[idx].sec1Humedad = randomFloat(50, 70); baseDatos[idx].sec1Ec = randomFloat(1.5, 2.5);
  baseDatos[idx].sec2Temperatura = randomFloat(25, 30); baseDatos[idx].sec2Humedad = randomFloat(50, 70); baseDatos[idx].sec2Ec = randomFloat(1.5, 2.5);
}

// ══════════════════════════════════════════════════════════════
//  CSMA — esperar canal libre antes de transmitir
//  Backoff aleatorio unico por nodo para minimizar colisiones
// ══════════════════════════════════════════════════════════════
void esperarCanalLibre() {
  unsigned long inicio = millis();
  while ((millis() - ultimoRx) < CSMA_SILENCIO_MS) {
    // Canal ocupado: backoff aleatorio + offset por NODO_ID
    // para que cada nodo elija tiempos diferentes
    delay(random(5, 20) + NODO_ID * 4);
    if (millis() - inicio > CSMA_TIMEOUT_MS) break;
  }
}

void enviarMensaje(MensajeESPNOW &msg) {
  esperarCanalLibre();
  esp_now_send(macBroadcast, (uint8_t*)&msg, sizeof(msg));
  delay(20);
  esp_now_send(macBroadcast, (uint8_t*)&msg, sizeof(msg)); // doble envio
  delay(30);
}

// ══════════════════════════════════════════════════════════════
//  TRANSMISION ESP-NOW
// ══════════════════════════════════════════════════════════════
void enviarDatosESPNOW() {
  MensajeESPNOW msg;
  msg.nodoId    = NODO_ID;
  msg.timestamp = baseDatos[NODO_ID-1].timestamp;
  msg.secuencia = secuenciaLocal;
  msg.saltos    = 0;
  strncpy(msg.cultivo, cultivoNombre.length() > 0 ? cultivoNombre.c_str() : NODO_NOMBRE, 11);
  msg.cultivo[11] = '\0';
  int idx = NODO_ID - 1;

  msg.tipo=1; msg.valor1=baseDatos[idx].priHumedad;     msg.valor2=baseDatos[idx].priTemperatura;
              msg.valor3=baseDatos[idx].priPh;           msg.valor4=baseDatos[idx].priEc;           enviarMensaje(msg);
  msg.tipo=2; msg.valor1=baseDatos[idx].sec1Humedad;    msg.valor2=baseDatos[idx].sec1Temperatura;
              msg.valor3=baseDatos[idx].sec1Ec;          msg.valor4=baseDatos[idx].sec2Ec;          enviarMensaje(msg);
  msg.tipo=3; msg.valor1=baseDatos[idx].ambTemperatura; msg.valor2=baseDatos[idx].ambHumedad;
              msg.valor3=baseDatos[idx].priRadiacion;    msg.valor4=baseDatos[idx].priN;            enviarMensaje(msg);
  msg.tipo=4; msg.valor1=baseDatos[idx].priP;           msg.valor2=baseDatos[idx].priK;
              msg.valor3=baseDatos[idx].sec2Humedad;     msg.valor4=baseDatos[idx].sec2Temperatura; enviarMensaje(msg);
}

// ══════════════════════════════════════════════════════════════
//  GUARDAR JSON EN LITTLEFS
//  API compatible con ArduinoJson v6 y v7
// ══════════════════════════════════════════════════════════════
void guardarJSONConsolidado() {
  limpiarArchivosViejos();

#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument doc;
#else
  DynamicJsonDocument doc(8192);
#endif

  unsigned long ts = baseDatos[NODO_ID-1].timestamp;
  if (ts == 0) ts = getTimestamp();
  doc["timestamp"] = ts;

  float sumT = 0, sumH = 0; int cnt = 0;
  for (int i = 0; i < MAX_NODOS; i++)
    if (baseDatos[i].activo) { sumT += baseDatos[i].ambTemperatura; sumH += baseDatos[i].ambHumedad; cnt++; }

#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonObject amb = doc["ambiente"].to<JsonObject>();
#else
  JsonObject amb = doc.createNestedObject("ambiente");
#endif
  amb["temperatura"] = cnt > 0 ? round(sumT/cnt*100)/100.0 : 25.0;
  amb["humedad"]     = cnt > 0 ? round(sumH/cnt*100)/100.0 : 50.0;

#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonArray pri = doc["primarios"].to<JsonArray>();
#else
  JsonArray pri = doc.createNestedArray("primarios");
#endif
  for (int i = 0; i < MAX_NODOS; i++) {
    if (baseDatos[i].activo) {
#if ARDUINOJSON_VERSION_MAJOR >= 7
      JsonObject p = pri.add<JsonObject>();
#else
      JsonObject p = pri.createNestedObject();
#endif
      p["id"]="p"+String(i+1); p["cultivo"]=baseDatos[i].cultivo; p["conectado"]=baseDatos[i].conectado;
      p["radiacion"]=(int)baseDatos[i].priRadiacion; p["ph"]=round(baseDatos[i].priPh*100)/100.0;
      p["temperatura"]=round(baseDatos[i].priTemperatura*100)/100.0; p["ec"]=round(baseDatos[i].priEc*100)/100.0;
      p["humedad"]=(int)baseDatos[i].priHumedad; p["n"]=(int)baseDatos[i].priN;
      p["p"]=(int)baseDatos[i].priP; p["k"]=(int)baseDatos[i].priK;
    }
  }

#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonArray sec = doc["secundarios"].to<JsonArray>();
#else
  JsonArray sec = doc.createNestedArray("secundarios");
#endif
  for (int i = 0; i < MAX_NODOS; i++) {
    if (baseDatos[i].activo) {
#if ARDUINOJSON_VERSION_MAJOR >= 7
      JsonObject s1 = sec.add<JsonObject>();
      JsonObject s2 = sec.add<JsonObject>();
#else
      JsonObject s1 = sec.createNestedObject();
      JsonObject s2 = sec.createNestedObject();
#endif
      s1["id"]="s"+String(i*2+1); s1["temperatura"]=round(baseDatos[i].sec1Temperatura*100)/100.0;
      s1["humedad"]=(int)baseDatos[i].sec1Humedad;  s1["ec"]=round(baseDatos[i].sec1Ec*100)/100.0;
      s2["id"]="s"+String(i*2+2); s2["temperatura"]=round(baseDatos[i].sec2Temperatura*100)/100.0;
      s2["humedad"]=(int)baseDatos[i].sec2Humedad;  s2["ec"]=round(baseDatos[i].sec2Ec*100)/100.0;
    }
  }

  String fn = "/medicion_" + String(ts) + ".json";
  File file = LittleFS.open(fn, "w");
  if (file) {
    serializeJson(doc, file);
    file.close();

    int idx = NODO_ID - 1;
    Serial.println("\n┌──────────────────────────────────────────────────────────┐");
    Serial.printf( "│  GUARDADO EN DISCO → %s\n", fn.c_str());
    Serial.println("├──────────────────────────────────────────────────────────┤");
    Serial.printf( "│  Cultivo: %-12s   Secuencia: %lu\n", baseDatos[idx].cultivo, secuenciaLocal);
    Serial.println("│  ── SUELO ──");
    Serial.printf( "│   Humedad: %.1f%%   Temp: %.1f°C   pH: %.2f   EC: %.2f\n",
                   baseDatos[idx].priHumedad, baseDatos[idx].priTemperatura,
                   baseDatos[idx].priPh, baseDatos[idx].priEc);
    Serial.printf( "│   N: %.0f   P: %.0f   K: %.0f   Radiacion: %.0f\n",
                   baseDatos[idx].priN, baseDatos[idx].priP,
                   baseDatos[idx].priK, baseDatos[idx].priRadiacion);
    Serial.println("│  ── AMBIENTE ──");
    Serial.printf( "│   Temp aire: %.1f°C   Humedad aire: %.1f%%\n",
                   baseDatos[idx].ambTemperatura, baseDatos[idx].ambHumedad);
    Serial.println("└──────────────────────────────────────────────────────────┘");
  }
  else Serial.println("[WARN] Error al escribir JSON");
}

// ══════════════════════════════════════════════════════════════
//  SERIAL MONITOR
// ══════════════════════════════════════════════════════════════
void mostrarEstadoSerial() {
  int activos, conectados; contarNodos(activos, conectados);
  Serial.println("\n╔══════════════════════════════════════════════════════════════╗");
  Serial.printf( "║  soilAir - NODO: %-10s (ID: %d)                         ║\n", NODO_NOMBRE, NODO_ID);
  Serial.printf( "║  Nodos en red: %d activos, %d conectados                       ║\n", activos, conectados);
  Serial.printf( "║  Secuencia local: %lu                                         ║\n", secuenciaLocal);
  Serial.println("╠══════════════════════════════════════════════════════════════╣");
  Serial.println("║  CULTIVO      │ ESTADO     │ HUM%  │ TEMP  │  pH  │ SEQ      ║");
  Serial.println("╠══════════════════════════════════════════════════════════════╣");
  for (int i = 0; i < MAX_NODOS; i++) {
    if (baseDatos[i].activo) {
      const char* est = baseDatos[i].conectado ? "ONLINE    " : "OFFLINE   ";
      Serial.printf("║  %-12s │ %s │ %4.0f%% │ %5.1f │ %4.1f │ %-8lu ║\n",
        baseDatos[i].cultivo, est, baseDatos[i].priHumedad,
        baseDatos[i].priTemperatura, baseDatos[i].priPh, baseDatos[i].secuencia);
    }
  }
  Serial.println("╚══════════════════════════════════════════════════════════════╝");
  if (conectados < activos) {
    Serial.println("DATOS PRESERVADOS de nodos desconectados:");
    for (int i = 0; i < MAX_NODOS; i++)
      if (baseDatos[i].activo && !baseDatos[i].conectado)
        Serial.printf("   └─ %s: Hum=%.0f%%, Temp=%.1f°C, pH=%.1f (seq:%lu)\n",
          baseDatos[i].cultivo, baseDatos[i].priHumedad,
          baseDatos[i].priTemperatura, baseDatos[i].priPh, baseDatos[i].secuencia);
  }
}

// ══════════════════════════════════════════════════════════════
//  CLAIM — token de propiedad del nodo
// ══════════════════════════════════════════════════════════════
void cargarClaim() {
  if (!LittleFS.exists("/claim.json")) return;
  File f = LittleFS.open("/claim.json", "r");
  if (!f) return;
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument doc;
#else
  DynamicJsonDocument doc(256);
#endif
  if (!deserializeJson(doc, f)) {
    claimToken = doc["token"].as<String>();
  }
  f.close();
}

void guardarClaim(const String& token) {
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument doc;
#else
  DynamicJsonDocument doc(256);
#endif
  doc["token"] = token;
  File f = LittleFS.open("/claim.json", "w");
  if (f) { serializeJson(doc, f); f.close(); }
  claimToken = token;
}

void borrarClaim() {
  if (LittleFS.exists("/claim.json")) LittleFS.remove("/claim.json");
  claimToken = "";
}

void cargarCultivo() {
  if (!LittleFS.exists("/cultivo.json")) return;
  File f = LittleFS.open("/cultivo.json", "r");
  if (!f) return;
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument doc;
#else
  DynamicJsonDocument doc(256);
#endif
  if (!deserializeJson(doc, f)) {
    cultivoNombre = doc["cultivo"].as<String>();
  }
  f.close();
}

void guardarCultivo(const String& nombre) {
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument doc;
#else
  DynamicJsonDocument doc(256);
#endif
  doc["cultivo"] = nombre;
  File f = LittleFS.open("/cultivo.json", "w");
  if (f) { serializeJson(doc, f); f.close(); }
  cultivoNombre = nombre;
}

// ══════════════════════════════════════════════════════════════
//  HTTP HANDLERS
// ══════════════════════════════════════════════════════════════
void handleList() {
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument doc;
#else
  DynamicJsonDocument doc(4096);
#endif
  JsonArray arr = doc.to<JsonArray>();
  File root = LittleFS.open("/");
  if (!root) { server.send(500, "text/plain", "Error"); return; }
  File file = root.openNextFile();
  while (file) {
    String name = file.name();
    if (name.startsWith("/")) name.remove(0, 1);
    if (name.startsWith("medicion_") && name.endsWith(".json")) arr.add(name);
    file = root.openNextFile();
  }
  String out; serializeJson(arr, out);
  server.send(200, "application/json", out);
}

void handleGetFile() {
  if (!server.hasArg("name")) { server.send(400, "text/plain", "Falta: name"); return; }
  String name = server.arg("name");
  if (!name.startsWith("/")) name = "/" + name;
  if (!LittleFS.exists(name)) { server.send(404, "text/plain", "No existe"); return; }
  File f = LittleFS.open(name, "r");
  server.streamFile(f, "application/json");
  f.close();
}

void handleDelete() {
  if (!server.hasArg("name")) { server.send(400, "text/plain", "Falta: name"); return; }
  String name = server.arg("name");
  if (!name.startsWith("/")) name = "/" + name;
  if (LittleFS.exists(name)) { LittleFS.remove(name); server.send(200, "text/plain", "OK"); }
  else server.send(404, "text/plain", "No existe");
}

void handleStatus() {
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument doc;
#else
  DynamicJsonDocument doc(2048);
#endif
  doc["nodoId"]=NODO_ID; doc["nombre"]=NODO_NOMBRE;
  doc["secuencia"]=secuenciaLocal; doc["uptime"]=millis()/1000;
  int activos, conectados; contarNodos(activos, conectados);
  doc["nodosActivos"]=activos; doc["nodosConectados"]=conectados;
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonArray nodos = doc["nodos"].to<JsonArray>();
#else
  JsonArray nodos = doc.createNestedArray("nodos");
#endif
  for (int i = 0; i < MAX_NODOS; i++) {
    if (baseDatos[i].activo) {
#if ARDUINOJSON_VERSION_MAJOR >= 7
      JsonObject n = nodos.add<JsonObject>();
#else
      JsonObject n = nodos.createNestedObject();
#endif
      n["id"]=i+1; n["cultivo"]=baseDatos[i].cultivo;
      n["conectado"]=baseDatos[i].conectado; n["seq"]=baseDatos[i].secuencia;
    }
  }
  String out; serializeJson(doc, out);
  server.send(200, "application/json", out);
}

void handleFormat() {
  LittleFS.format();
  Serial.println("🗑️  LittleFS formateado via HTTP");
  server.send(200, "text/plain", "LittleFS formateado OK. Todos los archivos eliminados.");
}

// /claim GET → {"claimed": true/false}
void handleClaimGet() {
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument doc;
#else
  DynamicJsonDocument doc(128);
#endif
  doc["claimed"] = (claimToken.length() > 0);
  String out; serializeJson(doc, out);
  server.send(200, "application/json", out);
}

// /claim POST {"token": "..."} → 200 si OK, 403 si bloqueado
void handleClaimPost() {
  String body = server.arg("plain");
  if (body.length() == 0) { server.send(400, "text/plain", "Body requerido"); return; }
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument req;
#else
  DynamicJsonDocument req(256);
#endif
  if (deserializeJson(req, body)) {
    server.send(400, "text/plain", "JSON invalido"); return;
  }
  String token = req["token"].as<String>();
  if (token.length() == 0) { server.send(400, "text/plain", "Token vacio"); return; }

  if (claimToken.length() == 0 || claimToken == token) {
    guardarClaim(token);
    Serial.printf("Nodo vinculado (token: %.8s...)\n", token.c_str());
    server.send(200, "application/json", "{\"ok\":true}");
  } else {
    Serial.println("Intento de vinculacion rechazado (token distinto)");
    server.send(403, "application/json", "{\"ok\":false,\"error\":\"claimed\"}");
  }
}

// /setcultivo POST {"cultivo": "Jitomate"} → guarda el nombre del cultivo
void handleSetCultivo() {
  String body = server.arg("plain");
  if (body.length() == 0) { server.send(400, "text/plain", "Body requerido"); return; }
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument req;
#else
  DynamicJsonDocument req(256);
#endif
  if (deserializeJson(req, body)) { server.send(400, "text/plain", "JSON invalido"); return; }
  String nombre = req["cultivo"].as<String>();
  if (nombre.length() == 0) { server.send(400, "text/plain", "Cultivo vacio"); return; }

  guardarCultivo(nombre);
  strncpy(baseDatos[NODO_ID - 1].cultivo, nombre.c_str(), 11);
  baseDatos[NODO_ID - 1].cultivo[11] = '\0';
  Serial.printf("Cultivo configurado desde la app: %s\n", nombre.c_str());
  server.send(200, "application/json", "{\"ok\":true}");
}

// /settime POST {"epoch": 1234567890} → sincroniza hora real
void handleSetTime() {
  String body = server.arg("plain");
  if (body.length() == 0) { server.send(400, "text/plain", "Body requerido"); return; }
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument req;
#else
  DynamicJsonDocument req(128);
#endif
  if (deserializeJson(req, body)) { server.send(400, "text/plain", "JSON invalido"); return; }
  long epoch = req["epoch"].as<long>();
  if (epoch > 1000000000L) {
    timeOffset = epoch - (long)(millis() / 1000);
    tieneHoraReal = true;
    Serial.printf("Hora sincronizada: %ld (offset: %ld)\n", epoch, timeOffset);
    server.send(200, "application/json", "{\"ok\":true}");
  } else {
    server.send(400, "text/plain", "Epoch invalido");
  }
}

// /claim DELETE {"token": "..."} → 200 si liberado, 403 si token incorrecto
void handleClaimDelete() {
  String body = server.arg("plain");
  if (body.length() == 0) { server.send(400, "text/plain", "Body requerido"); return; }
#if ARDUINOJSON_VERSION_MAJOR >= 7
  JsonDocument req;
#else
  DynamicJsonDocument req(256);
#endif
  if (deserializeJson(req, body)) {
    server.send(400, "text/plain", "JSON invalido"); return;
  }
  String token = req["token"].as<String>();

  if (claimToken.length() == 0 || claimToken == token) {
    borrarClaim();
    Serial.println("Nodo liberado via HTTP");
    server.send(200, "application/json", "{\"ok\":true}");
  } else {
    server.send(403, "application/json", "{\"ok\":false,\"error\":\"wrong_token\"}");
  }
}

// ══════════════════════════════════════════════════════════════
//  SETUP
// ══════════════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200); delay(1000);
  Serial.println("\n╔══════════════════════════════════════════════════════════════╗");
  Serial.printf( "║  soilAir - NODO: %-10s (ID: %d)                         ║\n", NODO_NOMBRE, NODO_ID);
  Serial.printf( "║  WiFi: %-16s  Pass: %-8s                    ║\n", AP_SSID, AP_PASS);
  Serial.println("╚══════════════════════════════════════════════════════════════╝\n");

  for (int i = 0; i < MAX_NODOS; i++) {
    baseDatos[i].activo    = false;
    baseDatos[i].conectado = false;
    baseDatos[i].secuencia = 0;
    strcpy(baseDatos[i].cultivo, "");
  }

  if (!LittleFS.begin(true)) { Serial.println("[ERR] LittleFS"); return; }
  Serial.println("LittleFS OK");
  cargarClaim();
  if (claimToken.length() > 0)
    Serial.printf("Nodo vinculado (token: %.8s...)\n", claimToken.c_str());
  else
    Serial.println("Nodo sin vincular");
  cargarCultivo();
  if (cultivoNombre.length() > 0) {
    strncpy(baseDatos[NODO_ID - 1].cultivo, cultivoNombre.c_str(), 11);
    baseDatos[NODO_ID - 1].cultivo[11] = '\0';
    Serial.printf("Cultivo cargado: %s\n", cultivoNombre.c_str());
  }

  pinMode(0, INPUT_PULLUP); // Botón BOOT para reset físico

  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.printf("WiFi AP: %s  IP: %s\n", AP_SSID, WiFi.softAPIP().toString().c_str());

  if (esp_now_init() != ESP_OK) { Serial.println("[ERR] ESP-NOW"); return; }
  esp_now_register_send_cb(onDataSent);
  esp_now_register_recv_cb(onDataRecv);
  esp_now_peer_info_t peer = {};
  memcpy(peer.peer_addr, macBroadcast, 6);
  peer.channel=0; peer.encrypt=false;
  esp_now_add_peer(&peer);
  Serial.println("ESP-NOW OK");

  server.on("/list",    HTTP_GET,    handleList);
  server.on("/get",     HTTP_GET,    handleGetFile);
  server.on("/delete",  HTTP_GET,    handleDelete);
  server.on("/status",  HTTP_GET,    handleStatus);
  server.on("/format",  HTTP_GET,    handleFormat);
  server.on("/setcultivo", HTTP_POST, handleSetCultivo);
  server.on("/settime", HTTP_POST,   handleSetTime);
  server.on("/claim",   HTTP_GET,    handleClaimGet);
  server.on("/claim",   HTTP_POST,   handleClaimPost);
  server.on("/claim",   HTTP_DELETE, handleClaimDelete);
  server.begin();
  Serial.println("HTTP Server OK");

  // Offset de arranque: evita que todos transmitan al mismo tiempo
  // al encender el sistema simultaneamente
  delay(NODO_ID * 600);
  Serial.println("\nSistema listo! Esperando otros nodos...\n");
}

// ══════════════════════════════════════════════════════════════
//  RESET FÍSICO — mantener BOOT presionado 5 segundos
// ══════════════════════════════════════════════════════════════
unsigned long _botonPresionado = 0;
bool _botonActivo = false;

void checkResetFisico() {
  if (digitalRead(0) == LOW) {
    if (!_botonActivo) {
      _botonActivo = true;
      _botonPresionado = millis();
    } else if (millis() - _botonPresionado >= 5000 && claimToken.length() > 0) {
      borrarClaim();
      Serial.println("Nodo liberado por reset fisico (BOOT 5s)");
      _botonActivo = false; // evita repetición
    }
  } else {
    _botonActivo = false;
  }
}

// ══════════════════════════════════════════════════════════════
//  LOOP
// ══════════════════════════════════════════════════════════════
void loop() {
  server.handleClient();
  checkResetFisico();
  if (millis() - ultimoEnvio >= INTERVALO_ENVIO) {
    ultimoEnvio = millis();
    generarDatosSimulados();
    enviarDatosESPNOW();
  }
  if (millis() - ultimoEstado >= 10000) {
    ultimoEstado = millis();
    mostrarEstadoSerial();
  }
  if (millis() - ultimoGuardado >= INTERVALO_GUARDADO) {
    ultimoGuardado = millis();
    guardarJSONConsolidado();
  }
  delay(10);
}
