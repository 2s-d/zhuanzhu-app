import '../models/project.dart';

/// 统一的数据导出/推送格式构建器
/// 导出JSON文件和远程推送使用相同的数据格式
class ExportDataBuilder {
  /// 构建导出/推送数据
  /// 参数与导出JSON时保持一致
  static Map<String, dynamic> build({
    required int schemaVersion,
    required int globalPointsTenths,
    required List<Project> projects,
    DateTime? lastCheckInDate,
    int? consecutiveCheckInDays,
    int? themeSeedColorValue,
  }) {
    return {
      'schemaVersion': schemaVersion,
      'globalPointsTenths': globalPointsTenths,
      'projects': projects.map((p) => p.toMap()).toList(),
      'lastCheckInDate': lastCheckInDate?.toIso8601String(),
      'consecutiveCheckInDays': consecutiveCheckInDays,
      'themeSeedColorValue': themeSeedColorValue,
    };
  }
}
