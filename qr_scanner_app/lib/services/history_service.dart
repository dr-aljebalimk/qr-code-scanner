import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result_model.dart';

class HistoryService {
  static const String _key = 'scan_history';
  static const int _maxHistory = 100;

  Future<List<ScanResultModel>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) {
          try {
            return ScanResultModel.fromJson(
                jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<ScanResultModel>()
        .toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  Future<void> addScan(ScanResultModel scan) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(scan.toJson()));
    if (raw.length > _maxHistory) raw.removeLast();
    await prefs.setStringList(_key, raw);
  }

  Future<void> deleteScan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((e) {
      try {
        final m = ScanResultModel.fromJson(
            jsonDecode(e) as Map<String, dynamic>);
        return m.id == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_key, raw);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
