import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AlpyApp());
}

class AlpyApp extends StatelessWidget {
  const AlpyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alpy Misali Çizim',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Minecraft',
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _count = prefs.getInt('count') ?? 0);
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DrawScreen(path: x.path)),
    );
    _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: _pick,
                  child: const Text('Fotoğraf Ekle',
                      style: TextStyle(fontSize: 24)),
                ),
              ),
              const Spacer(),
              const Text('Yaptığın projeler',
                  style: TextStyle(fontSize: 22, color: Colors.white)),
              const SizedBox(height: 8),
              Text('$_count',
                  style: const TextStyle(fontSize: 56, color: Colors.red)),
              const Spacer(),
              const Text('Alpy Misali Çizim',
                  style: TextStyle(fontSize: 30, color: Colors.red)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class DrawScreen extends StatefulWidget {
  final String path;
  const DrawScreen({super.key, required this.path});
  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  CameraController? _cam;
  String? _error;
  double _opacity = 0.5;
  double _scale = 1;
  double _baseScale = 1;
  Offset _offset = Offset.zero;
  bool _locked = false;
  bool _showBar = false;
  String? _msg;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl =
          CameraController(back, ResolutionPreset.high, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() => _cam = ctrl);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Kamera açılamadı. İzin verdin mi?');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  void _toast(String text) {
    _timer?.cancel();
    setState(() => _msg = text);
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _msg = null);
    });
  }

  void _toggleLock() {
    setState(() {
      _locked = !_locked;
      _showBar = false;
    });
    _toast(_locked ? 'Resim kilitlendi!' : 'Kilit açıldı!');
  }

  Future<void> _finish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eminim', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('count', (prefs.getInt('count') ?? 0) + 1);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _cameraLayer() {
    final c = _cam;
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: const TextStyle(color: Colors.red, fontSize: 20)),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }
    final s = c.value.previewSize!;
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: s.height,
            height: s.width,
            child: CameraPreview(c),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.8;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _cameraLayer()),
          Center(
            child: Transform.translate(
              offset: _offset,
              child: Transform.scale(
                scale: _scale,
                child: GestureDetector(
                  onTap: () {
                    if (!_locked) setState(() => _showBar = !_showBar);
                  },
                  onDoubleTap: _toggleLock,
                  onScaleStart: (d) => _baseScale = _scale,
                  onScaleUpdate: (d) {
                    if (_locked) return;
                    setState(() {
                      _scale = (_baseScale * d.scale).clamp(0.2, 5.0);
                      _offset += d.focalPointDelta;
                    });
                  },
                  child: Opacity(
                    opacity: _opacity,
                    child: Image.file(File(widget.path),
                        width: w, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: _finish,
                  child: const Text('Bitti'),
                ),
              ),
            ),
          ),
          if (_showBar && !_locked)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _opacity,
                            min: 0.05,
                            max: 1.0,
                            activeColor: Colors.red,
                            inactiveColor: Colors.red.shade200,
                            onChanged: (v) => setState(() => _opacity = v),
                          ),
                        ),
                        Text('${(_opacity * 100).round()}%',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 20)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_msg != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black87,
                  child: Text(_msg!,
                      style: const TextStyle(color: Colors.red, fontSize: 22)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
