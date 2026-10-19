import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';

import 'controller_2d.dart';
import 'theme.dart';

/// Rendu « 3D » de la manette : le dessin vectoriel détaillé est projeté en
/// perspective (rotation X/Y réelle), avec ombre portée et halo.
///
/// Pourquoi cette approche plutôt qu'un mesh low-poly ? Le tracé vectoriel
/// conserve tous les détails (sticks, gâchettes, glyphes) à toutes les tailles,
/// reste net sur écran Retina et ne souffre d'aucun artefact de tri de faces.
/// La rotation est une vraie transformation projective, pas un simple
/// changement d'échelle : l'effet est volumique et fluide à 60 fps.
class Controller3D extends StatefulWidget {
  const Controller3D({
    super.key,
    required this.state,
    this.layout = PadLayout.playstation,
    this.height = 280,
    this.autoRotate = false,
    this.initialYaw = -0.30,
    this.initialPitch = 0.95,
  });

  final PadState state;
  final PadLayout layout;
  final double height;
  final bool autoRotate;
  final double initialYaw;
  final double initialPitch;

  @override
  State<Controller3D> createState() => _Controller3DState();
}

class _Controller3DState extends State<Controller3D> with SingleTickerProviderStateMixin {
  late double _yaw = widget.initialYaw;
  late double _pitch = widget.initialPitch;
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _yaw = widget.initialYaw;
      _pitch = widget.initialPitch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onDoubleTap: _reset,
      onPanUpdate: (details) => setState(() {
        _yaw = (_yaw + details.delta.dx * 0.010).clamp(-1.15, 1.15);
        _pitch = (_pitch - details.delta.dy * 0.008).clamp(0.25, 1.45);
      }),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _idle,
          builder: (context, _) {
            final breathe = widget.autoRotate ? math.sin(_idle.value * 2 * math.pi) * 0.16 : 0.0;
            return _Stage(
              state: widget.state,
              layout: widget.layout,
              yaw: _yaw + breathe,
              pitch: _pitch,
              colors: colors,
            );
          },
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.state,
    required this.layout,
    required this.yaw,
    required this.pitch,
    required this.colors,
  });

  final PadState state;
  final PadLayout layout;
  final double yaw;
  final double pitch;
  final PadColors colors;

  @override
  Widget build(BuildContext context) {
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..rotateX(-pitch * 0.55)
      ..rotateZ(-yaw * 0.45);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 460.0);
        final padWidth = width * 0.82;
        final padHeight = padWidth * (168 / 280);

        final pad = SizedBox(
          width: padWidth,
          height: padHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Halo sous la manette.
              Positioned.fill(
                child: Transform(
                  transform: Matrix4.identity()..scaleByDouble(1.02, 0.86, 1, 1),
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(padHeight * 0.45),
                      boxShadow: [
                        BoxShadow(
                          color: colors.cyan.withValues(alpha: colors.isDark ? 0.18 : 0.10),
                          blurRadius: 55,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: colors.isDark ? 0.5 : 0.12),
                          blurRadius: 40,
                          offset: const Offset(0, 26),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: Size(padWidth, padHeight),
                painter: Controller2DPainter(
                  state: state,
                  layout: layout,
                  colors: colors,
                  showLabels: true,
                ),
              ),
            ],
          ),
        );

        return Center(
          child: Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Reflet au sol.
                Opacity(
                  opacity: 0.18,
                  child: Transform(
                    transform: Matrix4.identity()..scaleByDouble(1.0, -0.55, 1.0, 1),
                    alignment: Alignment.center,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 0, sigmaY: 10),
                      child: ShaderMask(
                        shaderCallback: (rect) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: pad,
                      ),
                    ),
                  ),
                ),
                pad,
              ],
            ),
          ),
        );
      },
    );
  }
}
