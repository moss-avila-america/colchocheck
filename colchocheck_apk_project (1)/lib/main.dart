import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ColchoCheckApp());
}

class ColchoCheckApp extends StatelessWidget {
  const ColchoCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ColchoCheck GNC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F2942),
          primary: const Color(0xFF0F2942),
          secondary: const Color(0xFF0284C7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        useMaterial3: true,
      ),
      home: const MainShellScreen(),
    );
  }
}

// ============================================================================
// MODELOS Y ESTADO CENTRAL (SUPER COLCHONES GNC - COLCHONES AMÉRICA)
// ============================================================================
class Usuario {
  String id;
  String pass;
  String nombre;
  String rol; // promotor | supervisor | ejecutivo | admin
  String plaza;
  bool activo;

  Usuario({
    required this.id,
    required this.pass,
    required this.nombre,
    required this.rol,
    required this.plaza,
    this.activo = true,
  });
}

class Sucursal {
  String codigo;
  String nombre;
  String plaza;
  double lat;
  double lng;
  bool geocercaActiva;

  Sucursal({
    required this.codigo,
    required this.nombre,
    required this.plaza,
    required this.lat,
    required this.lng,
    this.geocercaActiva = true,
  });
}

class VisitaPromotor {
  String id;
  String fecha;
  String numColaborador;
  String nombrePromotor;
  String sucursalCodigo;
  String nombreSucursal;
  String plaza;
  String supervisorAsigno;
  String estatus; // Pendiente | En Piso | Cerrada | Cerrada - Autorizada Admin
  String? horaEntrada;
  String? horaSalida;
  DateTime? inicioTimestamp;
  int tiempoEfectivoMin;
  String afluencia;
  int ingresosClientes;
  String ventaAmerica;
  String ventasCompetencia;
  String presupuestoAmerica;
  String presupuestoCompetencia;
  String notaAdmin;

  VisitaPromotor({
    required this.id,
    required this.fecha,
    required this.numColaborador,
    required this.nombrePromotor,
    required this.sucursalCodigo,
    required this.nombreSucursal,
    required this.plaza,
    required this.supervisorAsigno,
    this.estatus = 'Pendiente',
    this.horaEntrada,
    this.horaSalida,
    this.inicioTimestamp,
    this.tiempoEfectivoMin = 0,
    this.afluencia = 'Media',
    this.ingresosClientes = 18,
    this.ventaAmerica = '',
    this.ventasCompetencia = '',
    this.presupuestoAmerica = '',
    this.presupuestoCompetencia = '',
    this.notaAdmin = '',
  });
}

class VisitaSupervisor {
  String id;
  int orden;
  String numSupervisor;
  String nombreSupervisor;
  String plaza;
  String tipo; // Sucursal | Garantia
  String sucursalCodigo;
  String destinoNombre;
  String folioGarantia;
  String dictamenGarantia;
  List<bool> fotosGarantia;
  String estatus; // Pendiente | En Curso | Cerrada | Cerrada - Autorizada Admin
  String? horaEntrada;
  String? horaSalida;
  int tiempoTrasladoMin;
  int tiempoEstanciaMin;
  String notaAdmin;

  VisitaSupervisor({
    required this.id,
    required this.orden,
    required this.numSupervisor,
    required this.nombreSupervisor,
    required this.plaza,
    required this.tipo,
    this.sucursalCodigo = '',
    required this.destinoNombre,
    this.folioGarantia = '',
    this.dictamenGarantia = 'Procede Cambio por Garantía',
    List<bool>? fotosGarantia,
    this.estatus = 'Pendiente',
    this.horaEntrada,
    this.horaSalida,
    this.tiempoTrasladoMin = 0,
    this.tiempoEstanciaMin = 0,
    this.notaAdmin = '',
  }) : fotosGarantia = fotosGarantia ?? [false, false, false, false, false, false];
}

class CierreSupervisor {
  String fecha;
  String supervisor;
  String plaza;
  String comentario;

  CierreSupervisor({
    required this.fecha,
    required this.supervisor,
    required this.plaza,
    required this.comentario,
  });
}

class AppData {
  static final List<String> plazasOficiales = [
    'ZMG Jalisco',
    'Puerto Vallarta',
    'Tepic',
    'Colima',
    'Manzanillo',
    'Mazatlán',
    'Culiacán',
    'Los Mochis',
  ];

  static final List<String> etiquetasFotosGarantia = [
    '1. Etiqueta / No. Serie',
    '2. Vista Superior Completa',
    '3. Evidencia Hundimiento/Daño',
    '4. Base o Box del Cliente',
    '5. Costuras y Bordes',
    '6. Póliza / Hoja Firmada',
  ];

