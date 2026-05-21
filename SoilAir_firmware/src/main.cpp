#include <Arduino.h>
#include <LittleFS.h>
#include <ArduinoJson.h>
#include <WiFi.h>
#include <WebServer.h>

#define BUTTON_PIN 14 // Botón para generar archivos

// ---------------------------
//     CONFIG WIFI AP POR DEFECTO
// ---------------------------
const char *DEFAULT_AP_SSID = "SOILAIR";
const char *DEFAULT_AP_PASS = "momomomo"; // mínimo 8 caracteres

WebServer server(80);

// ---------------------------
//     TIMESTAMP Y RANDOMS
// ---------------------------
unsigned long getTimestamp()
{
  return millis() / 1000; // temporal
}

float randomFloat(float min, float max)
{
  return min + (float)random(0, 10000) / 10000.0 * (max - min);
}

// ---------------------------
//   GENERAR JSON DE MEDICIÓN
// ---------------------------
void generarMedicionJSON()
{
  unsigned long timestamp = getTimestamp();

  DynamicJsonDocument doc(1024);
  doc["timestamp"] = timestamp;

  JsonObject ambiente = doc.createNestedObject("ambiente");
  ambiente["temperatura"] = randomFloat(20, 40);
  ambiente["humedad"] = random(30, 80);

  JsonArray primarios = doc.createNestedArray("primarios");
  JsonObject p1 = primarios.createNestedObject();
  p1["id"] = "p1";
  p1["radiacion"] = random(500, 1200);
  p1["ph"] = randomFloat(5.5, 7.5);
  p1["temperatura"] = randomFloat(20, 40);
  p1["ec"] = randomFloat(0.5, 2.0);
  p1["humedad"] = random(20, 60);
  p1["n"] = random(10, 50);
  p1["p"] = random(10, 50);
  p1["k"] = random(10, 50);

  JsonObject p2 = primarios.createNestedObject();
  p2["id"] = "p2";
  p2["radiacion"] = random(500, 1200);
  p2["ph"] = randomFloat(5.5, 7.5);
  p2["temperatura"] = randomFloat(20, 40);
  p2["ec"] = randomFloat(0.5, 2.0);
  p2["humedad"] = random(20, 60);
  p2["n"] = random(10, 50);
  p2["p"] = random(10, 50);
  p2["k"] = random(10, 50);

  JsonObject p3 = primarios.createNestedObject();
  p3["id"] = "p3";
  p3["radiacion"] = random(500, 1200);
  p3["ph"] = randomFloat(5.5, 7.5);
  p3["temperatura"] = randomFloat(20, 40);
  p3["ec"] = randomFloat(0.5, 2.0);
  p3["humedad"] = random(20, 60);
  p3["n"] = random(10, 50);
  p3["p"] = random(10, 50);
  p3["k"] = random(10, 50);

  JsonArray secundarios = doc.createNestedArray("secundarios");
  JsonObject s1 = secundarios.createNestedObject();
  s1["id"] = "s1";
  s1["temperatura"] = randomFloat(20, 40);
  s1["humedad"] = random(20, 60);
  s1["ec"] = randomFloat(0.5, 2.0);

  JsonObject s2 = secundarios.createNestedObject();
  s2["id"] = "s2";
  s2["temperatura"] = randomFloat(20, 40);
  s2["humedad"] = random(20, 60);
  s2["ec"] = randomFloat(0.5, 2.0);

  JsonObject s3 = secundarios.createNestedObject();
  s3["id"] = "s3";
  s3["temperatura"] = randomFloat(20, 40);
  s3["humedad"] = random(20, 60);
  s3["ec"] = randomFloat(0.5, 2.0);

  JsonObject s4 = secundarios.createNestedObject();
  s4["id"] = "s4";
  s4["temperatura"] = randomFloat(20, 40);
  s4["humedad"] = random(20, 60);
  s4["ec"] = randomFloat(0.5, 2.0);

  JsonObject s5 = secundarios.createNestedObject();
  s5["id"] = "s5";
  s5["temperatura"] = randomFloat(20, 40);
  s5["humedad"] = random(20, 60);
  s5["ec"] = randomFloat(0.5, 2.0);

  JsonObject s6 = secundarios.createNestedObject();
  s6["id"] = "s6";
  s6["temperatura"] = randomFloat(20, 40);
  s6["humedad"] = random(20, 60);
  s6["ec"] = randomFloat(0.5, 2.0);

  // 🔥 Archivo con ruta ABSOLUTA
  String filename = "/medicion_" + String(timestamp) + ".json";

  File file = LittleFS.open(filename, "w");
  if (!file)
  {
    Serial.println("Error creando archivo");
    return;
  }

  serializeJsonPretty(doc, file);
  file.close();

  Serial.print("JSON guardado: ");
  Serial.println(filename);
}

// ---------------------------
//      FUNCIONES WIFI CONFIG (NUEVAS)
// ---------------------------
struct WiFiConfig
{
  String ssid;
  String pass;
};

