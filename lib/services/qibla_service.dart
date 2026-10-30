import 'log_service.dart';
import 'dart:math' as math;

/// ==========================================================
/// KIBLE HESABI - internet gerektirmez
/// Kabe koordinatları sabittir (21.4225 K, 39.8262 D).
/// Kullanıcının GPS konumundan büyük daire (great-circle) formülüyle
/// kıble açısı (kuzeyden itibaren saat yönünde derece) hesaplanır.
/// ==========================================================
class QiblaService {
  static const double kaabaLat = 21.4225;
  static const double kaabaLng = 39.8262;

  static double _toRad(double d) => d * math.pi / 180;
  static double _toDeg(double r) => r * 180 / math.pi;

  static double _bearingTo(
      double lat1, double lng1, double lat2, double lng2) {
    final phi1 = _toRad(lat1), phi2 = _toRad(lat2);
    final dLambda = _toRad(lng2 - lng1);
    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    final theta = _toDeg(math.atan2(y, x));
    return (theta + 360) % 360;
  }

  /// Kuzeyden itibaren saat yönünde kıble açısını derece cinsinden döndürür.
  static double qiblaBearing(double lat, double lng) {
    return _bearingTo(lat, lng, kaabaLat, kaabaLng);
  }
}
