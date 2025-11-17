import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';
import '../models/fortune.dart';

class AppData {
  static const currentSchema = 1;

  int schemaVersion;
  int globalPointsTenths;
  List<Project> projects;
  DateTime? lastCheckInDate;
  DateTime? lastFortuneDate;
  DailyFortune? todayFortune; // 今日运势（完整内容）
  int? themeSeedColorValue;

  AppData({
    this.schemaVersion = currentSchema,
    this.globalPointsTenths = 0,
    List<Project>? projects,
    this.lastCheckInDate,
    this.lastFortuneDate,
    this.todayFortune,
    this.themeSeedColorValue,
  }) : projects = projects ?? <Project>[];

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'globalPointsTenths': globalPointsTenths,
      'projects': projects.map((p) => p.toMap()).toList(),
      'lastCheckInDate': lastCheckInDate?.toIso8601String(),
      'lastFortuneDate': lastFortuneDate?.toIso8601String(),
      'todayFortune': todayFortune?.toMap(),
      'themeSeedColorValue': themeSeedColorValue,
    };
  }

  static AppData fromMap(Map<String, dynamic> map) {
    final int v = (map['schemaVersion'] ?? 1) as int;
    final List<Project> proj = [];
    final list = map['projects'] as List?;
    if (list != null) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          proj.add(Project.fromMap(item));
        } else if (item is Map) {
          proj.add(Project.fromMap(item.cast<String, dynamic>()));
        }
      }
    }
    DateTime? parseDate(String? s) => (s == null || s.isEmpty) ? null : DateTime.tryParse(s);
    DailyFortune? parseFortune(Map? m) {
      if (m == null) return null;
      try {
        return DailyFortune.fromMap(m.cast<String, dynamic>());
      } catch (_) {
        return null;
      }
    }

    final data = AppData(
      schemaVersion: v,
      globalPointsTenths: (map['globalPointsTenths'] ?? 0) as int,
      projects: proj,
      lastCheckInDate: parseDate(map['lastCheckInDate']),
      lastFortuneDate: parseDate(map['lastFortuneDate']),
      todayFortune: parseFortune(map['todayFortune'] as Map?),
      themeSeedColorValue: map['themeSeedColorValue'] as int?,
    );
    return _migrateIfNeeded(data);
  }

  static AppData _migrateIfNeeded(AppData data) {
    // 目前 v1 无迁移
    return data;
  }
}

class DataRepository {
  static final DataRepository instance = DataRepository._internal();
  DataRepository._internal();

  String _fileName = 'app_data.json';

  Future<File> _resolveFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
    // 如果需要调试切换文件名，可暴露 setter
  }

  Future<AppData> load() async {
    try {
      final f = await _resolveFile();
      if (!await f.exists()) {
        return AppData(schemaVersion: AppData.currentSchema);
      }
      final str = await f.readAsString();
      if (str.trim().isEmpty) {
        return AppData(schemaVersion: AppData.currentSchema);
      }
      final map = jsonDecode(str) as Map<String, dynamic>;
      return AppData.fromMap(map);
    } catch (e) {
      debugPrint('[data] load error: $e');
      return AppData(schemaVersion: AppData.currentSchema);
    }
  }

  Future<void> save(AppData data) async {
    try {
      final f = await _resolveFile();
      final tmp = File('${f.path}.tmp');
      final str = const JsonEncoder.withIndent('  ').convert(data.toMap());
      await tmp.writeAsString(str);
      await tmp.rename(f.path);
      debugPrint('[data] saved to ${f.path}');
    } catch (e) {
      debugPrint('[data] save error: $e');
    }
  }
}


