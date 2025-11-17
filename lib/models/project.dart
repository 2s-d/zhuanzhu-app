// 学习项目数据模型
import 'log_entry.dart';

class Project {
  final String id;
  final String name; // 项目名称（如"学习编程"）
  final DateTime createdAt; // 创建时间
  int totalStudyMinutes; // 累计学习时长（分钟）
  int totalPointsTenths; // 累计运（以0.1为单位）
  final List<LogEntry> logs; // 项目内的学习日志（最多500条）

  // 奖励配置（仅当前项目生效，null 表示使用默认）
  int? rewardShortRest; // 短休息获得的运（整数，1-10）
  int? rewardLongRest; // 长休息获得的运（整数，20-100）
  int? rewardPerMinuteTenths; // 每分钟获得的运（以0.1为单位的整数，1-30 => 0.1-3.0）

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    this.totalStudyMinutes = 0,
    this.totalPointsTenths = 0,
    List<LogEntry>? logs,
    this.rewardShortRest,
    this.rewardLongRest,
    this.rewardPerMinuteTenths,
  }) : logs = logs ?? [];

  // 从Map创建（用于持久化）
  factory Project.fromMap(Map<String, dynamic> map) {
    List<LogEntry> parseLogs() {
      final raw = map['logs'];
      if (raw is List) {
        return raw.map((e) {
          if (e is Map<String, dynamic>) return LogEntry.fromMap(e);
          if (e is Map) return LogEntry.fromMap(e.cast<String, dynamic>());
          return null;
        }).whereType<LogEntry>().toList();
      }
      return <LogEntry>[];
    }

    return Project(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['createdAt']),
      totalStudyMinutes: map['totalStudyMinutes'] ?? 0,
      totalPointsTenths: map['totalPointsTenths'] ?? (map['totalPoints'] ?? 0) * 10,
      logs: parseLogs(),
      // 奖励配置（1.0 可选：若后续需要再持久化；此处保持为可空）
      rewardShortRest: map['rewardShortRest'],
      rewardLongRest: map['rewardLongRest'],
      rewardPerMinuteTenths: map['rewardPerMinuteTenths'],
    );
  }

  // 转换为Map（用于持久化）
  Map<String, dynamic> toMap() {
    // 保证最多500条日志
    final List<LogEntry> cappedLogs = logs.length <= 500
        ? logs
        : logs.sublist(logs.length - 500);
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'totalStudyMinutes': totalStudyMinutes,
      'totalPointsTenths': totalPointsTenths,
      'logs': cappedLogs.map((e) => e.toMap()).toList(),
      'rewardShortRest': rewardShortRest,
      'rewardLongRest': rewardLongRest,
      'rewardPerMinuteTenths': rewardPerMinuteTenths,
    };
  }
}

