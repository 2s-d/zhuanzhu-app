/// APP 配置文件示例（可以上传到 Git）
/// 
/// 使用方法：
/// 1. 复制此文件为 app_config.dart
/// 2. 填入真实的密钥信息
/// 3. app_config.dart 已在 .gitignore 中排除，不会上传到 Git

import 'package:flutter/foundation.dart';

class AppConfig {
  // 前后端通信密钥（与服务器端保持一致）
  static const String appFixedKey = 'your_app_fixed_key_here';
  
  // WebSocket 服务器地址
  // - 原生 APP（Android/iOS）：直接连公网中转服务器（不经过 Nginx，使用 ws://）
  // - Web 版：通过域名 + Nginx 代理（统一入口，使用 wss://）
  static String get wsUrl {
    if (kIsWeb) {
      // Web 版：使用域名，通过 Nginx 代理到 8080（支持 WSS）
      return 'wss://zhuanzhu.paku.uno/ws';
    } else {
      // 原生 APP：直接连公网中转服务器（IP + 端口，server.js 监听 ws://）
      return 'ws://your_server_ip:8080';
    }
  }
}
