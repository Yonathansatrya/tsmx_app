import 'dart:io';

import 'package:flutter/services.dart';

class NativeNotificationService {
  NativeNotificationService._();

  static final NativeNotificationService instance =
      NativeNotificationService._();

  static const _channel = MethodChannel('com.tmsxhub/notifications');

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    final allowed = await _channel.invokeMethod<bool>('requestPermission');
    return allowed ?? false;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid || title.trim().isEmpty) return;
    await _channel.invokeMethod<void>('showNotification', {
      'id': id,
      'title': title,
      'body': body,
    });
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
    );
  }
}
