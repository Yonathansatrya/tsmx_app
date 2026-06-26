import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitLocationPoint {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;

  const VisitLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  });

  factory VisitLocationPoint.fromPosition(Position position) {
    return VisitLocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      capturedAt: position.timestamp,
    );
  }

  factory VisitLocationPoint.fromJson(Map<String, dynamic> json) {
    return VisitLocationPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      capturedAt: DateTime.parse(json['captured_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'captured_at': capturedAt.toIso8601String(),
  };
}

class SalesVisitLocationService {
  static const _queueKey = 'sales_visit_tracking_queue';
  static const trackingInterval = Duration(minutes: 5);
  StreamSubscription<Position>? _subscription;

  Future<VisitLocationPoint> currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('GPS belum aktif.');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Aktifkan melalui pengaturan perangkat.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return VisitLocationPoint.fromPosition(position);
  }

  double distanceMeters({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) {
    return Geolocator.distanceBetween(
      fromLatitude,
      fromLongitude,
      toLatitude,
      toLongitude,
    );
  }

  Future<void> startTracking(
    Future<void> Function(VisitLocationPoint point) onPoint, {
    String notificationTitle = 'Perjalanan customer aktif',
    String notificationText =
        'Aplikasi mencatat lokasi tiap 5 menit sampai check-in.',
    bool queueFailedPoints = true,
  }) async {
    await stopTracking();
    await currentPosition();
    final settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
            intervalDuration: trackingInterval,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: notificationTitle,
              notificationText: notificationText,
              enableWakeLock: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          );
    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) async {
          final point = VisitLocationPoint.fromPosition(position);
          try {
            await onPoint(point);
          } catch (_) {
            if (queueFailedPoints) await enqueue(point);
          }
        });
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> enqueue(VisitLocationPoint point) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? <String>[];
    queue.add(jsonEncode(point.toJson()));
    await prefs.setStringList(_queueKey, queue.takeLast(500).toList());
  }

  Future<List<VisitLocationPoint>> queuedPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? const [];
    return queue
        .map((row) => VisitLocationPoint.fromJson(jsonDecode(row)))
        .toList();
  }

  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }
}

extension<T> on List<T> {
  Iterable<T> takeLast(int count) => skip(length > count ? length - count : 0);
}
