import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../utils/time_formatter.dart';

// 日志页面
class LogScreen extends StatelessWidget {
  final List<LogEntry> logs;

  const LogScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    // 反转列表，最新的在最上面
    final reversedLogs = logs.reversed.toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志记录'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                '共 ${logs.length} 条',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '暂无日志记录',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: reversedLogs.length,
              itemBuilder: (context, index) {
                final log = reversedLogs[index];
                return _buildLogItem(log);
              },
            ),
    );
  }

  Widget _buildLogItem(LogEntry log) {
    Color iconColor;
    IconData iconData;
    
    switch (log.type) {
      case LogType.success:
        iconColor = Colors.green;
        iconData = Icons.add_circle;
        break;
      case LogType.rest:
        iconColor = Colors.blue;
        iconData = Icons.spa;
        break;
      case LogType.warning:
        iconColor = Colors.orange;
        iconData = Icons.warning;
        break;
      case LogType.info:
      default:
        iconColor = Colors.grey;
        iconData = Icons.info;
    }
    
    // 格式化时间
    String timeStr = TimeFormatter.formatTimestamp(log.timestamp);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(iconData, color: iconColor),
        title: Text(log.message),
        subtitle: Text(
          timeStr,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        dense: true,
      ),
    );
  }
}

