import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class NativeNotificationService {
  NativeNotificationService._();

  static final NativeNotificationService instance =
      NativeNotificationService._();

  static const _channel = MethodChannel('com.tmsxhub/notifications');
  final StreamController<Map<String, dynamic>> _tapController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationTaps => _tapController.stream;

  void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onNotificationTap') return null;
      final args = call.arguments;
      if (args is Map) {
        _tapController.add(Map<String, dynamic>.from(args));
      }
      return null;
    });
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    final allowed = await _channel.invokeMethod<bool>('requestPermission');
    return allowed ?? false;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? target,
  }) async {
    if (!Platform.isAndroid || title.trim().isEmpty) return;
    await _channel.invokeMethod<void>('showNotification', {
      'id': id,
      'title': title,
      'body': body,
      'target': target ?? '',
    });
  }

  Future<Map<String, dynamic>?> consumeInitialTapPayload() async {
    if (!Platform.isAndroid) return null;
    final payload = await _channel.invokeMapMethod<String, dynamic>(
      'consumeInitialTapPayload',
    );
    return payload == null ? null : Map<String, dynamic>.from(payload);
  }

  Future<void> showApprovalTodoNotification({
    required int count,
    String? siteName,
  }) async {
    if (!Platform.isAndroid || count <= 0) return;
    await showNotification(
      id: 1001,
      title: 'Todo approval menunggu',
      body: siteName?.trim().isNotEmpty == true
          ? '$count dokumen perlu approval di $siteName.'
          : '$count dokumen perlu approval.',
      target: 'approval_todo',
    );
  }
}
