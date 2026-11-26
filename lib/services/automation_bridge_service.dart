import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AutomationBridgeService {
  AutomationBridgeService._();

  static const MethodChannel _channel = MethodChannel(
    'id.sakupro.saku_pro/automation',
  );

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void setHandlers({
    ValueChanged<String>? onSharedImageReceived,
    ValueChanged<String>? onLaunchAction,
  }) {
    if (!isSupportedPlatform) {
      return;
    }
    if (onSharedImageReceived == null && onLaunchAction == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onSharedImageReceived' && call.arguments is String) {
        onSharedImageReceived?.call(call.arguments as String);
      } else if (call.method == 'onLaunchAction' && call.arguments is String) {
        onLaunchAction?.call(call.arguments as String);
      }
    });
  }

  static Future<String?> consumePendingSharedImage() async {
    if (!isSupportedPlatform) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('consumePendingSharedImage');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<String?> consumePendingLaunchAction() async {
    if (!isSupportedPlatform) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('consumePendingLaunchAction');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> hasPostNotificationPermission() async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'hasPostNotificationPermission',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> requestPostNotificationPermission() async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'requestPostNotificationPermission',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> showLocalNotification({
    required int id,
    required String channel,
    required String title,
    required String body,
  }) async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'showLocalNotification',
            <String, Object>{
              'id': id,
              'channel': channel,
              'title': title,
              'body': body,
            },
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> syncWidgetData({
    required String safeDailyText,
    required String netWorthText,
    required String statusLabel,
  }) async {
    if (!isSupportedPlatform) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('syncWidgetData', <String, Object>{
        'safeDailyText': safeDailyText,
        'netWorthText': netWorthText,
        'statusLabel': statusLabel,
      });
    } on PlatformException {
      // Safe no-op when widget host is unavailable.
    } on MissingPluginException {
      // Safe no-op in tests.
    }
  }

  static Future<void> syncReminderSchedule({
    required bool enabled,
    required String billsJson,
    required String weeklySummary,
  }) async {
    if (!isSupportedPlatform) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        'syncReminderSchedule',
        <String, Object>{
          'enabled': enabled,
          'billsJson': billsJson,
          'weeklySummary': weeklySummary,
        },
      );
    } on PlatformException {
      // Safe no-op.
    } on MissingPluginException {
      // Safe no-op in tests.
    }
  }

  static Future<String?> saveFileToDownloads({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? prunePrefix,
    int maxRetained = 5,
  }) async {
    if (!isSupportedPlatform) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>(
        'saveFileToDownloads',
        <String, Object?>{
          'fileName': fileName,
          'mimeType': mimeType,
          'bytes': bytes,
          'prunePrefix': ?prunePrefix,
          'maxRetained': maxRetained,
        },
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
