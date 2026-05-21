#include <Arduino.h>
#include <LittleFS.h>
#include <ArduinoJson.h>

#define BUTTON_PIN 14     // Botón para generar archivos
#define DUMP_BUTTON 27    // Botón para enviar todos los archivos por serial

void setup()
{
  Serial.begin(115200);

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(DUMP_BUTTON, INPUT_PULLUP);

  if (!LittleFS.begin(true))
  {
    Serial.println("Error montando LittleFS");
    return;
  }

  Serial.println("LittleFS listo. Botón 14 = generar JSON | Botón 15 = dump archivos");
}

// Tiempo falso por ahora
unsigned long getTimestamp()
{
  return millis() / 1000;
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
  p1["conductividad"] = randomFloat(0.5, 2.0);
  p1["humedad"] = random(20, 60);
  p1["n"] = random(10, 50);
  p1["p"] = random(10, 50);
  p1["k"] = random(10, 50);

  JsonArray secundarios = doc.createNestedArray("secundarios");

  JsonObject s1 = secundarios.createNestedObject();
  s1["id"] = "s1";
  s1["temperatura"] = randomFloat(20, 40);
  s1["humedad"] = random(20, 60);
  s1["conductividad"] = randomFloat(0.5, 2.0);

  JsonObject s2 = secundarios.createNestedObject();
  s2["id"] = "s2";
  s2["temperatura"] = randomFloat(20, 40);
  s2["humedad"] = random(20, 60);
  s2["conductividad"] = randomFloat(0.5, 2.0);

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

// ---------------------------------------
//      ENVIAR TODOS LOS ARCHIVOS POR SERIAL
// ---------------------------------------

void dumpTodosLosArchivos()
{
  Serial.println("\n=== DUMP DE TODOS LOS ARCHIVOS ===");

  File root = LittleFS.open("/");
  File file = root.openNextFile();

  if (!file)
  {
    Serial.println("No hay archivos en LittleFS.");
    return;
  }

  while (file)
  {
    Serial.print("\n=== ARCHIVO: ");
    Serial.print(file.name());
    Serial.println(" ===");

    // Mandar contenido byte por byte
    while (file.available())
      Serial.write(file.read());

    Serial.println("\n=== FIN ARCHIVO ===");

    file = root.openNextFile();
  }

  Serial.println("\n=== FIN DEL DUMP ===");
}

// ---------------------------
//            LOOP
// ---------------------------

void loop()
{
  static bool lastGen = HIGH;
  static bool lastDump = HIGH;

  bool genState = digitalRead(BUTTON_PIN);
  bool dumpState = digitalRead(DUMP_BUTTON);

  // Botón para generar JSON
  if (lastGen == HIGH && genState == LOW)
  {
    Serial.println("Botón 14 presionado → Generando medición...");
    generarMedicionJSON();
    delay(200);
  }

  // Botón para enviar todos los archivos por serial
  if (lastDump == HIGH && dumpState == LOW)
  {
    Serial.println("Botón 15 presionado → Enviando todos los archivos...");
    dumpTodosLosArchivos();
    delay(200);
  }

  lastGen = genState;
  lastDump = dumpState;
}
