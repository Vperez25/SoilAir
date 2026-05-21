#include <Arduino.h>
#include <ModbusMaster.h>

// Crear instancia Modbus
ModbusMaster node;

// Pines UART1 del ESP32
#define RXD1 16
#define TXD1 17

void setup()
{
    Serial.begin(115200);
    Serial.println("Iniciando...");

    // Configurar UART1
    Serial1.begin(4800, SERIAL_8N1, RXD1, TXD1);

    // Inicializar Modbus en UART1
    node.begin(1, Serial1); // 1 = ID del esclavo (ajusta según tu sensor)

    delay(1000);
}

void loop()
{
    uint8_t result;
    uint16_t data[2];

    // Leer 2 registros (ejemplo típico: 0x0000 temperatura, 0x0001 humedad)
    result = node.readHoldingRegisters(0x0000, 2);

    if (result == node.ku8MBSuccess)
    {
        float temperature = node.getResponseBuffer(1) / 10.0; // depende del sensor
        float humidity = node.getResponseBuffer(0) / 10.0;    // ajusta según datasheet

        Serial.print("Temperatura: ");
        Serial.print(temperature);
        Serial.print(" °C | Humedad: ");
        Serial.print(humidity);
        Serial.println(" %");
    }
    else
    {
        Serial.print("Error de lectura: ");
        Serial.println(result, HEX);
    }
    // delay para cada 10s
    delay(10000);
}
