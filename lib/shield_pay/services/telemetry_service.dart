import 'dart:convert';
import 'dart:html' as html;
import 'settings_service.dart';

class TelemetryService {
  static const _key = 'shieldpay_telemetry_v1';

  static Future<void> logEvent(String event, Map<String, dynamic> data) async {
    try {
      if (!SettingsService.instance.current.telemetryEnabled) return;
      final raw = html.window.localStorage[_key];
      final list = raw == null ? <dynamic>[] : json.decode(raw) as List<dynamic>;
      final entry = {'event': event, 'data': data, 'ts': DateTime.now().toIso8601String()};
      list.add(entry);
      // Keep only recent 200 events
      if (list.length > 200) list.removeRange(0, list.length - 200);
      html.window.localStorage[_key] = json.encode(list);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadEvents() async {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null) return [];
      final list = json.decode(raw) as List<dynamic>;
      return List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      return [];
    }
  }
}
