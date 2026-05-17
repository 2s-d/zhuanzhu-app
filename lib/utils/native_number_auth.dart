import 'package:flutter/services.dart';

/// 原生号码认证工具：通过平台通道调用 Android/iOS 原生代码，获取阿里云号码认证 token
class NativeNumberAuth {
  static const MethodChannel _channel = MethodChannel('focus_app/native_number_auth');

  /// 加速校验（可选，进入输入手机号页面时调用，可以更快获取 token）
  /// [timeout] - 超时时间（毫秒），默认 5000
  /// 返回：{ success: bool, vendor: String?, errorMsg: String? }
  static Future<Map<String, dynamic>> accelerateVerify({int timeout = 5000}) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'accelerateVerify',
        {'timeout': timeout},
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      return {
        'success': false,
        'errorMsg': e.message ?? '加速校验失败',
      };
    } catch (_) {
      return {
        'success': false,
        'errorMsg': '加速校验失败',
      };
    }
  }

  /// 获取验证 token（核心方法）
  /// [timeout] - 超时时间（毫秒），默认 5000
  /// 成功返回：{ success: true, token: String, code: String?, msg: String? }
  /// 失败抛出 PlatformException
  static Future<Map<String, dynamic>> getVerifyToken({int timeout = 5000}) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getVerifyToken',
        {'timeout': timeout},
      );
      final resultMap = Map<String, dynamic>.from(result ?? {});
      if (resultMap['success'] == true && resultMap['token'] != null) {
        return resultMap;
      } else {
        throw PlatformException(
          code: resultMap['code'] ?? 'UNKNOWN_ERROR',
          message: resultMap['msg'] ?? '获取 token 失败',
        );
      }
    } on PlatformException catch (e) {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
      );
    }
  }
}
