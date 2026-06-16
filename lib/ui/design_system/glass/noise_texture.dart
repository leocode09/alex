import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Generates and caches a single small tiling grain image so the film-grain
/// overlay costs nothing per frame.
class GrainTexture {
  const GrainTexture._();

  static const int _size = 128;
  static ui.Image? _image;
  static Future<ui.Image>? _pending;

  static ui.Image? get imageOrNull => _image;

  static Future<ui.Image> load() {
    final cached = _image;
    if (cached != null) {
      return Future<ui.Image>.value(cached);
    }
    return _pending ??= _generate();
  }

  static Future<ui.Image> _generate() {
    final completer = Completer<ui.Image>();
    final random = Random(0xA11CE);
    final pixels = Uint8List(_size * _size * 4);
    for (var i = 0; i < _size * _size; i++) {
      final offset = i * 4;
      pixels[offset] = 255;
      pixels[offset + 1] = 255;
      pixels[offset + 2] = 255;
      pixels[offset + 3] = random.nextInt(256);
    }
    ui.decodeImageFromPixels(
      pixels,
      _size,
      _size,
      ui.PixelFormat.rgba8888,
      (image) {
        _image = image;
        completer.complete(image);
      },
    );
    return completer.future;
  }
}

/// Paints subtle, tiled film grain across its bounds. The base texture is white
/// noise; [tint] recolors it (dark grain for light mode, light grain for dark)
/// and [opacity] keeps it faint.
class NoiseOverlay extends StatefulWidget {
  final Color tint;
  final double opacity;
  final BlendMode blendMode;

  const NoiseOverlay({
    super.key,
    required this.tint,
    required this.opacity,
    this.blendMode = BlendMode.srcOver,
  });

  @override
  State<NoiseOverlay> createState() => _NoiseOverlayState();
}

class _NoiseOverlayState extends State<NoiseOverlay> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _image = GrainTexture.imageOrNull;
    if (_image == null) {
      GrainTexture.load().then((image) {
        if (mounted) {
          setState(() => _image = image);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null || widget.opacity <= 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity.clamp(0.0, 1.0),
        child: CustomPaint(
          isComplex: false,
          willChange: false,
          painter: _NoisePainter(
            image: image,
            tint: widget.tint,
            blendMode: widget.blendMode,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final ui.Image image;
  final Color tint;
  final BlendMode blendMode;

  const _NoisePainter({
    required this.image,
    required this.tint,
    required this.blendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      )
      ..colorFilter = ColorFilter.mode(tint, BlendMode.srcIn)
      ..blendMode = blendMode;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_NoisePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.tint != tint ||
        oldDelegate.blendMode != blendMode;
  }
}
