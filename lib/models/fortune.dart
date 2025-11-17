// 运势等级枚举
enum FortuneLevel {
  ping('平', '平平无奇，继续努力'),
  xiaoJi('小吉', '小有收获，再接再厉'),
  daJi('大吉', '大吉大利，好运连连');

  final String name;
  final String description;

  const FortuneLevel(this.name, this.description);
}

// 今日运势
class DailyFortune {
  final FortuneLevel level;
  final DateTime date;
  final String message;

  DailyFortune({
    required this.level,
    required this.date,
    required this.message,
  });

  // 生成今日运势（随机）
  factory DailyFortune.generate() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final index = random % FortuneLevel.values.length;
    final level = FortuneLevel.values[index];
    
    return DailyFortune(
      level: level,
      date: DateTime.now(),
      message: level.description,
    );
  }

  // 序列化（用于持久化）
  Map<String, dynamic> toMap() {
    return {
      'level': level.name, // 使用枚举的 name
      'date': date.toIso8601String(),
      'message': message,
    };
  }

  // 反序列化（用于持久化）
  factory DailyFortune.fromMap(Map<String, dynamic> map) {
    final levelStr = map['level'] as String;
    FortuneLevel level;
    try {
      level = FortuneLevel.values.firstWhere((e) => e.name == levelStr);
    } catch (_) {
      level = FortuneLevel.ping; // 默认值
    }
    return DailyFortune(
      level: level,
      date: DateTime.parse(map['date']),
      message: map['message'] as String? ?? level.description,
    );
  }
}