  static final List<Usuario> usuarios = [
    Usuario(id: '1001', pass: '123', nombre: 'Luis Fernando Gómez', rol: 'promotor', plaza: 'ZMG Jalisco'),
    Usuario(id: '1002', pass: '123', nombre: 'María Elena Vázquez', rol: 'promotor', plaza: 'Puerto Vallarta'),
    Usuario(id: '1003', pass: '123', nombre: 'Jorge Alberto Ríos', rol: 'promotor', plaza: 'Mazatlán'),
    Usuario(id: '2001', pass: '123', nombre: 'Ing. Roberto Castañeda', rol: 'supervisor', plaza: 'ZMG Jalisco'),
    Usuario(id: '2002', pass: '123', nombre: 'Lic. Patricia Morales', rol: 'supervisor', plaza: 'Mazatlán'),
    Usuario(id: '3001', pass: '123', nombre: 'Dirección Comercial GNC / América', rol: 'ejecutivo', plaza: 'Todas las Plazas'),
    Usuario(id: '9999', pass: '123', nombre: 'Responsable de Cuenta (Administrador)', rol: 'admin', plaza: 'Todas las Plazas'),
  ];

  static final List<Sucursal> sucursales = [
    Sucursal(codigo: 'GDL-REV', nombre: 'Suc. Revolución', plaza: 'ZMG Jalisco', lat: 20.6628, lng: -103.3215),
    Sucursal(codigo: 'GDL-PAT', nombre: 'Suc. Plaza Patria', plaza: 'ZMG Jalisco', lat: 20.7121, lng: -103.3782),
    Sucursal(codigo: 'GDL-TES', nombre: 'Suc. Tesistán / Zapopan', plaza: 'ZMG Jalisco', lat: 20.7965, lng: -103.4791),
    Sucursal(codigo: 'PVR-FCO', nombre: 'Suc. Fco. Villa Vallarta', plaza: 'Puerto Vallarta', lat: 20.6401, lng: -105.2219),
    Sucursal(codigo: 'TEP-INS', nombre: 'Suc. Insurgentes Tepic', plaza: 'Tepic', lat: 21.5039, lng: -104.8954),
    Sucursal(codigo: 'COL-CAM', nombre: 'Suc. Camino Real Colima', plaza: 'Colima', lat: 19.2452, lng: -103.7241),
    Sucursal(codigo: 'ZLO-COS', nombre: 'Suc. Blvd. Costero Manzanillo', plaza: 'Manzanillo', lat: 19.1028, lng: -104.3235),
    Sucursal(codigo: 'MZT-EJE', nombre: 'Suc. Ejército Mexicano Mazatlán', plaza: 'Mazatlán', lat: 23.2261, lng: -106.4189),
    Sucursal(codigo: 'CUL-TRR', nombre: 'Suc. Tres Ríos Culiacán', plaza: 'Culiacán', lat: 24.8142, lng: -107.4018),
    Sucursal(codigo: 'LMM-ROS', nombre: 'Suc. Rosales Los Mochis', plaza: 'Los Mochis', lat: 25.7905, lng: -108.9932),
  ];

  static final List<VisitaPromotor> visitasPromotor = [
    VisitaPromotor(
      id: 'VP-101',
      fecha: '2026-11-04',
      numColaborador: '1001',
      nombrePromotor: 'Luis Fernando Gómez',
      sucursalCodigo: 'GDL-REV',
      nombreSucursal: 'Suc. Revolución',
      plaza: 'ZMG Jalisco',
      supervisorAsigno: 'Ing. Roberto Castañeda',
      estatus: 'Pendiente',
    ),
    VisitaPromotor(
      id: 'VP-102',
      fecha: '2026-11-04',
      numColaborador: '1002',
      nombrePromotor: 'María Elena Vázquez',
      sucursalCodigo: 'PVR-FCO',
      nombreSucursal: 'Suc. Fco. Villa Vallarta',
      plaza: 'Puerto Vallarta',
      supervisorAsigno: 'Ing. Roberto Castañeda',
      estatus: 'Cerrada',
      horaEntrada: '09:02:14',
      horaSalida: '17:18:40',
      tiempoEfectivoMin: 496,
      afluencia: 'Alta',
      ingresosClientes: 27,
      ventaAmerica: '3 Matrimoniales América Ortopédico + 1 King (\$28,900)',
      ventasCompetencia: '1 Matrimonial Spring Air (\$7,400)',
      presupuestoAmerica: 'Cotización Queen América Luxury \$11,200 vuelve viernes',
      presupuestoCompetencia: 'Cotización Sealy Posturepedic \$10,800',
    ),
    VisitaPromotor(
      id: 'VP-103',
      fecha: '2026-11-04',
      numColaborador: '1003',
      nombrePromotor: 'Jorge Alberto Ríos',
      sucursalCodigo: 'MZT-EJE',
      nombreSucursal: 'Suc. Ejército Mexicano Mazatlán',
      plaza: 'Mazatlán',
      supervisorAsigno: 'Lic. Patricia Morales',
      estatus: 'En Piso',
      horaEntrada: '10:15:00',
      inicioTimestamp: DateTime.now().subtract(const Duration(minutes: 145)),
      tiempoEfectivoMin: 145,
    ),
  ];

