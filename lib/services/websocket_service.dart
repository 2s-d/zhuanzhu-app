import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../config/app_config.dart';

/// WebSocket 服务：用于号码认证和数据推送（单例模式）
class WebSocketService {
  static final WebSocketService instance = WebSocketService._internal();
  WebSocketService._internal();
  
  static String get wsUrl => AppConfig.wsUrl;
  static const String appFixedKey = AppConfig.appFixedKey; // 与 server.js 中的 APP_FIXED_KEY 保持一致

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String? _currentPhone;
  
  /// 检查WebSocket是否已连接
  bool get isConnected => _isConnected && _channel != null;

  // 号码认证回调
  Function(bool success, bool match, String? errorMessage)? onVerifyResult;
  
  // Debug：记录当前一次认证的 requestId，便于端到端排查
  String? _currentVerifyRequestId;
  
  // 等待一次 verify_result 的 Completer（用于让 verifyPhone() 可 await 回包）
  Completer<void>? _verifyCompleter;

  /// 连接 WebSocket
  Future<bool> connect() async {
    if (_isConnected) return true;

    try {
      print('[WebSocket] connecting to $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      print('[WebSocket] connected');

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('[WebSocket] 错误: $error');
          _isConnected = false;
        },
        onDone: () {
          print('[WebSocket] 连接关闭');
          _isConnected = false;
        },
      );

      return true;
    } catch (e) {
      print('[WebSocket] 连接失败: $e');
      _isConnected = false;
      return false;
    }
  }

  /// 处理收到的消息
  void _handleMessage(dynamic message) {
    try {
      // Android 真机上 message 可能是 String，也可能是 Uint8List/List<int>（二进制帧）
      final String text;
      if (message is String) {
        text = message;
      } else if (message is List<int>) {
        text = utf8.decode(message);
      } else {
        text = message.toString();
      }

      // Debug：打印收到的消息类型与前缀，便于定位是否收到了 verify_result
      final preview = text.length > 200 ? '${text.substring(0, 200)}...' : text;
      print('[WebSocket] recv (${message.runtimeType}): $preview');

      final data = jsonDecode(text);
      final type = data['type'] as String?;

      if (type == 'verify_result') {
        // 如果当前没有在等待认证结果（例如已经超时收敛），忽略迟到回包，避免 UI 状态错乱
        if (_verifyCompleter == null) {
          print('[WebSocket] verify_result ignored (not waiting)');
          return;
        }
        
        // requestId 对齐（如果服务端返回了 requestId）
        final reqId = data['requestId'] as String?;
        if (_currentVerifyRequestId != null && reqId != null && reqId != _currentVerifyRequestId) {
          print('[WebSocket] verify_result ignored (requestId mismatch): got=$reqId want=$_currentVerifyRequestId');
          return;
        }
        final success = data['success'] as bool? ?? false;
        final match = data['match'] as bool? ?? false;
        final errorMessage = data['errorMessage'] as String?;
        print('[WebSocket] verify_result matched requestId=${reqId ?? _currentVerifyRequestId} success=$success match=$match');
        onVerifyResult?.call(success, match, errorMessage);
        
        // 结束等待（无论成功失败，至少让 UI 收敛）
        _verifyCompleter?.complete();
        _verifyCompleter = null;
        _currentVerifyRequestId = null;
      } else if (type == 'registered') {
        print('[WebSocket] 注册成功: ${data['phone']}');
      } else if (type == 'error') {
        print('[WebSocket] 错误: ${data['message']}');
      }
    } catch (e) {
      print('[WebSocket] 解析消息失败: $e');
    }
  }

  /// 发送号码认证请求
  /// [phone] - 手机号
  /// [verifyToken] - 从原生 SDK 获取的 token
  Future<void> verifyPhone(String phone, String verifyToken, {String? requestId}) async {
    if (!_isConnected || _channel == null) {
      await connect();
    }

    try {
      // 如果上一次还没结束，先放弃（避免多次点击导致永远等不到）
      if (_verifyCompleter != null && !_verifyCompleter!.isCompleted) {
        _verifyCompleter!.complete();
      }
      _verifyCompleter = Completer<void>();
      _currentVerifyRequestId = requestId;

      // 获取设备 ID
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown';
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      }

      _channel?.sink.add(jsonEncode({
        'type': 'verify_phone',
        'requestId': requestId,
        'appKey': appFixedKey,
        'phone': phone,
        'deviceId': deviceId,
        'verifyToken': verifyToken,
      }));
      print('[WebSocket] sent verify_phone requestId=${requestId ?? "-"} phone=$phone deviceId=$deviceId');

      // 等待服务端回包 verify_result（由 _handleMessage 结束）
      // 超时兜底：避免一直转圈；超时后会回调失败，并忽略迟到回包
      await _verifyCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('[WebSocket] verify_result timeout (15s)');
          onVerifyResult?.call(false, false, '认证超时（15s）：服务器未返回结果');
          _verifyCompleter?.complete();
          _verifyCompleter = null;
          _currentVerifyRequestId = null;
        },
      );
    } catch (e) {
      print('[WebSocket] 发送认证请求失败: $e');
      onVerifyResult?.call(false, false, '发送请求失败: $e');
      _verifyCompleter?.complete();
      _verifyCompleter = null;
      _currentVerifyRequestId = null;
    }
  }

  /// 注册 APP（用于数据推送）
  Future<void> register(String phone, String key) async {
    if (!_isConnected || _channel == null) {
      await connect();
    }

    _currentPhone = phone;

    try {
      _channel?.sink.add(jsonEncode({
        'type': 'register',
        'phone': phone,
        'key': key,
      }));
    } catch (e) {
      print('[WebSocket] 注册失败: $e');
    }
  }

  /// 推送数据
  Future<void> pushData(Map<String, dynamic> data) async {
    if (!_isConnected || _channel == null || _currentPhone == null) {
      print('[WebSocket] 未连接或未注册，无法推送数据');
      return;
    }

    try {
      _channel?.sink.add(jsonEncode({
        'type': 'push',
        'phone': _currentPhone,
        'data': data,
      }));
    } catch (e) {
      print('[WebSocket] 推送数据失败: $e');
    }
  }

  /// 断开连接
  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _currentPhone = null;
  }
}
