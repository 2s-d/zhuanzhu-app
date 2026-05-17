import 'dart:async';

/// 非 Web 环境下的占位实现，什么也不做（或抛出异常）
Future<void> saveJsonFileWeb(String suggestedName, String content) async {
  throw UnsupportedError('saveJsonFileWeb is only supported on web.');
}

