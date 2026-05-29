class AppStrings {
  final String lang;
  const AppStrings._(this.lang);

  factory AppStrings.of(String lang) => AppStrings._(lang);

  String _t(String key) => _map[lang]?[key] ?? _map['es']?[key] ?? key;

  // ── Navegación ─────────────────────────────────────────────────
  String get navDashboard    => _t('navDashboard');
  String get navHistorial    => _t('navHistorial');
  String get navSensores     => _t('navSensores');
  String get navSugerencias  => _t('navSugerencias');
  String get navAjustes      => _t('navAjustes');

  // ── Comunes ────────────────────────────────────────────────────
  String get cancelar  => _t('cancelar');
  String get guardar   => _t('guardar');
  String get cerrar    => _t('cerrar');
  String get otro      => _t('otro');
  String get sinNombre => _t('sinNombre');

  // ── Dashboard ──────────────────────────────────────────────────
  String get noHaySensores         => _t('noHaySensores');
  String get ultimaMedicion        => _t('ultimaMedicion');
  String get condicionesAmbientales=> _t('condicionesAmbientales');
  String get cultivoMonitoreado    => _t('cultivoMonitoreado');
  String get cambiar               => _t('cambiar');
  String get sinCultivo            => _t('sinCultivo');
  String get seleccionarCultivo    => _t('seleccionarCultivo');
  String get tempAire              => _t('tempAire');
  String get humedadAire           => _t('humedadAire');

  // ── Etiquetas de parámetros ────────────────────────────────────
  String get tempSuelo     => _t('tempSuelo');
  String get humedadSuelo  => _t('humedadSuelo');
  String get conductividad => _t('conductividad');
  String get nitrogeno     => _t('nitrogeno');
  String get fosforo       => _t('fosforo');
  String get potasio       => _t('potasio');
  String get radiacionSolar=> _t('radiacionSolar');
  String get radiacion     => _t('radiacion');

  String labelPorCampo(String campo, {bool ambiental = false}) {
    switch (campo) {
      case 'humedad':     return ambiental ? humedadAire  : humedadSuelo;
      case 'temperatura': return ambiental ? tempAire     : tempSuelo;
      case 'ph':          return 'pH';
      case 'ec':          return conductividad;
      case 'n':           return nitrogeno;
      case 'p':           return fosforo;
      case 'k':           return potasio;
      case 'radiacion':   return ambiental ? radiacion    : radiacionSolar;
      default:            return campo;
    }
  }

  // ── Historial ──────────────────────────────────────────────────
  String get periodo                => _t('periodo');
  String get rangoSemana            => _t('rangoSemana');
  String get rangoTreinta           => _t('rangoTreinta');
  String get rangoNoventa           => _t('rangoNoventa');
  String get rangoTodo              => _t('rangoTodo');
  String get sinDatosPeriodo        => _t('sinDatosPeriodo');
  String get sinSensoresRegistrados => _t('sinSensoresRegistrados');
  String get sincronizaParaLecturas => _t('sincronizaParaLecturas');
  String get ultimo                 => _t('ultimo');
  String get promedio               => _t('promedio');
  String get min                    => _t('min');
  String get max                    => _t('max');

  // ── Sensores screen ────────────────────────────────────────────
  String get sensoresConectados => _t('sensoresConectados');
  String get sincronizaDesdeAbajo=> _t('sincronizaDesdeAbajo');
  String get nodosDetectados    => _t('nodosDetectados');
  String get noEncontradosNodos => _t('noEncontradosNodos');
  String get asegurateNodos     => _t('asegurateNodos');
  String get puedesConectar     => _t('puedesConectar');
  String get sincronizar        => _t('sincronizar');
  String get liberar            => _t('liberar');
  String get editar             => _t('editar');
  String get noConfigurado      => _t('noConfigurado');
  String get vinculadoDispositivo=> _t('vinculadoDispositivo');
  String get escanear           => _t('escanear');
  String get buscandoRedes      => _t('buscandoRedes');
  String get noNodosEncontrados => _t('noNodosEncontrados');
  String get senalExcelente     => _t('senalExcelente');
  String get senalBuena         => _t('senalBuena');
  String get senalDebil         => _t('senalDebil');
  String get senalMuyDebil      => _t('senalMuyDebil');
  String get liberarNodo        => _t('liberarNodo');
  String get desincronizarSensor=> _t('desincronizarSensor');
  String get configurarSensor   => _t('configurarSensor');
  String get cultivoLabel       => _t('cultivoLabel');
  String get nombreSensor       => _t('nombreSensor');
  String get sensorPrincipal    => _t('sensorPrincipal');
  String get sensor             => _t('sensor');
  String get nombreVacio        => _t('nombreVacio');
  String get nombreExiste       => _t('nombreExiste');
  String get conectandoNodo     => _t('conectandoNodo');
  String get enviandoSolicitud  => _t('enviandoSolicitud');
  String get nodeLiberadoOk     => _t('nodeLiberadoOk');
  String get nodoRechazado      => _t('nodoRechazado');
  String get resetFisicoMensaje => _t('resetFisicoMensaje');
  String get nodoBloqueado      => _t('nodoBloqueado');
  String get reclamarFallo      => _t('reclamarFallo');
  String get reclamarDeNuevo    => _t('reclamarDeNuevo');

  // pasos de sincronización
  String get pasoConectando    => _t('pasoConectando');
  String get pasoVerificando   => _t('pasoVerificando');
  String get pasoListando      => _t('pasoListando');
  String get pasoDescargando   => _t('pasoDescargando');
  String get pasoGuardando     => _t('pasoGuardando');

  // ── Sugerencias ────────────────────────────────────────────────
  String get sugerenciasInfo    => _t('sugerenciasInfo');
  String get sinSugerencias     => _t('sinSugerencias');
  String get sinSugerenciasSub  => _t('sinSugerenciasSub');

  // ── Dashboard onboarding ───────────────────────────────────────
  String get bienvenidoTitulo   => _t('bienvenidoTitulo');
  String get bienvenidoDesc     => _t('bienvenidoDesc');

  // ── Configuración ──────────────────────────────────────────────
  String get apariencia            => _t('apariencia');
  String get modoOscuro            => _t('modoOscuro');
  String get idiomaSeccion         => _t('idiomaSeccion');
  String get idiomaApp             => _t('idiomaApp');
  String get informacion           => _t('informacion');
  String get version               => _t('version');
  String get dispositivosSoportados=> _t('dispositivosSoportados');

  // ── Sensores: permisos WiFi ────────────────────────────────────
  String get permisoUbicacion    => _t('permisoUbicacion');
  String get ubicacionDesactivada=> _t('ubicacionDesactivada');
  String get noSePuedeEscanear   => _t('noSePuedeEscanear');

  // ── Sensores: formato de fecha ─────────────────────────────────
  String get sinLecturas     => _t('sinLecturas');
  String get haceUnMomento   => _t('haceUnMomento');
  String haceMins(int n)     => _t('haceMinsTemplate').replaceAll('{n}', '$n');
  String haceHoras(int n)    => _t('haceHorasTemplate').replaceAll('{n}', '$n');

  // ── Funciones dinámicas ────────────────────────────────────────

  String nodosEncontrados(int n) {
    if (n == 0) return noNodosEncontrados;
    if (n == 1) return _t('unNodoEncontrado');
    return _t('nNodosEncontrados').replaceAll('{n}', '$n');
  }

  String archivosImportados(int n) {
    if (n == 1) return _t('unArchivoImportado');
    return _t('nArchivosImportados').replaceAll('{n}', '$n');
  }

  String sensorN(int n) => '$sensor $n';

  String liberarNodoContenido(String nombre) =>
      _t('liberarNodoContenidoTpl').replaceAll('{nombre}', nombre);

  String desincronizarContenido(String nombre) =>
      _t('desincronizarContenidoTpl').replaceAll('{nombre}', nombre);

  String resetFisicoSnackbar(String nombre) =>
      _t('resetFisicoSnackbarTpl').replaceAll('{nombre}', nombre);

  // ── Traducciones ───────────────────────────────────────────────

  static const Map<String, Map<String, String>> _map = {
    // ════════════════════════════════════════════════════════════
    'es': {
      'navDashboard':    'Dashboard',
      'navHistorial':    'Historial',
      'navSensores':     'Sensores',
      'navSugerencias':  'Sugerencias',
      'navAjustes':      'Ajustes',
      'cancelar':        'Cancelar',
      'guardar':         'Guardar',
      'cerrar':          'Cerrar',
      'otro':            'Otro',
      'sinNombre':       'sin nombre',
      // Dashboard
      'noHaySensores':          'No hay sensores conectados',
      'ultimaMedicion':         'Última medición',
      'condicionesAmbientales': 'Condiciones ambientales',
      'cultivoMonitoreado':     'Cultivo monitoreado',
      'cambiar':                'Cambiar',
      'sinCultivo':             'Sin cultivo',
      'seleccionarCultivo':     'Seleccionar cultivo',
      'tempAire':               'Temp. aire',
      'humedadAire':            'Humedad aire',
      // Params
      'tempSuelo':      'Temp. del suelo',
      'humedadSuelo':   'Humedad suelo',
      'conductividad':  'Conductividad',
      'nitrogeno':      'Nitrógeno',
      'fosforo':        'Fósforo',
      'potasio':        'Potasio',
      'radiacionSolar': 'Radiación solar',
      'radiacion':      'Radiación',
      // Historial
      'periodo':                'Período',
      'rangoSemana':            '7 días',
      'rangoTreinta':           '30 días',
      'rangoNoventa':           '90 días',
      'rangoTodo':              'Todo',
      'sinDatosPeriodo':        'Sin datos en este período',
      'sinSensoresRegistrados': 'Sin sensores registrados',
      'sincronizaParaLecturas': 'Sincroniza con un nodo para acumular lecturas.',
      'ultimo':                 'Último',
      'promedio':               'Promedio',
      'min':                    'Mín',
      'max':                    'Máx',
      // Sensores
      'sensoresConectados':  'Sensores conectados',
      'sincronizaDesdeAbajo':'Sincroniza un nodo desde la sección de abajo.',
      'nodosDetectados':     'Nodos detectados',
      'noEncontradosNodos':  'No se encontraron nodos SoilAir',
      'asegurateNodos':      'Asegúrate de que los nodos estén encendidos y cerca.',
      'puedesConectar':      'Puedes conectarte a cualquier nodo para obtener datos de toda la red.',
      'sincronizar':         'Sincronizar',
      'liberar':             'Liberar',
      'editar':              'Editar',
      'noConfigurado':       'No configurado',
      'vinculadoDispositivo':'Vinculado a este dispositivo',
      'escanear':            'Escanear',
      'buscandoRedes':       'Buscando redes SOILAIR…',
      'noNodosEncontrados':  'No se encontraron nodos',
      'unNodoEncontrado':    '1 nodo encontrado',
      'nNodosEncontrados':   '{n} nodos encontrados',
      'senalExcelente':      'Señal excelente',
      'senalBuena':          'Señal buena',
      'senalDebil':          'Señal débil',
      'senalMuyDebil':       'Señal muy débil',
      'liberarNodo':         'Liberar nodo',
      'desincronizarSensor': 'Desincronizar sensor',
      'configurarSensor':    'Configurar sensor',
      'cultivoLabel':        'Cultivo',
      'nombreSensor':        'Nombre del sensor',
      'sensorPrincipal':     'Sensor principal',
      'sensor':              'Sensor',
      'nombreVacio':         'El nombre no puede estar vacío.',
      'nombreExiste':        'Ese nombre ya existe, elige otro.',
      'conectandoNodo':      'Conectando al nodo…',
      'enviandoSolicitud':   'Enviando solicitud de liberación…',
      'nodeLiberadoOk':      'Nodo liberado correctamente.\nCualquier dispositivo podrá sincronizarlo.',
      'nodoRechazado':       'El nodo rechazó la solicitud.',
      'resetFisicoMensaje':  'Este nodo fue reseteado físicamente.\nLa vinculación anterior fue liberada.\n¿Deseas volver a vincularlo?',
      'nodoBloqueado':       'Este nodo está vinculado a otro dispositivo.\nSolo su propietario puede sincronizarlo.',
      'reclamarFallo':       'No se pudo reclamar: otro dispositivo ya lo vinculó.',
      'reclamarDeNuevo':     'Reclamar de nuevo',
      'pasoConectando':      'Conectando a la red…',
      'pasoVerificando':     'Verificando propiedad…',
      'pasoListando':        'Listando archivos del nodo…',
      'pasoDescargando':     'Descargando mediciones…',
      'pasoGuardando':       'Guardando en base de datos…',
      'unArchivoImportado':  '✓ 1 archivo importado',
      'nArchivosImportados': '✓ {n} archivos importados',
      'permisoUbicacion':    'Activa el permiso de ubicación en Ajustes → Aplicaciones → SoilAir → Permisos',
      'ubicacionDesactivada':'Activa la ubicación del dispositivo para detectar redes WiFi.',
      'noSePuedeEscanear':   'No se puede escanear en este momento.',
      'sinLecturas':         'Sin lecturas',
      'haceUnMomento':       'hace un momento',
      'haceMinsTemplate':    'hace {n} min',
      'haceHorasTemplate':   'hace {n} h',
      'liberarNodoContenidoTpl':    '¿Deseas liberar la propiedad de "{nombre}"?\n\nCualquier dispositivo podrá sincronizarlo después.',
      'desincronizarContenidoTpl':  'El sensor "{nombre}" dejará de mostrarse en Sensores conectados.\n\nSus datos históricos se conservarán.',
      'resetFisicoSnackbarTpl':     'El nodo {nombre} fue reseteado físicamente. Propiedad liberada.',
      // Sugerencias
      'sugerenciasInfo':    'Recomendaciones basadas en las últimas lecturas y los rangos óptimos del cultivo asignado.',
      'sinSugerencias':     'Todo en orden',
      'sinSugerenciasSub':  'Los sensores están dentro de los rangos óptimos del cultivo asignado.',
      // Dashboard onboarding
      'bienvenidoTitulo':   'Bienvenido a SoilAir',
      'bienvenidoDesc':     'Monitorea en tiempo real el suelo de tus cultivos. Conecta tu primer sensor desde la pestaña Sensores.',
      // Ajustes
      'apariencia':             'Apariencia',
      'modoOscuro':             'Modo oscuro',
      'idiomaSeccion':          'Idioma',
      'idiomaApp':              'Idioma de la app',
      'informacion':            'Información',
      'version':                'Versión',
      'dispositivosSoportados': 'Dispositivos soportados',
    },
    // ════════════════════════════════════════════════════════════
    'en': {
      'navDashboard':    'Dashboard',
      'navHistorial':    'History',
      'navSensores':     'Sensors',
      'navSugerencias':  'Suggestions',
      'navAjustes':      'Settings',
      'cancelar':        'Cancel',
      'guardar':         'Save',
      'cerrar':          'Close',
      'otro':            'Other',
      'sinNombre':       'unnamed',
      'noHaySensores':          'No sensors connected',
      'ultimaMedicion':         'Last reading',
      'condicionesAmbientales': 'Ambient conditions',
      'cultivoMonitoreado':     'Monitored crop',
      'cambiar':                'Change',
      'sinCultivo':             'No crop',
      'seleccionarCultivo':     'Select crop',
      'tempAire':               'Air temp.',
      'humedadAire':            'Air humidity',
      'tempSuelo':      'Soil temp.',
      'humedadSuelo':   'Soil humidity',
      'conductividad':  'Conductivity',
      'nitrogeno':      'Nitrogen',
      'fosforo':        'Phosphorus',
      'potasio':        'Potassium',
      'radiacionSolar': 'Solar radiation',
      'radiacion':      'Radiation',
      'periodo':                'Period',
      'rangoSemana':            '7 days',
      'rangoTreinta':           '30 days',
      'rangoNoventa':           '90 days',
      'rangoTodo':              'All',
      'sinDatosPeriodo':        'No data in this period',
      'sinSensoresRegistrados': 'No registered sensors',
      'sincronizaParaLecturas': 'Sync with a node to accumulate readings.',
      'ultimo':                 'Last',
      'promedio':               'Average',
      'min':                    'Min',
      'max':                    'Max',
      'sensoresConectados':  'Connected sensors',
      'sincronizaDesdeAbajo':'Sync a node from the section below.',
      'nodosDetectados':     'Detected nodes',
      'noEncontradosNodos':  'No SoilAir nodes found',
      'asegurateNodos':      'Make sure nodes are powered on and nearby.',
      'puedesConectar':      'You can connect to any node to get data from the whole network.',
      'sincronizar':         'Sync',
      'liberar':             'Release',
      'editar':              'Edit',
      'noConfigurado':       'Not configured',
      'vinculadoDispositivo':'Linked to this device',
      'escanear':            'Scan',
      'buscandoRedes':       'Searching for SOILAIR networks…',
      'noNodosEncontrados':  'No nodes found',
      'unNodoEncontrado':    '1 node found',
      'nNodosEncontrados':   '{n} nodes found',
      'senalExcelente':      'Excellent signal',
      'senalBuena':          'Good signal',
      'senalDebil':          'Weak signal',
      'senalMuyDebil':       'Very weak signal',
      'liberarNodo':         'Release node',
      'desincronizarSensor': 'Desync sensor',
      'configurarSensor':    'Configure sensor',
      'cultivoLabel':        'Crop',
      'nombreSensor':        'Sensor name',
      'sensorPrincipal':     'Main sensor',
      'sensor':              'Sensor',
      'nombreVacio':         'Name cannot be empty.',
      'nombreExiste':        'That name already exists, choose another.',
      'conectandoNodo':      'Connecting to node…',
      'enviandoSolicitud':   'Sending release request…',
      'nodeLiberadoOk':      'Node released successfully.\nAny device will be able to sync it.',
      'nodoRechazado':       'The node rejected the request.',
      'resetFisicoMensaje':  'This node was physically reset.\nThe previous link was released.\nDo you want to re-link it?',
      'nodoBloqueado':       'This node is linked to another device.\nOnly its owner can sync it.',
      'reclamarFallo':       'Could not claim: another device already linked it.',
      'reclamarDeNuevo':     'Re-claim',
      'pasoConectando':      'Connecting to network…',
      'pasoVerificando':     'Verifying ownership…',
      'pasoListando':        'Listing node files…',
      'pasoDescargando':     'Downloading readings…',
      'pasoGuardando':       'Saving to database…',
      'unArchivoImportado':  '✓ 1 file imported',
      'nArchivosImportados': '✓ {n} files imported',
      'permisoUbicacion':    'Enable location permission in Settings → Apps → SoilAir → Permissions',
      'ubicacionDesactivada':'Enable device location to detect WiFi networks.',
      'noSePuedeEscanear':   'Cannot scan at this moment.',
      'sinLecturas':         'No readings',
      'haceUnMomento':       'just now',
      'haceMinsTemplate':    '{n} min ago',
      'haceHorasTemplate':   '{n} h ago',
      'liberarNodoContenidoTpl':   'Release ownership of "{nombre}"?\n\nAny device will be able to sync it afterwards.',
      'desincronizarContenidoTpl': 'Sensor "{nombre}" will no longer appear in Connected sensors.\n\nHistorical data will be preserved.',
      'resetFisicoSnackbarTpl':    'Node {nombre} was physically reset. Ownership released.',
      // Suggestions
      'sugerenciasInfo':    'Recommendations based on the latest readings and the optimal ranges of the assigned crop.',
      'sinSugerencias':     'All clear',
      'sinSugerenciasSub':  'Your sensors are within the optimal ranges for the assigned crop.',
      // Dashboard onboarding
      'bienvenidoTitulo':   'Welcome to SoilAir',
      'bienvenidoDesc':     'Monitor your crops soil conditions in real time. Connect your first sensor from the Sensors tab.',
      'apariencia':             'Appearance',
      'modoOscuro':             'Dark mode',
      'idiomaSeccion':          'Language',
      'idiomaApp':              'App language',
      'informacion':            'Information',
      'version':                'Version',
      'dispositivosSoportados': 'Supported devices',
    },
    // ════════════════════════════════════════════════════════════
    'fr': {
      'navDashboard':    'Tableau de bord',
      'navHistorial':    'Historique',
      'navSensores':     'Capteurs',
      'navSugerencias':  'Suggestions',
      'navAjustes':      'Paramètres',
      'cancelar':        'Annuler',
      'guardar':         'Enregistrer',
      'cerrar':          'Fermer',
      'otro':            'Autre',
      'sinNombre':       'sans nom',
      'noHaySensores':          'Aucun capteur connecté',
      'ultimaMedicion':         'Dernière mesure',
      'condicionesAmbientales': 'Conditions ambiantes',
      'cultivoMonitoreado':     'Culture suivie',
      'cambiar':                'Modifier',
      'sinCultivo':             'Sans culture',
      'seleccionarCultivo':     'Sélectionner culture',
      'tempAire':               'Temp. air',
      'humedadAire':            'Humidité air',
      'tempSuelo':      'Temp. sol',
      'humedadSuelo':   'Humidité sol',
      'conductividad':  'Conductivité',
      'nitrogeno':      'Azote',
      'fosforo':        'Phosphore',
      'potasio':        'Potassium',
      'radiacionSolar': 'Radiation solaire',
      'radiacion':      'Radiation',
      'periodo':                'Période',
      'rangoSemana':            '7 jours',
      'rangoTreinta':           '30 jours',
      'rangoNoventa':           '90 jours',
      'rangoTodo':              'Tout',
      'sinDatosPeriodo':        'Aucune donnée pour cette période',
      'sinSensoresRegistrados': 'Aucun capteur enregistré',
      'sincronizaParaLecturas': 'Synchronisez avec un nœud pour accumuler des lectures.',
      'ultimo':                 'Dernier',
      'promedio':               'Moyenne',
      'min':                    'Min',
      'max':                    'Max',
      'sensoresConectados':  'Capteurs connectés',
      'sincronizaDesdeAbajo':'Synchronisez un nœud depuis la section ci-dessous.',
      'nodosDetectados':     'Nœuds détectés',
      'noEncontradosNodos':  'Aucun nœud SoilAir trouvé',
      'asegurateNodos':      'Assurez-vous que les nœuds sont allumés et à proximité.',
      'puedesConectar':      "Vous pouvez vous connecter à n'importe quel nœud pour obtenir des données de tout le réseau.",
      'sincronizar':         'Synchroniser',
      'liberar':             'Libérer',
      'editar':              'Modifier',
      'noConfigurado':       'Non configuré',
      'vinculadoDispositivo':'Lié à cet appareil',
      'escanear':            'Scanner',
      'buscandoRedes':       'Recherche de réseaux SOILAIR…',
      'noNodosEncontrados':  'Aucun nœud trouvé',
      'unNodoEncontrado':    '1 nœud trouvé',
      'nNodosEncontrados':   '{n} nœuds trouvés',
      'senalExcelente':      'Signal excellent',
      'senalBuena':          'Bon signal',
      'senalDebil':          'Signal faible',
      'senalMuyDebil':       'Signal très faible',
      'liberarNodo':         'Libérer nœud',
      'desincronizarSensor': 'Désynchroniser capteur',
      'configurarSensor':    'Configurer capteur',
      'cultivoLabel':        'Culture',
      'nombreSensor':        'Nom du capteur',
      'sensorPrincipal':     'Capteur principal',
      'sensor':              'Capteur',
      'nombreVacio':         'Le nom ne peut pas être vide.',
      'nombreExiste':        'Ce nom existe déjà, choisissez-en un autre.',
      'conectandoNodo':      'Connexion au nœud…',
      'enviandoSolicitud':   'Envoi de la demande de libération…',
      'nodeLiberadoOk':      'Nœud libéré avec succès.\nN\'importe quel appareil pourra le synchroniser.',
      'nodoRechazado':       'Le nœud a rejeté la demande.',
      'resetFisicoMensaje':  'Ce nœud a été réinitialisé physiquement.\nLe lien précédent a été supprimé.\nVoulez-vous le lier à nouveau ?',
      'nodoBloqueado':       "Ce nœud est lié à un autre appareil.\nSeul son propriétaire peut le synchroniser.",
      'reclamarFallo':       'Impossible de revendiquer : un autre appareil l\'a déjà lié.',
      'reclamarDeNuevo':     'Lier à nouveau',
      'pasoConectando':      'Connexion au réseau…',
      'pasoVerificando':     'Vérification de la propriété…',
      'pasoListando':        'Liste des fichiers du nœud…',
      'pasoDescargando':     'Téléchargement des mesures…',
      'pasoGuardando':       'Enregistrement en base de données…',
      'unArchivoImportado':  '✓ 1 fichier importé',
      'nArchivosImportados': '✓ {n} fichiers importés',
      'permisoUbicacion':    'Activez la permission de localisation dans Paramètres → Applications → SoilAir → Autorisations',
      'ubicacionDesactivada':'Activez la localisation de l\'appareil pour détecter les réseaux WiFi.',
      'noSePuedeEscanear':   'Impossible de scanner pour le moment.',
      'sinLecturas':         'Aucune lecture',
      'haceUnMomento':       'à l\'instant',
      'haceMinsTemplate':    'il y a {n} min',
      'haceHorasTemplate':   'il y a {n} h',
      'liberarNodoContenidoTpl':   'Libérer la propriété de « {nombre} » ?\n\nN\'importe quel appareil pourra le synchroniser ensuite.',
      'desincronizarContenidoTpl': 'Le capteur « {nombre} » ne s\'affichera plus dans Capteurs connectés.\n\nLes données historiques seront conservées.',
      'resetFisicoSnackbarTpl':    'Le nœud {nombre} a été réinitialisé physiquement. Propriété libérée.',
      // Suggestions
      'sugerenciasInfo':    "Recommandations basées sur les dernières lectures et les plages optimales de la culture assignée.",
      'sinSugerencias':     'Tout va bien',
      'sinSugerenciasSub':  "Vos capteurs sont dans les plages optimales de la culture assignée.",
      // Dashboard onboarding
      'bienvenidoTitulo':   'Bienvenue sur SoilAir',
      'bienvenidoDesc':     "Surveillez en temps réel les conditions du sol de vos cultures. Connectez votre premier capteur depuis l'onglet Capteurs.",
      'apariencia':             'Apparence',
      'modoOscuro':             'Mode sombre',
      'idiomaSeccion':          'Langue',
      'idiomaApp':              'Langue de l\'application',
      'informacion':            'Informations',
      'version':                'Version',
      'dispositivosSoportados': 'Appareils pris en charge',
    },
  };
}
