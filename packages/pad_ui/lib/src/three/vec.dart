import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Point 3D minimal (pas de dépendance vector_math).
class V3 {
  const V3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const zero = V3(0, 0, 0);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;

  V3 cross(V3 o) => V3(
    y * o.z - z * o.y,
    z * o.x - x * o.z,
    x * o.y - y * o.x,
  );

  double get length => math.sqrt(x * x + y * y + z * z);

  V3 get normalized {
    final l = length;
    return l == 0 ? this : V3(x / l, y / l, z / l);
  }

  Offset get xy => Offset(x, y);
}

/// Caméra orbitale : lacet libre (360°), tangage borné.
class OrbitCamera {
  OrbitCamera({
    required this.yaw,
    required this.pitch,
    this.distance = 4.2,
    this.focal = 3.6,
  });

  double yaw;
  double pitch;
  final double distance;
  final double focal;

  V3 rotate(V3 p) {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final x1 = p.x * cy + p.z * sy;
    final z1 = -p.x * sy + p.z * cy;
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final y2 = p.y * cp - z1 * sp;
    final z2 = p.y * sp + z1 * cp;
    return V3(x1, y2, z2);
  }

  /// Facteur de perspective (> 1 = plus proche).
  double perspective(double z) => focal / (focal - z);

  /// z « caméra » : positif = vers l'observateur.
  double depthOf(V3 world) => rotate(world).z;
}