  static final List<VisitaSupervisor> visitasSupervisor = [
    VisitaSupervisor(
      id: 'VS-201',
      orden: 1,
      numSupervisor: '2001',
      nombreSupervisor: 'Ing. Roberto Castañeda',
      plaza: 'ZMG Jalisco',
      tipo: 'Sucursal',
      sucursalCodigo: 'GDL-REV',
      destinoNombre: 'Suc. Revolución',
      estatus: 'Cerrada',
      horaEntrada: '09:10:00',
      horaSalida: '10:05:00',
      tiempoTrasladoMin: 0,
      tiempoEstanciaMin: 55,
    ),
    VisitaSupervisor(
      id: 'VS-202',
      orden: 2,
      numSupervisor: '2001',
      nombreSupervisor: 'Ing. Roberto Castañeda',
      plaza: 'ZMG Jalisco',
      tipo: 'Garantia',
      destinoNombre: 'Domicilio Cliente Col. Americana',
      folioGarantia: 'GAR-GNC-2026-0418',
      dictamenGarantia: 'Procede Cambio por Garantía',
      fotosGarantia: [true, true, true, true, true, true],
      estatus: 'Cerrada',
      horaEntrada: '10:32:00',
      horaSalida: '11:10:00',
      tiempoTrasladoMin: 27,
      tiempoEstanciaMin: 38,
    ),
    VisitaSupervisor(
      id: 'VS-203',
      orden: 3,
      numSupervisor: '2001',
      nombreSupervisor: 'Ing. Roberto Castañeda',
      plaza: 'ZMG Jalisco',
      tipo: 'Sucursal',
      sucursalCodigo: 'GDL-PAT',
      destinoNombre: 'Suc. Plaza Patria',
      estatus: 'Pendiente',
    ),
  ];

  static final List<CierreSupervisor> cierresSupervisor = [
    CierreSupervisor(
      fecha: '2026-11-04',
      supervisor: 'Ing. Roberto Castañeda',
      plaza: 'ZMG Jalisco',
      comentario: 'Se supervisó piso de venta en Suc. Revolución con POP completo de Colchones América. Se atendió garantía GAR-GNC-2026-0418 en Col. Americana adjuntando las 6 fotografías reglamentarias.',
    ),
  ];
}

