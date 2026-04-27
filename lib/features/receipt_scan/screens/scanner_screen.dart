import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../transaction/transaction_repository.dart';
import '../ocr_notifier.dart';
import '../receipt_data_model.dart';
import '../widgets/scanner_overlay.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  final ReceiptScanArgs args;

  const ScannerScreen({super.key, this.args = const ReceiptScanArgs()});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  CameraController? _cameraController;
  Future<void>? _initializeFuture;
  bool _flashOn = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      setState(() {
        _cameraController = controller;
        _initializeFuture = controller.initialize();
      });
      await _initializeFuture;
      if (!mounted) return;
      await controller.setFlashMode(FlashMode.off);
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrNotifierProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          Positioned.fill(child: _buildPreview()),
          const Positioned.fill(child: ScannerOverlay()),
          if (ocrState.isScanning)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.72),
                child: Center(
                  child: _ScannerProcessing(step: ocrState.processingStep),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _toggleFlash,
                        icon: Icon(
                          _flashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'Posisikan struk di dalam kotak',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Pastikan semua teks terlihat jelas dan tidak terpotong.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.photo_library_outlined,
                        onTap: () async {
                          final file = await ref
                              .read(ocrNotifierProvider.notifier)
                              .pickFromGallery();
                          if (!context.mounted) return;
                          await _processCapturedFile(file);
                        },
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          await _captureAndProcess();
                        },
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 6),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF4F6EF7), Color(0xFF6B3FE7)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: Icons.receipt_long_rounded,
                        onTap: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_cameraController == null || _initializeFuture == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF13182A),
              const Color(0xFF0A0A0F),
              Colors.black.withValues(alpha: 0.92),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return CameraPreview(_cameraController!);
      },
    );
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    _flashOn = !_flashOn;
    await controller.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
  }

  Future<void> _captureAndProcess() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final shot = await controller.takePicture();
      await _processCapturedFile(File(shot.path));
    } catch (_) {}
  }

  Future<void> _processCapturedFile(File? file) async {
    if (file == null || _navigating) return;
    final result = await ref.read(ocrNotifierProvider.notifier).scan(file);
    if (!mounted || result == null) {
      if (mounted) {
        final error = ref.read(ocrNotifierProvider).error;
        if (error != null && error.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      }
      return;
    }
    _navigating = true;
    final draft = ref.read(ocrNotifierProvider.notifier).buildDraft(result);
    final targetTransactionId = widget.args.transactionId;
    if (result.confidence >= 72 && (result.totalAmount ?? 0) > 0) {
      if (!mounted) return;
      if (targetTransactionId != null && targetTransactionId.isNotEmpty) {
        await ref
            .read(transactionRepositoryProvider)
            .saveReceiptMetadata(targetTransactionId, result.toJson());
        if (!mounted) return;
        context.pop(true);
        return;
      }
      context.pushReplacementNamed('add-transaction', extra: draft);
      return;
    }
    if (!mounted) return;
    context.pushReplacementNamed(
      'review-receipt',
      extra: ReceiptReviewArgs(
        imagePath: file.path,
        transactionId: targetTransactionId,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF151A2A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ScannerProcessing extends StatelessWidget {
  final int step;

  const _ScannerProcessing({required this.step});

  @override
  Widget build(BuildContext context) {
    final labels = ['Memproses gambar...', 'Mengekstrak data...', 'Selesai!'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 52,
          height: 52,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 18),
        const Text(
          'Membaca struk...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(labels.length, (index) {
          final active = step >= index + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${active ? '✅' : '•'} ${labels[index]}',
              style: TextStyle(color: active ? Colors.white : Colors.white54),
            ),
          );
        }),
        const SizedBox(height: 6),
        const Text(
          'Estimasi 3-5 detik',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }
}
