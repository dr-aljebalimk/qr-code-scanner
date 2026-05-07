import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';
import '../models/scan_result_model.dart';
import '../services/history_service.dart';
import '../services/url_service.dart';
import '../theme/app_theme.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/glass_button.dart';
import '../widgets/permission_request_view.dart';
import '../widgets/success_flash.dart';
import 'history_screen.dart';

enum _PermState { checking, granted, denied, permanentlyDenied }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final HistoryService _historyService = HistoryService();
  final _uuid = const Uuid();

  _PermState _permState = _PermState.checking;
  bool _isFlashOn = false;
  bool _showSuccess = false;
  bool _isProcessing = false;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerCtrl.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _scannerCtrl.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _scannerCtrl.stop();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    _applyPermissionStatus(status);
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    _applyPermissionStatus(status);
  }

  void _applyPermissionStatus(PermissionStatus status) {
    setState(() {
      if (status.isGranted) {
        _permState = _PermState.granted;
      } else if (status.isPermanentlyDenied) {
        _permState = _PermState.permanentlyDenied;
      } else {
        _permState = _PermState.denied;
      }
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final now = DateTime.now();
    if (_lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 2500) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;
      if (!UrlService.isValidUrl(rawValue)) continue;

      _isProcessing = true;
      _lastScanTime = now;

      await HapticFeedback.lightImpact();
      setState(() => _showSuccess = true);

      final scan = ScanResultModel(
        id: _uuid.v4(),
        url: rawValue,
        scannedAt: DateTime.now(),
      );
      await _historyService.addScan(scan);

      Fluttertoast.showToast(
        msg: 'Opening: ${scan.displayUrl}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
        backgroundColor: AppTheme.success.withValues(alpha: 0.9),
        textColor: Colors.black,
        fontSize: 14,
      );

      await UrlService.openUrl(rawValue);
      break;
    }
  }

  void _onSuccessComplete() {
    setState(() {
      _showSuccess = false;
      _isProcessing = false;
    });
  }

  void _toggleFlash() {
    setState(() => _isFlashOn = !_isFlashOn);
    _scannerCtrl.toggleTorch();
  }

  Future<void> _openGallery() async {
    // mobile_scanner ^7 requires a real file path from image_picker.
    // To enable gallery scanning: add image_picker to pubspec, pick an image,
    // then call: await _scannerCtrl.analyzeImage(pickedFile.path)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Gallery: add image_picker, pick a file, then call analyzeImage(path)',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openHistory() async {
    _scannerCtrl.stop();
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const HistoryScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    _scannerCtrl.start();
  }

  @override
  Widget build(BuildContext context) {
    if (_permState == _PermState.checking) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (_permState == _PermState.denied ||
        _permState == _PermState.permanentlyDenied) {
      return PermissionRequestView(
        isPermanentlyDenied: _permState == _PermState.permanentlyDenied,
        onRequest: _requestPermission,
      );
    }

    const frameSize = 280.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'QR SCANNER',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _scannerCtrl,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),

          // Dimming overlay
          ScannerDimOverlay(frameSize: frameSize),

          // Scanner frame + laser
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const PulseRing(),
                    ScannerOverlay(size: frameSize),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'POINT AT A QR CODE',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),

          // Bottom glass bar
          GlassBottomBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GlassButton(
                  icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  label: 'Flash',
                  onTap: _toggleFlash,
                  isActive: _isFlashOn,
                  activeColor: const Color(0xFFFFD600),
                ),
                GlassButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: _openGallery,
                ),
                GlassButton(
                  icon: Icons.history_rounded,
                  label: 'History',
                  onTap: _openHistory,
                ),
              ],
            ),
          ),

          // Success overlay
          if (_showSuccess)
            Positioned.fill(
              child: SuccessFlash(onComplete: _onSuccessComplete),
            ),
        ],
      ),
    );
  }
}
