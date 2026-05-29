#pragma once
#include <stdint.h>

typedef struct {
  uint8_t  nodoId;
  uint8_t  tipo;
  char     cultivo[12];
  float    valor1, valor2, valor3, valor4;
  uint32_t timestamp;
  uint32_t secuencia;
  uint8_t  saltos;
} MensajeESPNOW;

typedef struct {
  bool     activo;
  bool     conectado;
  uint32_t ultimoContacto;
  uint32_t timestamp;
  uint32_t secuencia;
  char     cultivo[12];
  float    ambTemperatura, ambHumedad;
  float    priRadiacion, priPh, priTemperatura, priEc, priHumedad;
  float    priN, priP, priK;
  float    sec1Temperatura, sec1Humedad, sec1Ec;
  float    sec2Temperatura, sec2Humedad, sec2Ec;
} DatosNodo;
