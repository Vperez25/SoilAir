import 'package:flutter/material.dart';
import 'package:soilair/services/database.dart';
import 'package:soilair/theme/app_light_theme.dart';

class AdminSensorsBody extends StatefulWidget {
  const AdminSensorsBody({super.key});

  @override
  State<AdminSensorsBody> createState() => _AdminSensorsBodyState();
}

class _AdminSensorsBodyState extends State<AdminSensorsBody> {
  final _db = DatabaseHelper();

  List<Map<String, dynamic>> _cultivos = [];
  Map<String, dynamic>? _configuracion;
  List<Map<String, dynamic>> _sensores = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final cultivos = await _db.getCultivos();
    final config = await _db.getConfiguracion();
    final sensores = await _db.getSensoresAdmin();
    setState(() {
      _cultivos = cultivos;
      _configuracion = config;
      _sensores = sensores;
      _cargando = false;
    });
  }

  String get _cultivoNombre {
    if (_configuracion == null) return 'Sin configurar';
    final cultivoId = _configuracion!['cultivo_id'];
    if (cultivoId == null) {
      return _configuracion!['cultivo_nombre'] as String? ?? 'Otro';
    }
    final c = _cultivos.firstWhere(
      (c) => c['id'] == cultivoId,
      orElse: () => <String, dynamic>{},
    );
    return c['nombre'] as String? ?? 'Sin configurar';
  }

  Future<void> _cambiarCultivo() async {
    final cultivoActualId = _configuracion?['cultivo_id'] as int?;
    final esOtro = _configuracion != null && cultivoActualId == null;

    await showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Seleccionar cultivo'),
        children: [
          ..._cultivos.map((c) {
            final seleccionado = c['id'] == cultivoActualId;
            return SimpleDialogOption(
              onPressed: () async {
                await _db.setConfiguracion(cultivoId: c['id'] as int, cultivoNombre: null);
                if (ctx.mounted) Navigator.pop(ctx);
                await _cargar();
              },
              child: Row(
                children: [
                  Icon(
                    seleccionado ? Icons.check_circle : Icons.circle_outlined,
                    color: seleccionado ? AppLightTheme.botonPrincipal : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(c['nombre'] as String),
                ],
              ),
            );
          }),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () async {
              await _db.setConfiguracion(cultivoId: null, cultivoNombre: 'Otro');
              if (ctx.mounted) Navigator.pop(ctx);
              await _cargar();
            },
            child: Row(
              children: [
                Icon(
                  esOtro ? Icons.check_circle : Icons.circle_outlined,
                  color: esOtro ? AppLightTheme.botonPrincipal : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 10),
                const Text('Otro'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFecha(int? timestamp) {
    if (timestamp == null) return 'Sin lecturas';
    final fecha = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final ahora = DateTime.now();
    final diff = ahora.difference(fecha);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());


    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tarjeta de cultivo ──────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppLightTheme.divisor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cultivo configurado',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppLightTheme.botonPrincipal.withValues(alpha: 0.1),
                        child: const Icon(Icons.eco, color: AppLightTheme.botonPrincipal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _cultivoNombre,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      FilledButton(
                        onPressed: _cambiarCultivo,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppLightTheme.botonPrincipal,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Cambiar'),
                      ),
                    ],
                  ),
                  if (_configuracion == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Selecciona un cultivo para ver rangos recomendados en el dashboard.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Sensores detectados ─────────────────────────────
          const Text(
            'Sensores detectados',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          if (_sensores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.sensors_off, size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay módulos asociados',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Asocia un módulo desde la pestaña "Módulos".',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Módulos asociados', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            ..._sensores.map((s) => _tarjetaSensor(
                  id: s['id'] as String,
                  nombre: s['nombre'] as String?,
                  cultivoNombre: s['cultivo_nombre'] as String?,
                  timestamp: s['ultimo_timestamp'] as int?,
                )),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaSensor({
    required String id,
    required String? nombre,
    required String? cultivoNombre,
    required int? timestamp,
  }) {
    final configurado = nombre != null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: configurado ? AppLightTheme.divisor : Colors.orange.shade200,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: configurado
              ? AppLightTheme.botonPrincipal.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: Icon(
            configurado ? Icons.sensors : Icons.sensors_off,
            color: configurado ? AppLightTheme.botonPrincipal : Colors.orange.shade700,
            size: 20,
          ),
        ),
        title: Text(
          nombre ?? 'Sin configurar',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: configurado ? null : Colors.orange,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cultivoNombre != null)
              Text(cultivoNombre, style: const TextStyle(fontSize: 12)),
            Text(
              _formatFecha(timestamp),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        isThreeLine: cultivoNombre != null,
        trailing: configurado
            ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
            : Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400, size: 18),
      ),
    );
  }
}
