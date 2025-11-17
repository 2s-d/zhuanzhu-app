import 'dart:async';
import 'package:flutter/material.dart';

// 倒计时对话框 Widget
class CountdownDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String message;
  final int initialSeconds;
  final int speedMultiplier;
  final bool isLongRest;
  final VoidCallback onFinish;

  const CountdownDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.message,
    required this.initialSeconds,
    required this.speedMultiplier,
    required this.onFinish,
    this.isLongRest = false,
  });

  @override
  State<CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    // 根据加速倍数调整计时器间隔
    int milliseconds = (1000 / widget.speedMultiplier).round();
    _timer = Timer.periodic(Duration(milliseconds: milliseconds), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        // 倒计时结束
        timer.cancel();
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String timeDisplay;
    if (widget.isLongRest) {
      // 长休息：显示为 MM:SS 格式
      int minutes = _remainingSeconds ~/ 60;
      int seconds = _remainingSeconds % 60;
      timeDisplay = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      // 短休息：显示为秒数
      timeDisplay = '$_remainingSeconds秒';
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.icon, color: widget.iconColor, size: 30),
          const SizedBox(width: 10),
          Text(widget.title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.message,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            timeDisplay,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: widget.iconColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.isLongRest ? '长休息倒计时' : '短休息倒计时',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 5),
          const Text(
            '休息结束后将自动继续学习',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

