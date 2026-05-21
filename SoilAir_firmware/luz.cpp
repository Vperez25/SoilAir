#include <Arduino.h>
#include <Wire.h>
#include "Adafruit_AS7341.h"

Adafruit_AS7341 as7341;

void setup()
{
    Serial.begin(115200);
    delay(2000);
    Serial.println("Iniciando sensor AS7341...");

    Wire.begin(21, 22); // SDA, SCL

    if (!as7341.begin())
    {
        Serial.println("❌ No se detectó el sensor AS7341. Revisa las conexiones.");
        while (1)
            delay(10);
    }

    Serial.println("✅ Sensor AS7341 detectado correctamente.");

    as7341.setATIME(100);
    as7341.setASTEP(999);
    as7341.setGain(AS7341_GAIN_64X);
}

void loop()
{
    if (!as7341.readAllChannels())
    {
        Serial.println("⚠️ Error leyendo canales");
        delay(1000);
        return;
    }

    uint16_t ch415 = as7341.getChannel(AS7341_CHANNEL_415nm_F1);
    uint16_t ch445 = as7341.getChannel(AS7341_CHANNEL_445nm_F2);
    uint16_t ch480 = as7341.getChannel(AS7341_CHANNEL_480nm_F3);
    uint16_t ch515 = as7341.getChannel(AS7341_CHANNEL_515nm_F4);
    uint16_t ch555 = as7341.getChannel(AS7341_CHANNEL_555nm_F5);
    uint16_t ch590 = as7341.getChannel(AS7341_CHANNEL_590nm_F6);
    uint16_t ch630 = as7341.getChannel(AS7341_CHANNEL_630nm_F7);
    uint16_t ch680 = as7341.getChannel(AS7341_CHANNEL_680nm_F8);
    uint16_t chClear = as7341.getChannel(AS7341_CHANNEL_CLEAR);
    uint16_t chNIR = as7341.getChannel(AS7341_CHANNEL_NIR);

    // Suma ponderada simple de luz visible (para índice solar)
    float visible = (ch445 + ch480 + ch515 + ch555 + ch590 + ch630 + ch680) / 7.0;

    // Estimación empírica de "lux" o irradiancia relativa
    float irradiancia_rel = (visible / 1024.0) * 100.0; // 0–100%
    if (irradiancia_rel > 100.0)
        irradiancia_rel = 100.0;

    Serial.println("\n☀️ --- MEDICIÓN DE RADIACIÓN SOLAR ---");
    Serial.printf("Visible promedio: %.2f\n", visible);
    Serial.printf("Infrarrojo cercano (NIR): %d\n", chNIR);
    Serial.printf("Canal CLEAR (blanco): %d\n", chClear);
    Serial.printf("Índice de radiación solar (%%): %.1f%%\n", irradiancia_rel);

    // Estimación burda en lux (depende de calibración)
    float lux = chClear * 0.5; // coeficiente aproximado
    Serial.printf("Lux aproximados: %.0f lx\n", lux);

    delay(2000);
}