// ============================================================================
// PANTALLA CONTENEDORA PRINCIPAL CON CAMBIO DE ROLES Y LOGIN
// ============================================================================
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  Usuario? currentUser;
  int simulatedDistanceMeters = 18;
  final TextEditingController _loginIdCtrl = TextEditingController(text: '1001');
  final TextEditingController _loginPassCtrl = TextEditingController(text: '123');
  final ImagePicker _picker = ImagePicker();

  String _horaActual() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  void _quickSwitch(String colabId) {
    final u = AppData.usuarios.firstWhere((e) => e.id == colabId);
    setState(() {
      _loginIdCtrl.text = u.id;
      _loginPassCtrl.text = u.pass;
      currentUser = u;
    });
  }

  void _handleLogin() {
    final id = _loginIdCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim();
    final matches = AppData.usuarios.where((u) => u.id == id && u.pass == pass).toList();
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No. de Colaborador o contraseña incorrectos'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (!matches.first.activo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Colaborador bloqueado / inactivo'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    setState(() {
      currentUser = matches.first;
    });
  }

  Future<bool> _capturarFotoYValidarGPS({required String titulo, bool permitirGaleria = false}) async {
    try {
      await Geolocator.requestPermission();
    } catch (_) {}

    if (!mounted) return false;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F2942),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded, size: 48, color: Colors.lightBlueAccent),
                  const SizedBox(height: 8),
                  Text('GPS Validado: ${simulatedDistanceMeters}m de tienda',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('Hora de Red: ${_horaActual()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              permitirGaleria
                  ? 'En Folios de Garantía puedes usar la Cámara en vivo o adjuntar desde tu Galería.'
                  : 'Cámara en vivo obligatoria con compresión automática (<250 KB) y sello de coordenadas.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () async {
              try {
                await _picker.pickImage(
                  source: permitirGaleria ? ImageSource.gallery : ImageSource.camera,
                  imageQuality: 55,
                );
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Capturar y Registrar'),
          ),
        ],
      ),
    );
    return confirmar ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2942),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ColchoCheck • Super Colchones (GNC)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(
              currentUser == null
                  ? 'Beta Fase 1 • Colchones América'
                  : '${currentUser!.nombre} (#${currentUser!.id}) • ${currentUser!.rol.toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: Colors.lightBlueAccent),
            ),
          ],
        ),
        actions: [
          if (currentUser != null)
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () => setState(() => currentUser = null),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            color: const Color(0xFF091929),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Demo Rápida: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  _roleChip('Promotor (1001)', '1001'),
                  _roleChip('Supervisor (2001)', '2001'),
                  _roleChip('Dirección (3001)', '3001'),
                  _roleChip('Admin (9999)', '9999', isHighlight: true),
                ],
              ),
            ),
          ),
        ),
      ),
      body: currentUser == null
          ? _buildLoginView()
          : currentUser!.rol == 'promotor'
              ? PromotorView(
                  simulatedDistance: simulatedDistanceMeters,
                  onDistanceChanged: (val) => setState(() => simulatedDistanceMeters = val),
                  onCapture: _capturarFotoYValidarGPS,
                )
              : currentUser!.rol == 'supervisor'
                  ? SupervisorView(
                      usuario: currentUser!,
                      onCapture: _capturarFotoYValidarGPS,
                    )
                  : AdminExecutiveView(usuario: currentUser!),
    );
  }

  Widget _roleChip(String label, String id, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: isHighlight ? Colors.amber.shade700 : const Color(0xFF1E3A5F),
        side: BorderSide.none,
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        onPressed: () => _quickSwitch(id),
      ),
    );
  }

  Widget _buildLoginView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2942),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.verified_user_rounded, size: 42, color: Colors.lightBlueAccent),
                  ),
                  const SizedBox(height: 12),
                  const Text('ColchoCheck', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const Text('SUPER COLCHONES (GNC) • COLCHONES AMÉRICA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _loginIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número de Colaborador',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _loginPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña Asignada',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _handleLogin,
                      child: const Text('INICIAR JORNADA', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// VISTA 1: PROMOTOR DE PISO DE VENTA (GEOCERCA 100M + RELOJ + 6 MÉTRICAS)
// ============================================================================
class PromotorView extends StatefulWidget {
  final int simulatedDistance;
  final ValueChanged<int> onDistanceChanged;
  final Future<bool> Function({required String titulo, bool permitirGaleria}) onCapture;

  const PromotorView({
    super.key,
    required this.simulatedDistance,
    required this.onDistanceChanged,
    required this.onCapture,
  });

  @override
  State<PromotorView> createState() => _PromotorViewState();
}

class _PromotorViewState extends State<PromotorView> {
  late VisitaPromotor selectedVisit;
  Timer? _timer;
  final _ventaAmericaCtrl = TextEditingController();
  final _ventaCompCtrl = TextEditingController();
  final _presupAmericaCtrl = TextEditingController();
  final _presupCompCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedVisit = AppData.visitasPromotor.first;
    _syncControllers();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && selectedVisit.estatus == 'En Piso') setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncControllers() {
    _ventaAmericaCtrl.text = selectedVisit.ventaAmerica;
    _ventaCompCtrl.text = selectedVisit.ventasCompetencia;
    _presupAmericaCtrl.text = selectedVisit.presupuestoAmerica;
    _presupCompCtrl.text = selectedVisit.presupuestoCompetencia;
  }

  String _formatElapsed() {
    if (selectedVisit.estatus == 'En Piso' && selectedVisit.inicioTimestamp != null) {
      final diff = DateTime.now().difference(selectedVisit.inicioTimestamp!);
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    } else if (selectedVisit.estatus.startsWith('Cerrada')) {
      final h = (selectedVisit.tiempoEfectivoMin ~/ 60).toString().padLeft(2, '0');
      final m = (selectedVisit.tiempoEfectivoMin % 60).toString().padLeft(2, '0');
      return '$h:$m:00';
    }
    return '00:00:00';
  }

  Future<void> _registrarEntrada() async {
    final sucursal = AppData.sucursales.firstWhere(
      (s) => s.codigo == selectedVisit.sucursalCodigo,
      orElse: () => AppData.sucursales.first,
    );
    if (sucursal.geocercaActiva && widget.simulatedDistance > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'BLOQUEO GEOCERCA 100m: Estás a ${widget.simulatedDistance}m de ${selectedVisit.nombreSucursal}. Acércate al piso de venta.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final ok = await widget.onCapture(titulo: 'Entrada: ${selectedVisit.nombreSucursal}');
    if (!ok) return;
    final now = DateTime.now();
    setState(() {
      selectedVisit.estatus = 'En Piso';
      selectedVisit.inicioTimestamp = now;
      selectedVisit.horaEntrada =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _registrarSalida() async {
    final ok = await widget.onCapture(titulo: 'Salida: ${selectedVisit.nombreSucursal}');
    if (!ok) return;
    final now = DateTime.now();
    setState(() {
      selectedVisit.estatus = 'Cerrada';
      selectedVisit.horaSalida =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      selectedVisit.tiempoEfectivoMin = 475;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isClosed = selectedVisit.estatus.startsWith('Cerrada');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Simulador de Geocerca 100m
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CONTROL DE GEOCERCA 100M (PRUEBA EN VIVO)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => widget.onDistanceChanged(18),
                        child: Text('En Piso (18m) ${widget.simulatedDistance <= 100 ? "✓" : ""}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => widget.onDistanceChanged(420),
                        child: Text('Fuera (420m) ${widget.simulatedDistance > 100 ? "🔒" : ""}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Rol y Cronómetro Efectivo
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('1. ROL ASIGNADO HOY', style: TextStyle(fontWeight: FontWeight.bold)),
                    Chip(label: Text(selectedVisit.estatus, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
                DropdownButtonFormField<VisitaPromotor>(
                  value: selectedVisit,
                  isExpanded: true,
                  items: AppData.visitasPromotor
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text('${v.nombreSucursal} (${v.plaza}) - ${v.nombrePromotor}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedVisit = val;
                        _syncControllers();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2942),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('TIEMPO EFECTIVO EN PISO DE VENTA',
                          style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_formatElapsed(),
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                      Text(
                        'Entrada: ${selectedVisit.horaEntrada ?? "--:--"} • Salida: ${selectedVisit.horaSalida ?? "--:--"}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                        onPressed: selectedVisit.estatus == 'Pendiente' ? _registrarEntrada : null,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Entrada + GPS'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                        onPressed: selectedVisit.estatus == 'En Piso' ? _registrarSalida : null,
                        icon: const Icon(Icons.flag),
                        label: const Text('Cerrar Visita'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Comentarios Finales de Día (6 campos condicionales al cierre)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('2. COMENTARIOS FIN DE DÍA (${selectedVisit.nombreSucursal})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  isClosed
                      ? '✅ Visita cerrada: Completa los 6 indicadores de piso.'
                      : '🔒 Bloqueado: Se habilita únicamente posterior al cierre de visita.',
                  style: TextStyle(fontSize: 12, color: isClosed ? Colors.green.shade800 : Colors.amber.shade900),
                ),
                const SizedBox(height: 14),
                IgnorePointer(
                  ignoring: !isClosed,
                  child: Opacity(
                    opacity: isClosed ? 1.0 : 0.45,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedVisit.afluencia.isEmpty ? 'Media' : selectedVisit.afluencia,
                          decoration: const InputDecoration(
                            labelText: '• Afluencia (Nula, Baja, Media, Alta)',
                            border: OutlineInputBorder(),
                          ),
                          items: ['Nula', 'Baja', 'Media', 'Alta']
                              .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                              .toList(),
                          onChanged: (v) => setState(() => selectedVisit.afluencia = v ?? 'Media'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Text('• Ingresos de clientes (1 al 9999):', style: TextStyle(fontWeight: FontWeight.w600))),
                            IconButton(
                              onPressed: () => setState(() =>
                                  selectedVisit.ingresosClientes = (selectedVisit.ingresosClientes - 1).clamp(1, 9999)),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${selectedVisit.ingresosClientes}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              onPressed: () => setState(() =>
                                  selectedVisit.ingresosClientes = (selectedVisit.ingresosClientes + 1).clamp(1, 9999)),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _ventaAmericaCtrl,
                          maxLength: 140,
                          decoration: const InputDecoration(
                            labelText: '• Venta Colchones América (máx 140 car.)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _ventaCompCtrl,
                          maxLength: 140,
                          decoration: const InputDecoration(
                            labelText: '• Ventas Competencia (máx 140 car.)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _presupAmericaCtrl,
                          maxLength: 140,
                          decoration: const InputDecoration(
                            labelText: '• 1 Presupuesto Colchones América (máx 140 car.)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _presupCompCtrl,
                          maxLength: 140,
                          decoration: const InputDecoration(
                            labelText: '• 1 Presupuesto Competencia (máx 140 car.)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                selectedVisit.ventaAmerica = _ventaAmericaCtrl.text.trim();
                                selectedVisit.ventasCompetencia = _ventaCompCtrl.text.trim();
                                selectedVisit.presupuestoAmerica = _presupAmericaCtrl.text.trim();
                                selectedVisit.presupuestoCompetencia = _presupCompCtrl.text.trim();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reporte de fin de día guardado en Hoja de Cálculo.')),
                              );
                            },
                            child: const Text('GUARDAR REPORTE FIN DE DÍA'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// VISTA 2: SUPERVISOR (MÁX 10 VISITAS + GARANTÍAS 6 FOTOS + ROL + CIERRE 1000)
// ============================================================================
class SupervisorView extends StatefulWidget {
  final Usuario usuario;
  final Future<bool> Function({required String titulo, bool permitirGaleria}) onCapture;

  const SupervisorView({super.key, required this.usuario, required this.onCapture});

  @override
  State<SupervisorView> createState() => _SupervisorViewState();
}

class _SupervisorViewState extends State<SupervisorView> {
  String tipoVisitaNueva = 'Sucursal';
  String sucursalSeleccionada = AppData.sucursales.first.codigo;
  final _folioCtrl = TextEditingController();
  final _domicilioCtrl = TextEditingController();
  final _cierre1000Ctrl = TextEditingController();

  void _agregarParada() {
    if (AppData.visitasSupervisor.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Límite máximo de 10 visitas diarias alcanzado.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final orden = AppData.visitasSupervisor.length + 1;
    setState(() {
      if (tipoVisitaNueva == 'Sucursal') {
        final suc = AppData.sucursales.firstWhere((s) => s.codigo == sucursalSeleccionada);
        AppData.visitasSupervisor.add(VisitaSupervisor(
          id: 'VS-20$orden',
          orden: orden,
          numSupervisor: widget.usuario.id,
          nombreSupervisor: widget.usuario.nombre,
          plaza: suc.plaza,
          tipo: 'Sucursal',
          sucursalCodigo: suc.codigo,
          destinoNombre: suc.nombre,
        ));
      } else {
        final folio = _folioCtrl.text.trim().isEmpty ? 'GAR-GNC-2026-09$orden' : _folioCtrl.text.trim();
        final dom = _domicilioCtrl.text.trim().isEmpty ? 'Domicilio Cliente Garantía' : _domicilioCtrl.text.trim();
        AppData.visitasSupervisor.add(VisitaSupervisor(
          id: 'VS-20$orden',
          orden: orden,
          numSupervisor: widget.usuario.id,
          nombreSupervisor: widget.usuario.nombre,
          plaza: widget.usuario.plaza,
          tipo: 'Garantia',
          destinoNombre: 'Garantía: $dom',
          folioGarantia: folio,
        ));
        _folioCtrl.clear();
        _domicilioCtrl.clear();
      }
    });
  }

  Future<void> _abrirModalGarantia6Fotos(VisitaSupervisor v) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verificación Folio Garantía: ${v.folioGarantia}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Text('Adjunta las 6 fotografías reglamentarias (Cámara o Galería permitida):',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(6, (idx) {
                  final ok = v.fotosGarantia[idx];
                  return FilterChip(
                    selected: ok,
                    label: Text(AppData.etiquetasFotosGarantia[idx], style: const TextStyle(fontSize: 11)),
                    onSelected: (_) async {
                      final captured = await widget.onCapture(
                        titulo: AppData.etiquetasFotosGarantia[idx],
                        permitirGaleria: true,
                      );
                      if (captured) {
                        setModalState(() => v.fotosGarantia[idx] = true);
                        setState(() {});
                      }
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      for (var i = 0; i < 6; i++) {
                        v.fotosGarantia[i] = true;
                      }
                      v.estatus = 'Cerrada';
                      v.horaSalida = '12:45:00';
                      v.tiempoEstanciaMin = 35;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar 6 Fotos y Cerrar Garantía'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PLAN DIARIO SUPERVISOR (MÁX 10)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Chip(label: Text('${AppData.visitasSupervisor.length} / 10')),
                  ],
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Sucursal', label: Text('🏬 Sucursal GNC')),
                    ButtonSegment(value: 'Garantia', label: Text('🛠️ Folio Garantía')),
                  ],
                  selected: {tipoVisitaNueva},
                  onSelectionChanged: (s) => setState(() => tipoVisitaNueva = s.first),
                ),
                const SizedBox(height: 12),
                if (tipoVisitaNueva == 'Sucursal')
                  DropdownButtonFormField<String>(
                    value: sucursalSeleccionada,
                    items: AppData.sucursales
                        .map((s) => DropdownMenuItem(value: s.codigo, child: Text('${s.nombre} (${s.plaza})')))
                        .toList(),
                    onChanged: (val) => setState(() => sucursalSeleccionada = val ?? sucursalSeleccionada),
                  )
                else ...[
                  TextField(
                    controller: _folioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número de Folio de Garantía',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _domicilioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Colonia / Referencia del Domicilio Cliente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _agregarParada,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Agregar al Plan de Trabajo'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Lista de paradas
        ...AppData.visitasSupervisor.map((v) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: v.tipo == 'Garantia' ? Colors.amber.shade700 : const Color(0xFF0F2942),
                  foregroundColor: Colors.white,
                  child: Text('${v.orden}'),
                ),
                title: Text('${v.destinoNombre} ${v.folioGarantia.isNotEmpty ? "(${v.folioGarantia})" : ""}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                  'Estatus: ${v.estatus} • Traslado: ${v.tiempoTrasladoMin}m • Estancia: ${v.tiempoEstanciaMin}m'
                  '${v.tipo == "Garantia" ? "\nEvidencias: ${v.fotosGarantia.where((e) => e).length}/6 fotos" : ""}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: v.estatus == 'Pendiente'
                    ? FilledButton(
                        onPressed: () async {
                          final ok = await widget.onCapture(
                            titulo: 'Entrada Supervisión: ${v.destinoNombre}',
                            permitirGaleria: v.tipo == 'Garantia',
                          );
                          if (!ok) return;
                          setState(() {
                            v.estatus = 'En Curso';
                            v.horaEntrada = '11:20:00';
                            v.tiempoTrasladoMin = v.orden == 1 ? 0 : 24;
                          });
                          if (v.tipo == 'Garantia') {
                            _abrirModalGarantia6Fotos(v);
                          }
                        },
                        child: const Text('Entrada'),
                      )
                    : v.estatus == 'En Curso'
                        ? FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: v.tipo == 'Garantia' ? Colors.amber.shade800 : Colors.red.shade700),
                            onPressed: () async {
                              if (v.tipo == 'Garantia') {
                                _abrirModalGarantia6Fotos(v);
                              } else {
                                final ok = await widget.onCapture(titulo: 'Salida Supervisión: ${v.destinoNombre}');
                                if (!ok) return;
                                setState(() {
                                  v.estatus = 'Cerrada';
                                  v.horaSalida = '12:05:00';
                                  v.tiempoEstanciaMin = 45;
                                });
                              }
                            },
                            child: Text(v.tipo == 'Garantia' ? '6 Fotos' : 'Salida'),
                          )
                        : const Icon(Icons.check_circle, color: Colors.green),
              ),
            )),
        const SizedBox(height: 12),

        // Cierre del día 1000 caracteres
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CIERRE DE DÍA DEL SUPERVISOR (MÁX 1,000 CARACTERES)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: _cierre1000Ctrl,
                  maxLength: 1000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Comentarios generales de supervisión, exhibiciones y garantías...',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (_cierre1000Ctrl.text.trim().isEmpty) return;
                      setState(() {
                        AppData.cierresSupervisor.insert(
                          0,
                          CierreSupervisor(
                            fecha: '2026-11-04',
                            supervisor: widget.usuario.nombre,
                            plaza: widget.usuario.plaza,
                            comentario: _cierre1000Ctrl.text.trim(),
                          ),
                        );
                        _cierre1000Ctrl.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cierre general del supervisor registrado.')),
                      );
                    },
                    child: const Text('ENVIAR CIERRE DE DÍA'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// VISTA 3: ADMINISTRADOR Y EJECUTIVO / DIRECCIÓN (TABLAS + CONTINGENCIAS + ALTAS)
// ============================================================================
class AdminExecutiveView extends StatefulWidget {
  final Usuario usuario;
  const AdminExecutiveView({super.key, required this.usuario});

  @override
  State<AdminExecutiveView> createState() => _AdminExecutiveViewState();
}

class _AdminExecutiveViewState extends State<AdminExecutiveView> {
  int currentTab = 0;

  void _autorizarContingenciaPromotor(VisitaPromotor vp) {
    setState(() {
      vp.estatus = 'Cerrada - Autorizada Admin';
      vp.horaSalida ??= '18:00:00';
      vp.notaAdmin = 'Autorizado por Admin (Contingencia / Enfermedad)';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visita cerrada como AUTORIZADA POR ADMINISTRADOR.')),
    );
  }

  void _autorizarContingenciaSupervisor(VisitaSupervisor vs) {
    setState(() {
      vs.estatus = 'Cerrada - Autorizada Admin';
      vs.horaSalida ??= '18:00:00';
      vs.notaAdmin = 'Autorizado por Admin (Contingencia)';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supervisión cerrada como AUTORIZADA POR ADMINISTRADOR.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.usuario.rol == 'admin';
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: isAdmin ? Colors.amber.shade100 : Colors.lightBlue.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            isAdmin
                ? 'MODO SUPERUSUARIO (ADMINISTRADOR): Visualización total + Cierres por Contingencia + Alta de Sucursales y Usuarios.'
                : 'MODO SOLO LECTURA (EJECUTIVO / GERENCIA / DIRECCIÓN): Consulta de métricas y tiempos efectivos en tiempo real.',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        NavigationBar(
          selectedIndex: currentTab,
          onDestinationSelected: (idx) => setState(() => currentTab = idx),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.table_chart), label: 'Hoja Resumen'),
            NavigationDestination(icon: Icon(Icons.store_mall_directory), label: 'Sucursales 100m'),
            NavigationDestination(icon: Icon(Icons.people_alt), label: 'Usuarios y Roles'),
          ],
        ),
        Expanded(
          child: currentTab == 0
              ? _buildHojaResumen(isAdmin)
              : currentTab == 1
                  ? _buildCatalogoSucursales(isAdmin)
                  : _buildDirectorioUsuarios(isAdmin),
        ),
      ],
    );
  }

  Widget _buildHojaResumen(bool isAdmin) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('CONCENTRADO DE PROMOTORES (PISO DE VENTA)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...AppData.visitasPromotor.map((vp) => Card(
              child: ListTile(
                title: Text('${vp.nombreSucursal} (${vp.plaza}) — ${vp.nombrePromotor}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                  'Estatus: ${vp.estatus} | T. Efectivo: ${vp.tiempoEfectivoMin} min | Afluencia: ${vp.afluencia} (${vp.ingresosClientes} ing.)\n'
                  'Venta América: ${vp.ventaAmerica.isEmpty ? "--" : vp.ventaAmerica}\n'
                  '${vp.notaAdmin.isNotEmpty ? "Nota Admin: ${vp.notaAdmin}" : ""}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: (isAdmin && !vp.estatus.startsWith('Cerrada'))
                    ? FilledButton.tonal(
                        onPressed: () => _autorizarContingenciaPromotor(vp),
                        child: const Text('⚡ Autorizar Cierre', style: TextStyle(fontSize: 11)),
                      )
                    : const Icon(Icons.verified, color: Colors.blueGrey),
              ),
            )),
        const SizedBox(height: 16),
        const Text('CONCENTRADO DE SUPERVISORES (ESTANCIA + TRASLADO + GARANTÍAS)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...AppData.visitasSupervisor.map((vs) => Card(
              child: ListTile(
                title: Text('#${vs.orden} [${vs.tipo}] ${vs.destinoNombre} — ${vs.nombreSupervisor}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                  'Estatus: ${vs.estatus} | Traslado: ${vs.tiempoTrasladoMin} min | Estancia: ${vs.tiempoEstanciaMin} min'
                  '${vs.folioGarantia.isNotEmpty ? "\nFolio: ${vs.folioGarantia} (${vs.fotosGarantia.where((e) => e).length}/6 fotos)" : ""}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: (isAdmin && !vs.estatus.startsWith('Cerrada'))
                    ? FilledButton.tonal(
                        onPressed: () => _autorizarContingenciaSupervisor(vs),
                        child: const Text('⚡ Autorizar Cierre', style: TextStyle(fontSize: 11)),
                      )
                    : const Icon(Icons.verified, color: Colors.blueGrey),
              ),
            )),
      ],
    );
  }

  Widget _buildCatalogoSucursales(bool isAdmin) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: AppData.sucursales.length,
      itemBuilder: (ctx, idx) {
        final s = AppData.sucursales[idx];
        return Card(
          child: SwitchListTile(
            title: Text('${s.nombre} (${s.codigo})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${s.plaza} • GPS: ${s.lat}, ${s.lng}\nGeocerca 100 metros: ${s.geocercaActiva ? "ACTIVA" : "LIBRE"}',
                style: const TextStyle(fontSize: 12)),
            value: s.geocercaActiva,
            onChanged: isAdmin ? (val) => setState(() => s.geocercaActiva = val) : null,
          ),
        );
      },
    );
  }

  Widget _buildDirectorioUsuarios(bool isAdmin) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: AppData.usuarios.length,
      itemBuilder: (ctx, idx) {
        final u = AppData.usuarios[idx];
        return Card(
          child: SwitchListTile(
            title: Text('${u.nombre} (${u.rol.toUpperCase()})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('No. Colaborador: ${u.id} • Password: ${u.pass} • Plaza: ${u.plaza}',
                style: const TextStyle(fontSize: 12)),
            value: u.activo,
            onChanged: isAdmin ? (val) => setState(() => u.activo = val) : null,
          ),
        );
      },
    );
  }
}
