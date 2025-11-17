import 'package:flutter/material.dart';

// 调试菜单组件
class DebugMenu extends StatelessWidget {
  final int speedMultiplier;
  final bool isStudying;
  final Function(int) onSpeedChange;

  const DebugMenu({
    super.key,
    required this.speedMultiplier,
    required this.isStudying,
    required this.onSpeedChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text(
            '⚙️ 调试加速模式',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '当前速度: ${speedMultiplier}x',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              _buildSpeedButton(1),
              _buildSpeedButton(5),
              _buildSpeedButton(10),
              _buildSpeedButton(60),
              _buildSpeedButton(300),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '提示：学习开始后无法切换速度',
            style: TextStyle(fontSize: 12, color: Colors.red),
          ),
          const Divider(),
          const Text(
            '速度说明：\n1x=正常 5x=5倍速 10x=10倍速\n60x=1分钟=1秒 300x=5分钟=1秒',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(int speed) {
    return ElevatedButton(
      onPressed: isStudying ? null : () => onSpeedChange(speed),
      style: ElevatedButton.styleFrom(
        backgroundColor: speedMultiplier == speed ? Colors.red : Colors.grey,
      ),
      child: Text('${speed}x'),
    );
  }
}