bool saveWiFiConfig(const String &ssid, const String &pass)
{
  DynamicJsonDocument doc(256);
  doc["ssid"] = ssid;
  doc["pass"] = pass;

  File file = LittleFS.open("/wifi_config.json", "w");
  if (!file)
    return false;

  serializeJson(doc, file);
  file.close();
  return true;
}

WiFiConfig loadWiFiConfig()
{
  WiFiConfig cfg;
  cfg.ssid = DEFAULT_AP_SSID;
  cfg.pass = DEFAULT_AP_PASS;

  if (!LittleFS.exists("/wifi_config.json"))
    return cfg;

  File file = LittleFS.open("/wifi_config.json", "r");
  if (!file)
    return cfg;

  DynamicJsonDocument doc(256);
  deserializeJson(doc, file);
  file.close();

  cfg.ssid = doc["ssid"].as<String>();
  cfg.pass = doc["pass"].as<String>();
  return cfg;
}

// ---------------------------
//             HTTP HANDLERS
// ---------------------------

// /list → lista TODOS los archivos
void handleList()
{
  DynamicJsonDocument doc(4096);
  JsonArray arr = doc.to<JsonArray>();

  File root = LittleFS.open("/");
  if (!root)
  {
    server.send(500, "text/plain", "Error leyendo LittleFS");
    return;
  }

  File file = root.openNextFile();
  while (file)
  {
    String name = file.name();

    // SOLUCIÓN: Solo eliminar el "/" si existe al inicio
    if (name.startsWith("/"))
    {
      name.remove(0, 1);
    }

    // También verificar que no esté vacío después de eliminar "/"
    // Y solo incluir archivos que empiecen con "medicion_"
    if (name.length() > 0 && name.startsWith("medicion_"))
    {
      arr.add(name);
    }

    file = root.openNextFile();
  }

  String output;
  serializeJson(arr, output);
  server.send(200, "application/json", output);
}

// /get?name=archivo.json
void handleGetFile()
{
  if (!server.hasArg("name"))
  {
    server.send(400, "text/plain", "Falta parámetro: name");
    return;
  }

  String name = server.arg("name");

  // Si Flutter manda "archivo.json" → agregar "/"
  if (!name.startsWith("/"))
  {
    name = "/" + name;
  }

  if (!LittleFS.exists(name))
  {
    server.send(404, "text/plain", "Archivo no encontrado");
    return;
  }

  File file = LittleFS.open(name, "r");
  server.streamFile(file, "application/json");
  file.close();
}

// /delete?name=archivo.json
void handleDelete()
{
  if (!server.hasArg("name"))
  {
    server.send(400, "text/plain", "Falta parámetro: name");
    return;
  }

  String name = server.arg("name");
  if (!name.startsWith("/"))
  {
    name = "/" + name;
  }

  if (!LittleFS.exists(name))
  {
    server.send(404, "text/plain", "Archivo no existe");
    return;
  }

  LittleFS.remove(name);
  server.send(200, "text/plain", "Archivo eliminado");
}

// Nuevo endpoint para cambiar SSID y contraseña
void handleSetWiFi()
{
  if (!server.hasArg("ssid") || !server.hasArg("pass"))
  {
    server.send(400, "text/plain", "Faltan parámetros ssid o pass");
    return;
  }

  String newSSID = server.arg("ssid");
  String newPASS = server.arg("pass");

  if (saveWiFiConfig(newSSID, newPASS))
  {
    server.send(200, "text/plain", "Configuración guardada. Reiniciando...");
    delay(500);
    ESP.restart();
  }
  else
  {
    server.send(500, "text/plain", "Error guardando configuración");
  }
}

// ---------------------------
//             SETUP
// ---------------------------
void setup()
{
  Serial.begin(115200);
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  if (!LittleFS.begin(true))
  {
    Serial.println("Error montando LittleFS");
    return;
  }

  Serial.println("LittleFS listo.");

  // Cargar configuración WiFi guardada (NUEVO)
  WiFiConfig cfg = loadWiFiConfig();

  // AP WiFi con configuración cargada (MODIFICADO)
  WiFi.softAP(cfg.ssid.c_str(), cfg.pass.c_str());
  Serial.print("Access Point creado: ");
  Serial.println(cfg.ssid);
  Serial.print("IP: ");
  Serial.println(WiFi.softAPIP()); // <- ESTA ES TU IP REAL PARA FLUTTER

  // Endpoints (se añade /setwifi)
  server.on("/list", HTTP_GET, handleList);
  server.on("/get", HTTP_GET, handleGetFile);
  server.on("/delete", HTTP_GET, handleDelete);
  server.on("/setwifi", HTTP_GET, handleSetWiFi); // NUEVO ENDPOINT

  server.begin();
  Serial.println("Servidor HTTP iniciado.");
}

// ---------------------------
//             LOOP
// ---------------------------
void loop()
{
  server.handleClient();

  static bool lastGen = HIGH;
  bool genState = digitalRead(BUTTON_PIN);

  if (lastGen == HIGH && genState == LOW)
  {
    Serial.println("Botón presionado → Generando medición...");
    generarMedicionJSON();
    delay(200);
  }

  lastGen = genState;
}