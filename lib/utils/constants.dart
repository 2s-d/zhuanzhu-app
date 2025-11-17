// 应用常量
class AppConstants {
  // 时间常量
  static const int shortRestMinIntervalMinutes = 3;  // 短休息最小间隔（分钟）
  static const int shortRestMaxIntervalMinutes = 5;  // 短休息最大间隔（分钟）
  static const int shortRestDurationSeconds = 10;    // 短休息时长（秒）
  
  static const int longRestIntervalMinutes = 90;     // 长休息间隔（分钟）
  static const int longRestDurationSeconds = 20 * 60; // 长休息时长（秒）
  
  // 学习时长限制
  static const int minPresetMinutes = 60;            // 预设最小学习时长（分钟）
  static const int maxPresetMinutes = 720;           // 预设最大学习时长（分钟，12小时）
  static const int maxStudyMinutes = 720;           // 自由模式最大学习时长（分钟，12小时）
  
  // 积分规则
  static const int pointsPerShortRest = 1;           // 每次短休息获得的运
  static const int pointsPerLongRest = 30;           // 每次长休息获得的运
  static const int pointsPerMinute = 1;              // 每分钟获得的运（0.1运，以0.1为单位则为1）
  static const int pointsForPresetComplete = 30;     // 完成预设任务额外获得的运
  static const int pointsPerCheckIn = 30;            // 每次签到获得的运
  
  // 日志
  static const int maxLogEntries = 500;              // 最大日志条数
  
  // 初始值
  static const int initialPointsTenths = 1000;       // 初始运（100.0运 = 1000 tenths）
  static const int initialStudyMinutes = 300;        // 初始学习时长（分钟）
}

