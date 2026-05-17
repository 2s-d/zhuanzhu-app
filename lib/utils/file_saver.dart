import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';

import 'web_saver_stub.dart'
    if (dart.library.html) 'web_saver_html.dart';

/// 统一的 JSON 保存工具：在支持的平台上弹出“选择保存位置”的对话框。
///
/// 返回是否保存成功。
Future<bool> saveJsonWithPicker({
  required String defaultFileName,
  required Map<String, dynamic> json,
}) async {
  final jsonString = const JsonEncoder.withIndent('  ').convert(json);

  // Web：沿用已有的浏览器下载方案
  if (kIsWeb) {
    await saveJsonFileWeb(defaultFileName, jsonString);
    return true;
  }

  // 其它平台：通过 file_selector 让用户选择保存位置
  try {
    final location = await getSaveLocation(
      suggestedName: defaultFileName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'JSON',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );

    if (location == null) {
      // 用户取消
      return false;
    }

    final file = File(location.path);
    await file.writeAsString(jsonString);
    return true;
  } catch (e) {
    debugPrint('[file_saver] saveJsonWithPicker error: $e');
    return false;
  }
}

