import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/project.dart';
import '../models/fortune.dart';

/// 服务器配置
class ServerConfig {
  // 你的服务器地址（需要修改为实际的服务器IP或域名）
  static const String httpUrl = 'http://108.160.131.86:3007';
  static const String wsUrl = 'ws://108.160.131.86:8080';
}

/// 云同步服务
class CloudSyncService {
  /// 上传数据到服务器
  /// [phone] - 手机号，用于标识用户
  /// [key] - 连接密钥，用于验证
  /// [data] - AppData 数据
  /// 返回是否成功
  static Future<bool> uploadData({
    required String phone,
    required String key,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ServerConfig.httpUrl}/api/upload'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          'key': key,
          'data': data,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('[CloudSync] 上传失败: $e');
      return false;
    }
  }

  /// 检查手机连接状态
  /// [phone] - 手机号
  /// 返回是否在线
  static Future<bool> checkStatus(String phone) async {
    try {
      final response = await http.get(
        Uri.parse('${ServerConfig.httpUrl}/api/status?phone=$phone'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['connected'] == true;
      }
      return false;
    } catch (e) {
      print('[CloudSync] 检查状态失败: $e');
      return false;
    }
  }

  /// 从服务器获取数据
  /// [phone] - 手机号
  /// [key] - 连接密钥
  /// 返回服务器上的数据，如果失败返回null
  static Future<Map<String, dynamic>?> fetchData({
    required String phone,
    required String key,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ServerConfig.httpUrl}/api/data?phone=$phone&key=$key'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result['data'];
        }
      }
      return null;
    } catch (e) {
      print('[CloudSync] 获取数据失败: $e');
      return null;
    }
  }
}
