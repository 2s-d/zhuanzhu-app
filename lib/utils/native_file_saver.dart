import 'dart:convert';
import 'package:flutter/services.dart';

/// 原生文件保存工具：通过平台通道调用 Android/iOS 原生代码，弹出系统文件保存对话框
class NativeFileSaver {
  static const MethodChannel _channel = MethodChannel('focus_app/native_file_saver');

  /// 保存 JSON 数据到用户选择的文件位置
  /// [suggestedFileName] - 建议的文件名（如：focus_data_1234567890.json）
  /// [jsonData] - 要保存的 JSON 数据（Map）
  /// 返回是否保存成功（true=成功，false=用户取消，异常会抛出）
  static Future<bool> saveJson({
    required String suggestedFileName,
    required Map<String, dynamic> jsonData,
  }) async {
    try {
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      
      final result = await _channel.invokeMethod<bool>(
        'saveJson',
        {
          'fileName': suggestedFileName,
          'content': jsonString,
        },
      );
      
      return result ?? false;
    } catch (e) {
      // 重新抛出异常，让调用方能看到具体错误信息
      rethrow;
    }
  }
}
