// 日志类型枚举
enum LogType {
  info,    // 普通信息
  success, // 成功/积分增加
  warning, // 警告
  rest,    // 休息提示
}

// 日志条目
class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogType type;

  LogEntry({
    required this.message,
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
    };
  }

  static LogEntry fromMap(Map<String, dynamic> map) {
    LogType parseType(String? s) {
      if (s == null) return LogType.info;
      return LogType.values.firstWhere(
        (e) => e.name == s,
        orElse: () => LogType.info,
      );
    }

    DateTime parseTime(String? s) {
      if (s == null) return DateTime.now();
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    return LogEntry(
      message: map['message'] ?? '',
      timestamp: parseTime(map['timestamp']),
      type: parseType(map['type']),
    );
  }
}

