import 'package:flutter/foundation.dart';

class DataEvents {
  DataEvents._();
  static final DataEvents instance = DataEvents._();

  /// Sube +1 cada vez que entran datos nuevos a la BD.
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  void notificarDatosNuevos() => version.value++;
}
