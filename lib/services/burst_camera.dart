import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:gal/gal.dart';

/// Headless burst capture: opens a camera facing [direction] (the
/// ultrawide when the platform reports one) without a preview and saves
/// one photo per [interval] to the camera roll until [stop] is called.
class BurstCamera {
  BurstCamera({
    this.direction = CameraLensDirection.back,
    this.interval = const Duration(seconds: 1),
    this.onShot,
  });

  final CameraLensDirection direction;
  final Duration interval;

  /// Called with the running total after each photo is saved.
  final void Function(int count)? onShot;

  CameraController? _controller;
  Timer? _timer;
  bool _capturing = false;
  int count = 0;

  bool get isRunning => _controller != null;

  /// Throws if the camera or photo library is unavailable / denied.
  Future<void> start() async {
    if (isRunning) return;
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw Exception('Sem permissão para salvar na galeria');
    }

    final cameras = await availableCameras();
    final matching =
        cameras.where((c) => c.lensDirection == direction).toList();
    if (matching.isEmpty) {
      throw Exception(direction == CameraLensDirection.front
          ? 'Nenhuma câmera frontal'
          : 'Nenhuma câmera traseira');
    }
    // iOS reports lens types; Android (CameraX) reports unknown, so fall
    // back to the default camera for that direction there.
    final camera = matching.firstWhere(
      (c) => c.lensType == CameraLensType.ultraWide,
      orElse: () => matching.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    _controller = controller;
    count = 0;
    _timer = Timer.periodic(interval, (_) => _shoot());
  }

  Future<void> _shoot() async {
    final controller = _controller;
    // Skip a tick rather than queue shots if saving runs slower than
    // the interval.
    if (controller == null || _capturing) return;
    _capturing = true;
    try {
      final file = await controller.takePicture();
      await Gal.putImage(file.path);
      count++;
      onShot?.call(count);
      // The gallery keeps its own copy; drop the temp file.
      await File(file.path).delete();
    } catch (_) {
      // A dropped frame shouldn't end the burst.
    } finally {
      _capturing = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
