import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bank_notification_parser.dart';

class NotificationBridgeService {
  NotificationBridgeService._();

  static const MethodChannel _channel = MethodChannel(
    'id.sakupro.saku_pro/notification_listener',
  );

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void setOnPendingEventsAvailable(VoidCallback? callback) {
    if (!isSupportedPlatform) {
      return;
    }
    if (callback == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onPendingEventsAvailable') {
        callback();
      }
    });
  }

  static Future<bool> isPermissionGranted() async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      final granted = await _channel.invokeMethod<bool>('isPermissionGranted');
      return granted ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> openNotificationAccessSettings() async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      final ok = await _channel.invokeMethod<bool>(
        'openNotificationAccessSettings',
      );
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> openAppDetailsSettings() async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('openAppDetailsSettings');
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> updateConfig({
    required bool enabled,
    required List<String> packages,
  }) async {
    if (!isSupportedPlatform) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('updateConfig', <String, Object>{
        'enabled': enabled,
        'packages': packages,
      });
    } on PlatformException {
      // Ignore bridge failure during background or detached teardown.
    } on MissingPluginException {
      // Safe no-op in widget tests without Android host binary.
    }
  }

  static Future<List<RawBankNotification>> drainPendingEvents() async {
    if (!isSupportedPlatform) {
      return const <RawBankNotification>[];
    }
    try {
      final rawJson =
          await _channel.invokeMethod<String>('drainPendingEvents') ?? '[]';
      return _decodeRawList(rawJson);
    } on PlatformException {
      return const <RawBankNotification>[];
    } on MissingPluginException {
      return const <RawBankNotification>[];
    }
  }

  static Future<List<RawBankNotification>> readRecentLogs() async {
    if (!isSupportedPlatform) {
      return const <RawBankNotification>[];
    }
    try {
      final rawJson =
          await _channel.invokeMethod<String>('readRecentLogs') ?? '[]';
      return _decodeRawList(rawJson);
    } on PlatformException {
      return const <RawBankNotification>[];
    } on MissingPluginException {
      return const <RawBankNotification>[];
    }
  }

  static Future<void> clearRecentLogs() async {
    if (!isSupportedPlatform) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('clearRecentLogs');
    } on PlatformException {
      // No-op on platform error.
    } on MissingPluginException {
      // No-op in tests.
    }
  }

  static List<RawBankNotification> _decodeRawList(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return const <RawBankNotification>[];
      }
      final result = <RawBankNotification>[];
      for (final item in decoded) {
        if (item is Map) {
          result.add(
            RawBankNotification.fromJson(Map<String, Object?>.from(item)),
          );
        }
      }
      return result;
    } catch (_) {
      return const <RawBankNotification>[];
    }
  }
}
