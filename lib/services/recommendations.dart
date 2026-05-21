class Sugerencia {
  final String sensorNombre;
  final String parametro;
  final double? valor;
  final String mensaje;
  final String nivel;

  Sugerencia({
    required this.sensorNombre,
    required this.parametro,
    required this.valor,
    required this.mensaje,
    required this.nivel,
  });
}

class EvaluadorSugerencias {
  static List<Sugerencia> evaluarSensor({
    required Map<String, dynamic> sensor,
    required Map<String, dynamic> rangos,
  }) {
    List<Sugerencia> sugerencias = [];

    final nombre = sensor['nombre'] ?? 'Sensor';
    final params = ['n', 'p', 'k', 'ph', 'humedad', 'ec', 'temperatura'];

    for (var param in params) {
      final valor = sensor[param] as double?;
      if (valor == null) continue;

      final optMin = rangos['${param}_optimo_min'] as double?;
      final optMax = rangos['${param}_optimo_max'] as double?;
      final critMin = rangos['${param}_critico_min'] as double?;
      final critMax = rangos['${param}_critico_max'] as double?;

      if (critMin != null && valor < critMin) {
        sugerencias.add(Sugerencia(
          sensorNombre: nombre,
          parametro: param,
          valor: valor,
          nivel: 'crítico',
          mensaje: _mensajeCritico(param, bajo: true),
        ));
      } else if (critMax != null && valor > critMax) {
        sugerencias.add(Sugerencia(
          sensorNombre: nombre,
          parametro: param,
          valor: valor,
          nivel: 'crítico',
          mensaje: _mensajeCritico(param, bajo: false),
        ));
      } else if (optMin != null && valor < optMin) {
        sugerencias.add(Sugerencia(
          sensorNombre: nombre,
          parametro: param,
          valor: valor,
          nivel: 'bajo',
          mensaje: _mensajeBasico(param, bajo: true),
        ));
      } else if (optMax != null && valor > optMax) {
        sugerencias.add(Sugerencia(
          sensorNombre: nombre,
          parametro: param,
          valor: valor,
          nivel: 'alto',
          mensaje: _mensajeBasico(param, bajo: false),
        ));
      }
    }

    return sugerencias;
  }

  static String _mensajeCritico(String param, {required bool bajo}) {
    switch (param) {
      case 'n':
        return bajo
            ? 'Se detecta una deficiencia crítica de nitrógeno. Esto puede afectar seriamente el crecimiento. Aplica fertilizantes ricos en nitrógeno lo antes posible.'
            : 'El nivel de nitrógeno es excesivamente alto. Podría causar toxicidad o interferir con la absorción de otros nutrientes como el potasio. Reduce la fertilización con nitrógeno.';
      case 'p':
        return bajo
            ? 'Fósforo en nivel muy bajo. Esto puede afectar el desarrollo radicular y la floración. Aplica un fertilizante fosfatado de liberación rápida.'
            : 'Fósforo en exceso. Puede causar desequilibrios con micronutrientes como el zinc. Evita añadir más fósforo.';
      case 'k':
        return bajo
            ? 'Deficiencia severa de potasio. Esto puede comprometer la resistencia al estrés hídrico. Aplica un fertilizante con alta concentración de potasio.'
            : 'Exceso crítico de potasio. Podría impedir la absorción de magnesio y calcio. Ajusta la fertilización.';
      case 'ph':
        return bajo
            ? 'pH del suelo extremadamente ácido. Esto afecta la disponibilidad de nutrientes esenciales. Considera encalar para subir el pH.'
            : 'pH muy alcalino. Puede limitar la disponibilidad de hierro y fósforo. Agrega materia orgánica o enmiendas ácidas.';
      case 'humedad':
        return bajo
            ? 'Humedad del suelo críticamente baja. Las raíces podrían estar deshidratadas. Riega de inmediato y evalúa el sistema de riego.'
            : 'Exceso de humedad. Puede provocar pudrición de raíces y enfermedades. Asegura un drenaje adecuado.';
      case 'ec':
        return bajo
            ? 'Conductividad eléctrica muy baja. Podría indicar escasez de nutrientes disponibles en el suelo.'
            : 'Conductividad eléctrica elevada. Riesgo de acumulación de sales. Lava el suelo con agua limpia si es necesario.';
      case 'temperatura':
        return bajo
            ? 'Temperatura del suelo demasiado baja. Esto retrasa la germinación y el crecimiento. Considera proteger con acolchado o esperar condiciones más cálidas.'
            : 'Temperatura del suelo muy elevada. Podría causar estrés térmico en las raíces. Aumenta el riego o usa cobertura para reducir el calor.';
      default:
        return 'Valor fuera de rango crítico detectado.';
    }
  }

  static String _mensajeBasico(String param, {required bool bajo}) {
    switch (param) {
      case 'n':
        return bajo
            ? 'Nivel de nitrógeno por debajo del ideal. Aplica fertilizante nitrogenado.'
            : 'Niveles de nitrógeno por encima del óptimo. Puedes reducir la frecuencia de fertilización.';
      case 'p':
        return bajo
            ? 'Fósforo ligeramente bajo. Usa fertilizante fosfatado.'
            : 'Fósforo un poco alto. No se recomienda fertilizar más con este nutriente.';
      case 'k':
        return bajo
            ? 'Potasio algo bajo. Revisa el calendario de fertilización con potasio.'
            : 'Potasio elevado. Reduce o pausa la aplicación por ahora.';
      case 'ph':
        return bajo
            ? 'pH ligeramente ácido. Un encalado suave podría mejorar la disponibilidad de nutrientes.'
            : 'pH por encima del rango ideal. Considera aplicar materiales acidificantes.';
      case 'humedad':
        return bajo
            ? 'Humedad algo baja. Riega moderadamente en las próximas horas.'
            : 'Humedad algo elevada. Observa si hay buen drenaje.';
      case 'ec':
        return bajo
            ? 'Conductividad eléctrica baja. Podría ser señal de fertilidad limitada.'
            : 'EC por encima del nivel ideal. Reduce sales solubles si es necesario.';
      case 'temperatura':
        return bajo
            ? 'Temperatura levemente baja. Podría retrasar el desarrollo.'
            : 'Temperatura algo elevada. Puede afectar el crecimiento si persiste.';
      default:
        return 'Parámetro fuera del rango óptimo.';
    }
  }
}
