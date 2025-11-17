import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/log_entry.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/time_formatter.dart';
import '../widgets/countdown_dialog.dart';
import '../widgets/debug_menu.dart';
import 'log_screen.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class StudyScreen extends StatefulWidget {
  final Project project;
  final double globalPoints; // 初始全局总运（进入页面时的快照）
  final void Function(int deltaTenths) onGlobalTenthsDelta; // 学习过程中的全局运增量（0.1为单位）
  final void Function(int deltaTenths) onProjectTenthsDelta; // 学习过程中本项目运增量（0.1为单位）
  final void Function(int deltaMinutes) onProjectMinutesDelta; // 自由模式：学习分钟实时计入
  final Function(int studyMinutes, int earnedPoints) onStudyComplete;
  final void Function(int shortRest, int longRest, int perMinuteTenths)? onApplyGlobalRewards; // 全局应用奖励配置
  final VoidCallback? onRequestSave; // 新增：当页面内状态（如日志）变更时请求保存
  
  const StudyScreen({
    super.key,
    required this.project,
    required this.globalPoints,
    required this.onGlobalTenthsDelta,
    required this.onProjectTenthsDelta,
    required this.onProjectMinutesDelta,
    required this.onStudyComplete,
    this.onApplyGlobalRewards,
    this.onRequestSave,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _pointsTenths = 0; // 本项目获得的运
  int _totalStudyMinutes = 0; // 本项目的学习时长（仅在结束/结算时写入）
  bool _isStudying = false;
  int _globalPointsTenthsSnapshot = 0; // 不再用于显示，仅作为历史兼容占位
  // 副标题显示的“本项目累计”基于进入页面时的快照 + 本次会话增量，避免实时回传造成的双累加
  int _baseProjectPointsTenths = 0; // 进入页面时项目累计运（0.1为单位）
  int _baseProjectStudyMinutes = 0; // 进入页面时项目累计分钟数
  
  // 获取实际运（显示用）
  double get _points => _pointsTenths / 10.0;
  // 顶部总运显示：主页面传入的总运 + 本次学习获得的运（实时）
  double get _displayGlobalPoints => widget.globalPoints + _points;
  // 本项目累计显示（实时）：历史累计 + 本次学习累计
  double get _projectTotalPoints =>
      (_baseProjectPointsTenths + _pointsTenths) / 10.0;
  int get _projectTotalMinutes =>
      _isFreeMode ? (_baseProjectStudyMinutes + (_sessionStudySeconds ~/ 60)) : _baseProjectStudyMinutes;
  
  // 奖励配置（项目优先，默认回落到常量）
  int get _cfgShortRest => widget.project.rewardShortRest ?? AppConstants.pointsPerShortRest;
  int get _cfgLongRest => widget.project.rewardLongRest ?? AppConstants.pointsPerLongRest;
  int get _cfgPerMinuteTenths => widget.project.rewardPerMinuteTenths ?? AppConstants.pointsPerMinute; // 以0.1为单位
  
  @override
  void initState() {
    super.initState();
    // 记录进入页面时的项目累计快照，副标题用快照 + 本次增量，避免实时回传导致的双重累加
    _baseProjectPointsTenths = widget.project.totalPointsTenths;
    _baseProjectStudyMinutes = widget.project.totalStudyMinutes;
    // 绑定项目日志列表，保证返回主页面再进入不丢失
    _logs = widget.project.logs;
    // 首次进入学习页的引导
    _maybeShowOnboarding();
    // 读取提示音选择
    _loadSoundSelections();
  }
  
  // 学习模式：true=自由模式，false=预设模式
  bool _isFreeMode = true;
  
  // 计时器相关
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _presetMinutes = 0;
  int _sessionStudySeconds = 0;
  int _sessionTotalSeconds = 0;
  int _lastMinuteMarker = 0;

  // 旧的快照初始化已移除，直接用 widget.globalPoints + 本次运 计算显示
  
  // 小阶段休息相关
  int _nextShortRestSeconds = 0;
  bool _isShortResting = false;
  int _shortRestSecondsRemaining = AppConstants.shortRestDurationSeconds;
  int _shortRestCount = 0;
  final Random _random = Random();
  
  // 大阶段休息相关
  int _longRestInterval = AppConstants.longRestIntervalMinutes * 60;
  int _nextLongRestSeconds = AppConstants.longRestIntervalMinutes * 60;
  bool _isLongResting = false;
  int _longRestSeconds = AppConstants.longRestDurationSeconds;
  int _longRestSecondsRemaining = AppConstants.longRestDurationSeconds;
  int _longRestCount = 0;
  Timer? _soundTimer;
  // 音效播放器（本地资产优先，失败时回退 SystemSound）
  final AudioPlayer _shortPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _longPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  int _shortSoundIndex = 1; // 1~5
  int _longSoundIndex = 1;  // 1~4
  
  // 对话框状态追踪
  bool _isLongRestDialogShowing = false;
  bool _isShortRestDialogShowing = false;
  
  // 加速模式（开发调试用）
  int _speedMultiplier = 1;
  bool _showDebugMenu = false;
  
  // 日志相关（引用项目级日志，保持跨页面）
  late List<LogEntry> _logs;
  // 引导相关
  final GlobalKey _freeBtnKey = GlobalKey();
  final GlobalKey _presetBtnKey = GlobalKey();
  TutorialCoachMark? _coach;
  
  // 签到相关
  DateTime? _lastCheckInDate;
  bool _hasCheckedInToday = false;
  
  @override
  void dispose() {
    _timer?.cancel();
    _soundTimer?.cancel();
    _shortPlayer.dispose();
    _longPlayer.dispose();
    super.dispose();
  }
  
  // 添加日志
  void _addLog(String message, {LogType type = LogType.info}) {
    setState(() {
      final log = LogEntry(
        message: message,
        timestamp: DateTime.now(),
        type: type,
      );
      
      if (_logs.length >= AppConstants.maxLogEntries) {
        _logs.removeAt(0);
      }
      _logs.add(log);
    });
    // 请求主页面立即保存（确保进程被杀也不丢）
    try {
      widget.onRequestSave?.call();
    } catch (_) {}
  }
  
  // 签到功能
  void _showCheckInDialog() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_lastCheckInDate != null) {
      final lastCheckIn = DateTime(_lastCheckInDate!.year, _lastCheckInDate!.month, _lastCheckInDate!.day);
      if (lastCheckIn == today) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 30),
                SizedBox(width: 10),
                Text('今日已签到'),
              ],
            ),
            content: const Text(
              '您今天已经签到过了\n明天再来吧！',
              style: TextStyle(fontSize: 16),
            ),
          ),
        );
        return;
      }
    }
    
    _performCheckIn();
  }
  
  // 执行签到
  void _performCheckIn() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    int missedDays = 0;
    
    if (_lastCheckInDate != null) {
      final lastCheckIn = DateTime(_lastCheckInDate!.year, _lastCheckInDate!.month, _lastCheckInDate!.day);
      missedDays = today.difference(lastCheckIn).inDays;
    } else {
      missedDays = 1;
    }
    
    final earnedPoints = missedDays * AppConstants.pointsPerCheckIn;
    
    setState(() {
      _pointsTenths += earnedPoints * 10;
      _lastCheckInDate = now;
      _hasCheckedInToday = true;
    });
    
    if (missedDays == 1) {
      _addLog('签到成功，获得 +${AppConstants.pointsPerCheckIn} 运', type: LogType.success);
    } else {
      _addLog('补签 $missedDays 天，获得 +$earnedPoints 运', type: LogType.success);
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text('签到成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '活着就很幸运了',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (missedDays == 1)
              const Text('签到 1 天', style: TextStyle(fontSize: 16))
            else
              Text('补签 $missedDays 天', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text(
              '获得 +$earnedPoints 运',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '越努力越幸运',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // 开始自由模式学习
  void _startFreeMode() {
    setState(() {
      _isFreeMode = true;
      _isStudying = true;
      _isShortResting = false;
      _elapsedSeconds = 0;
      _sessionStudySeconds = 0;
      _sessionTotalSeconds = 0;
      _lastMinuteMarker = 0;
      _shortRestCount = 0;
      _longRestCount = 0;
    });
    
    _scheduleNextShortRest();
    _nextLongRestSeconds = _longRestInterval;
    _startStudyTimer();
  }
  
  // 开始预设模式学习
  void _startPresetMode(int minutes) {
    if (minutes < AppConstants.minPresetMinutes || minutes > AppConstants.maxPresetMinutes) {
      _showErrorDialog('预设时间必须大于等于${AppConstants.minPresetMinutes}且小于等于${AppConstants.maxPresetMinutes}分钟');
      return;
    }
    
    setState(() {
      _isFreeMode = false;
      _isStudying = true;
      _isShortResting = false;
      _presetMinutes = minutes;
      _elapsedSeconds = minutes * 60;
      _sessionStudySeconds = 0;
      _sessionTotalSeconds = 0;
      _lastMinuteMarker = 0;
      _shortRestCount = 0;
      _longRestCount = 0;
    });
    
    _scheduleNextShortRest();
    _nextLongRestSeconds = _longRestInterval;
    _startStudyTimer();
  }
  
  // 启动学习计时器
  void _startStudyTimer() {
    int milliseconds = (1000 / _speedMultiplier).round();
    _timer = Timer.periodic(Duration(milliseconds: milliseconds), (timer) {
      setState(() {
        _sessionTotalSeconds++;
        
        int currentMinute = _sessionTotalSeconds ~/ 60;
        if (currentMinute > _lastMinuteMarker) {
          final int deltaMin = currentMinute - _lastMinuteMarker;
          final int deltaTenths = _cfgPerMinuteTenths * deltaMin;
          _pointsTenths += deltaTenths;
          widget.onGlobalTenthsDelta(deltaTenths);
          widget.onProjectTenthsDelta(deltaTenths);
          if (_isFreeMode && deltaMin > 0) {
            // 自由模式：分钟实时计入项目累计，保证中断不丢失
            widget.onProjectMinutesDelta(deltaMin);
          }
          _lastMinuteMarker = currentMinute;
        }
      });
      
      if (_isLongResting) {
        setState(() {
          if (_longRestSecondsRemaining > 0) {
            _longRestSecondsRemaining--;
          } else {
            _isLongResting = false;
            _scheduleNextShortRest();
            
            if (_isLongRestDialogShowing) {
              _isLongRestDialogShowing = false;
              try {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                // 忽略错误
              }
            }
          }
        });
      } else if (_isShortResting) {
        setState(() {
          if (_shortRestSecondsRemaining > 0) {
            _shortRestSecondsRemaining--;
          } else {
            _isShortResting = false;
            _scheduleNextShortRest();
          }
        });
      } else {
        setState(() {
          _sessionStudySeconds++;
          
          if (_isFreeMode) {
            _elapsedSeconds++;
            if (_elapsedSeconds >= AppConstants.maxStudyMinutes * 60) {
              _completeFreeMode();
              return;
            }
          } else {
            _elapsedSeconds--;
            if (_elapsedSeconds <= 0) {
              _completePresetStudy();
              return;
            }
          }
          
          if (_sessionStudySeconds >= _nextShortRestSeconds && !_isShortResting) {
            _triggerShortRest();
            return;
          }
          
          if (_sessionStudySeconds >= _nextLongRestSeconds && !_isLongResting) {
            _triggerLongRest();
            return;
          }
        });
      }
    });
  }
  
  // 设置下次短休息时间
  void _scheduleNextShortRest() {
    int intervalSeconds = (AppConstants.shortRestMinIntervalMinutes + 
        _random.nextInt(AppConstants.shortRestMaxIntervalMinutes - AppConstants.shortRestMinIntervalMinutes + 1)) * 60;
    _nextShortRestSeconds = _sessionStudySeconds + intervalSeconds;
  }
  
  // 触发短休息提醒
  void _triggerShortRest() {
    if (_isShortResting) return;
    _playShortSound();
    
    setState(() {
      _isShortResting = true;
      _shortRestSecondsRemaining = AppConstants.shortRestDurationSeconds;
      _shortRestCount++;
      _pointsTenths += _cfgShortRest * 10;
      widget.onGlobalTenthsDelta(_cfgShortRest * 10);
      widget.onProjectTenthsDelta(_cfgShortRest * 10);
    });
    
    _addLog('小阶段休息提醒，获得 +${_cfgShortRest} 运', type: LogType.rest);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isShortResting) {
        _showShortRestDialog();
      }
    });
  }
  
  // 显示短休息提示对话框
  void _showShortRestDialog() {
    if (_isShortRestDialogShowing) return;
    
    try {
      _isShortRestDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => CountdownDialog(
          title: '休息一下吧',
          icon: Icons.spa,
          iconColor: Colors.green,
          message: '放松一下，让大脑休息片刻',
          initialSeconds: _shortRestSecondsRemaining,
          speedMultiplier: _speedMultiplier,
          onFinish: () {
            if (Navigator.canPop(dialogContext)) {
              Navigator.of(dialogContext).pop();
            }
          },
        ),
      ).then((_) {
        _isShortRestDialogShowing = false;
      });
    } catch (e) {
      _isShortRestDialogShowing = false;
    }
  }

  // 手动停止学习（自由模式）
  void _stopFreeMode() {
    _timer?.cancel();
    
    int studiedMinutes = (_sessionStudySeconds / 60).floor();
    
    setState(() {
      _isStudying = false;
      _isShortResting = false;
      _isLongResting = false;
      _isLongRestDialogShowing = false;
      _isShortRestDialogShowing = false;
      // 将本次会话分钟并入本页面的项目快照，清零会话分钟，避免本页展示重复累加
      _baseProjectStudyMinutes += studiedMinutes;
      _sessionStudySeconds = 0;
    });
    
    // 自由模式分钟已在每分钟实时回调中累计到项目，勿再重复结算
    
    _addLog('结束自由模式学习，学习时长: $studiedMinutes 分钟', type: LogType.info);
    
    _showFreeCompleteDialog(studiedMinutes);
  }
  
  // 自由模式达到上限自动完成
  void _completeFreeMode() {
    _timer?.cancel();
    
    int studiedMinutes = (_sessionStudySeconds / 60).floor();
    
    setState(() {
      _isStudying = false;
      _isShortResting = false;
      _isLongResting = false;
      _isLongRestDialogShowing = false;
      _isShortRestDialogShowing = false;
      // 将本次会话分钟并入本页面的项目快照，清零会话分钟
      _baseProjectStudyMinutes += studiedMinutes;
      _sessionStudySeconds = 0;
    });
    
    // 自由模式分钟已在每分钟实时回调中累计到项目，勿再重复结算
    
    _addLog('达到学习上限（${AppConstants.maxStudyMinutes}分钟），学习时长: $studiedMinutes 分钟', type: LogType.success);
    
    _showFreeTimeReachedDialog(studiedMinutes);
  }
  
  // 手动停止学习（预设模式 - 未完成）
  void _stopPresetMode() {
    _timer?.cancel();
    
    setState(() {
      _isStudying = false;
      _isShortResting = false;
      _isLongResting = false;
      _isLongRestDialogShowing = false;
      _isShortRestDialogShowing = false;
    });
    
    _showPresetIncompleteDialog();
  }
  
  // 完成预设学习任务
  void _completePresetStudy() {
    _timer?.cancel();
    
    int studiedMinutes = (_sessionStudySeconds / 60).floor();
    
    setState(() {
      _isStudying = false;
      _isShortResting = false;
      _isLongResting = false;
      _isLongRestDialogShowing = false;
      _isShortRestDialogShowing = false;
      _totalStudyMinutes += studiedMinutes;
      _pointsTenths += AppConstants.pointsForPresetComplete * 10; // 本次奖励计入本次运
    });

    // 将完成奖励同步到全局与项目累计运
    widget.onGlobalTenthsDelta(AppConstants.pointsForPresetComplete * 10);
    widget.onProjectTenthsDelta(AppConstants.pointsForPresetComplete * 10);
    
    // 通知主页更新项目累计学习时长（运已实时同步）
    widget.onStudyComplete(studiedMinutes, 0);
    // 更新本页副标题快照，让用户在本页也能看到最新累计分钟
    setState(() {
      _baseProjectStudyMinutes += studiedMinutes;
      _sessionStudySeconds = 0; // 结束后本次增量清零
    });
    
    _addLog('完成预设学习任务，获得 +${AppConstants.pointsForPresetComplete} 运，学习时长: $studiedMinutes 分钟', type: LogType.success);
    
    _showPresetCompleteDialog(studiedMinutes);
  }
  
  // 触发长休息
  void _triggerLongRest() {
    if (_isLongResting) return;
    
    _playLongSound();
    
    setState(() {
      _isShortResting = false;
      _isLongResting = true;
      _longRestSecondsRemaining = _longRestSeconds;
      _longRestCount++;
      _pointsTenths += _cfgLongRest * 10;
      widget.onGlobalTenthsDelta(_cfgLongRest * 10);
      widget.onProjectTenthsDelta(_cfgLongRest * 10);
    });
    
    _nextLongRestSeconds = _sessionStudySeconds + _longRestInterval;
    
    _addLog('完成90分钟大阶段学习，获得 +${_cfgLongRest} 运', type: LogType.success);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isLongResting) {
        _showLongRestDialog();
      }
    });
  }
  
  // 播放2秒提示音
  void _playLongSound() {
    _playLongAsset();
  }

  // 读取用户选择的提示音（短/长）
  Future<void> _loadSoundSelections() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _shortSoundIndex = sp.getInt('sound_short_index') ?? 1;
      final loadedLong = sp.getInt('sound_long_index') ?? 1;
      _longSoundIndex = loadedLong.clamp(1, 4);
    } catch (_) {}
  }

  // 资产路径候选（允许 mp3 或 wav）
  List<String> _assetCandidatesShort(int idx) => [
        'assets/sounds/s$idx.mp3',
        'assets/sounds/s$idx.wav',
      ];
  List<String> _assetCandidatesLong(int idx) => [
        'assets/sounds/l$idx.mp3',
        'assets/sounds/l$idx.wav',
      ];

  // 确认 bundle 是否能加载该资产键
  Future<bool> _debugAssetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  // 将 bundle 键转换为 AssetSource 需要的相对路径（去掉 assets/ 前缀）
  String _toPlayerAsset(String p) {
    return p.startsWith('assets/') ? p.substring(7) : p;
  }

  Future<void> _playShortSound() async {
    try {
      await _shortPlayer.stop();
      bool played = false;
      for (final path in _assetCandidatesShort(_shortSoundIndex)) {
        final exists = await _debugAssetExists(path);
        if (!exists) continue;
        try {
          final playPath = _toPlayerAsset(path);
          await _shortPlayer.play(AssetSource(playPath));
          played = true;
          break;
        } catch (_) {}
      }
      if (!played) throw Exception('no asset');
    } catch (_) {
      // 资产不存在或未声明时，回退系统提示音
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> _playLongAsset() async {
    try {
      await _longPlayer.stop();
      bool played = false;
      for (final path in _assetCandidatesLong(_longSoundIndex)) {
        final exists = await _debugAssetExists(path);
        if (!exists) continue;
        try {
          final playPath = _toPlayerAsset(path);
          await _longPlayer.play(AssetSource(playPath));
          played = true;
          break;
        } catch (_) {}
      }
      if (!played) throw Exception('no asset');
    } catch (_) {
      // 回退为多次系统提示音
      SystemSound.play(SystemSoundType.alert);
      _soundTimer = Timer(const Duration(milliseconds: 500), () {
        SystemSound.play(SystemSoundType.alert);
      });
      Timer(const Duration(seconds: 1), () {
        SystemSound.play(SystemSoundType.alert);
      });
      Timer(const Duration(milliseconds: 1500), () {
        SystemSound.play(SystemSoundType.alert);
      });
    }
  }
  
  // 显示长休息对话框
  void _showLongRestDialog() {
    if (_isLongRestDialogShowing) return;
    
    try {
      _isLongRestDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => CountdownDialog(
          title: '完成大阶段学习！',
          icon: Icons.celebration,
          iconColor: Colors.purple,
          message: '恭喜完成90分钟学习！\n获得运: +${_cfgLongRest}',
          initialSeconds: _longRestSecondsRemaining,
          speedMultiplier: _speedMultiplier,
          isLongRest: true,
          onFinish: () {
            if (Navigator.canPop(dialogContext)) {
              Navigator.of(dialogContext).pop();
            }
          },
        ),
      ).then((_) {
        _isLongRestDialogShowing = false;
      });
    } catch (e) {
      _isLongRestDialogShowing = false;
    }
  }
  
  // 显示错误对话框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('错误'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  // 显示预设时间对话框
  void _showPresetTimeDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置学习时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入学习时间（分钟）'),
            Text(
              '必须大于等于${AppConstants.minPresetMinutes}分钟，小于等于${AppConstants.maxPresetMinutes}分钟（12小时）',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '分钟数',
                border: OutlineInputBorder(),
                suffixText: '分钟',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final int? minutes = int.tryParse(controller.text);
              if (minutes == null || minutes < AppConstants.minPresetMinutes || minutes > AppConstants.maxPresetMinutes) {
                _showErrorDialog('请输入大于等于${AppConstants.minPresetMinutes}且小于等于${AppConstants.maxPresetMinutes}的分钟数');
                return;
              }
              Navigator.of(context).pop();
              _startPresetMode(minutes);
            },
            child: const Text('开始'),
          ),
        ],
      ),
    );
  }
  
  // 各种完成对话框（精简版，只保留核心逻辑）
  void _showFreeTimeReachedDialog([int? studiedMinutesArg]) {
    int studiedMinutes = studiedMinutesArg ?? (_sessionStudySeconds / 60).floor();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.access_time_filled, color: Colors.orange, size: 30),
            SizedBox(width: 10),
            Text('已达学习上限！'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('恭喜你已持续学习5天（${AppConstants.maxStudyMinutes}分钟）！',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('本次学习时长: $studiedMinutes 分钟'),
            Text('小阶段休息: $_shortRestCount 次（+${_shortRestCount}运）'),
            Text('大阶段休息: $_longRestCount 次（+${_longRestCount * _cfgLongRest}运）'),
            Text('每分钟运: +${(_sessionTotalSeconds ~/ 60 * 0.1).toStringAsFixed(1)}运'),
            const SizedBox(height: 10),
            Text('已计入学习总时长', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('是时候好好休息一下了！', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
  
  void _showFreeCompleteDialog([int? studiedMinutesArg]) {
    int studiedMinutes = studiedMinutesArg ?? (_sessionStudySeconds / 60).floor();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('学习完成'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('学习时长: $studiedMinutes 分钟'),
            Text('小阶段休息: $_shortRestCount 次（+${_shortRestCount}运）'),
            Text('大阶段休息: $_longRestCount 次（+${_longRestCount * _cfgLongRest}运）'),
            Text('每分钟运: +${(_sessionTotalSeconds ~/ 60 * 0.1).toStringAsFixed(1)}运'),
            const SizedBox(height: 10),
            Text('已计入学习总时长', style: TextStyle(color: Colors.green[700])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  void _showPresetCompleteDialog([int? studiedMinutesArg]) {
    int studiedMinutes = studiedMinutesArg ?? (_sessionStudySeconds / 60).floor();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text('任务完成！'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('学习时长: $studiedMinutes 分钟'),
            Text('小阶段休息: $_shortRestCount 次（+${_shortRestCount}运）'),
            Text('大阶段休息: $_longRestCount 次（+${_longRestCount * _cfgLongRest}运）'),
            Text('每分钟运: +${(_sessionTotalSeconds ~/ 60 * 0.1).toStringAsFixed(1)}运'),
            Text('完成奖励: +${AppConstants.pointsForPresetComplete}运'),
            const SizedBox(height: 10),
            Text('已计入学习总时长', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('太棒了！'),
          ),
        ],
      ),
    );
  }
  
  void _showPresetIncompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 30),
            SizedBox(width: 10),
            Text('任务未完成'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('此次学习任务未完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('小阶段休息: $_shortRestCount 次（+${_shortRestCount}运）'),
            Text('大阶段休息: $_longRestCount 次（+${_longRestCount * _cfgLongRest}运）'),
            Text('每分钟运: +${(_sessionTotalSeconds ~/ 60 * 0.1).toStringAsFixed(1)}运'),
            const SizedBox(height: 10),
            Text('未计入学习总时长', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  double _getCurrentProgress() {
    if (_isFreeMode) {
      return 0.0;
    } else {
      return 1.0 - (_elapsedSeconds / (_presetMinutes * 60));
    }
  }

  // 显示奖励设置对话框
  void _showRewardSettingsDialog() {
    final TextEditingController shortCtl = TextEditingController(text: _cfgShortRest.toString());
    final TextEditingController longCtl = TextEditingController(text: _cfgLongRest.toString());
    final TextEditingController perMinCtl = TextEditingController(text: (_cfgPerMinuteTenths / 10.0).toStringAsFixed(1));

    void applyToProject(int shortVal, int longVal, int perMinuteTenths) {
      setState(() {
        widget.project.rewardShortRest = shortVal;
        widget.project.rewardLongRest = longVal;
        widget.project.rewardPerMinuteTenths = perMinuteTenths;
      });
      _addLog('更新奖励：短+$shortVal，长+$longVal，每分钟+${(perMinuteTenths/10.0).toStringAsFixed(1)}运', type: LogType.info);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, size: 28),
            SizedBox(width: 8),
            Text('奖励额度设置'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('范围：短休 1-10、长休 20-100、每分钟 0.1-3.0'),
            const SizedBox(height: 12),
            TextField(
              controller: shortCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '短休每次奖励（整数）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: longCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '长休每次奖励（整数）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: perMinCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '每分钟奖励（1位小数）', border: OutlineInputBorder(), suffixText: '运/分钟'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 恢复默认（清除项目覆盖）
              setState(() {
                widget.project.rewardShortRest = null;
                widget.project.rewardLongRest = null;
                widget.project.rewardPerMinuteTenths = null;
              });
              Navigator.of(context).pop();
            },
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: () {
              final int? s = int.tryParse(shortCtl.text);
              final int? l = int.tryParse(longCtl.text);
              double? pm = double.tryParse(perMinCtl.text);
              if (s == null || s < 1 || s > 10) { _showErrorDialog('短休范围 1-10'); return; }
              if (l == null || l < 20 || l > 100) { _showErrorDialog('长休范围 20-100'); return; }
              if (pm == null) { _showErrorDialog('每分钟请输入数字'); return; }
              pm = double.parse(pm.toStringAsFixed(1));
              if (pm < 0.1 || pm > 3.0) { _showErrorDialog('每分钟范围 0.1-3.0'); return; }
              final int pmTenths = (pm * 10).round();
              applyToProject(s, l, pmTenths);
              Navigator.of(context).pop();
            },
            child: const Text('应用'),
          ),
          ElevatedButton(
            onPressed: () {
              final int? s = int.tryParse(shortCtl.text);
              final int? l = int.tryParse(longCtl.text);
              double? pm = double.tryParse(perMinCtl.text);
              if (s == null || s < 1 || s > 10) { _showErrorDialog('短休范围 1-10'); return; }
              if (l == null || l < 20 || l > 100) { _showErrorDialog('长休范围 20-100'); return; }
              if (pm == null) { _showErrorDialog('每分钟请输入数字'); return; }
              pm = double.parse(pm.toStringAsFixed(1));
              if (pm < 0.1 || pm > 3.0) { _showErrorDialog('每分钟范围 0.1-3.0'); return; }
              final int pmTenths = (pm * 10).round();
              applyToProject(s, l, pmTenths);
              widget.onApplyGlobalRewards?.call(s, l, pmTenths);
              Navigator.of(context).pop();
            },
            child: const Text('全局应用'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project.name),
            const SizedBox(height: 2),
            Text(
              '累计: $_projectTotalMinutes 分钟 / ${_projectTotalPoints.toStringAsFixed(1)} 运',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isStudying) {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('确认退出'),
                  content: const Text('正在学习中，确定要退出吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.of(context).pop();
            }
          },
          tooltip: '返回',
        ),
        actions: [
          // 调试菜单按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showRewardSettingsDialog,
            tooltip: '奖励设置',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              setState(() {
                _showDebugMenu = !_showDebugMenu;
              });
            },
            tooltip: '调试菜单',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                '运: ${_displayGlobalPoints.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // 调试菜单
                  if (_showDebugMenu) ...[
                    DebugMenu(
                      speedMultiplier: _speedMultiplier,
                      isStudying: _isStudying,
                      onSpeedChange: (speed) {
                        setState(() {
                          _speedMultiplier = speed;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                   // 顶部副标题已显示项目累计，页内不再重复展示
                  
                  // 长休息界面
                  if (_isLongResting) ...[
                    const Icon(Icons.bedtime, size: 120, color: Colors.purple),
                    const SizedBox(height: 20),
                    const Text('长休息中', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.purple)),
                    const SizedBox(height: 10),
                    Text(
                      TimeFormatter.formatTime(_longRestSecondsRemaining),
                      style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: LinearProgressIndicator(
                        value: 1.0 - (_longRestSecondsRemaining / _longRestSeconds),
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${((1.0 - (_longRestSecondsRemaining / _longRestSeconds)) * 100).toStringAsFixed(0)}% 完成',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    const Text('好好休息，恢复精力', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ] else ...[
                    // 学习界面
                    Icon(
                      _isStudying ? Icons.timer : Icons.timer_off,
                      size: 100,
                      color: _isStudying ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 20),
                    
                    if (_isStudying) ...[
                      if (_isShortResting) ...[
                        const Icon(Icons.spa, size: 80, color: Colors.orange),
                        const SizedBox(height: 10),
                        const Text('休息中...', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                        const SizedBox(height: 10),
                        Text(
                          '$_shortRestSecondsRemaining 秒',
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ] else ...[
                        Text(
                          TimeFormatter.formatTime(_elapsedSeconds),
                          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        const SizedBox(height: 10),
                        if (!_isFreeMode) ...[
                          Text('学习进度', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          const SizedBox(height: 5),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: LinearProgressIndicator(
                              value: _getCurrentProgress(),
                              minHeight: 8,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${(_getCurrentProgress() * 100).toStringAsFixed(0)}% 完成',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ] else ...[
                      Text('准备开始', style: Theme.of(context).textTheme.headlineMedium),
                    ],
                  ],
                  
                  const SizedBox(height: 20),
                  if (!_isLongResting) ...[
                    const SizedBox(height: 40),
                    
                    if (!_isStudying) ...[
                      Container(
                        key: _freeBtnKey, // 用容器包裹，确保有明确的可高亮区域
                        child: ElevatedButton(
                          onPressed: _startFreeMode,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                            backgroundColor: Colors.blue,
                            textStyle: const TextStyle(fontSize: 20),
                          ),
                          child: const Text('开始专注'),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        key: _presetBtnKey, // 同理包裹“预设时间”按钮
                        child: ElevatedButton(
                          onPressed: () => _showPresetTimeDialog(),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                            backgroundColor: Colors.green,
                            textStyle: const TextStyle(fontSize: 20),
                          ),
                          child: const Text('预设时间'),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _isFreeMode ? _stopFreeMode : _stopPresetMode,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                          backgroundColor: Colors.orange,
                          textStyle: const TextStyle(fontSize: 20),
                        ),
                        child: const Text('结束专注'),
                      ),
                    ],
                    const SizedBox(height: 30),
                  ] else ...[
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLongResting = false;
                              _scheduleNextShortRest();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            backgroundColor: Colors.grey,
                          ),
                          child: const Text('跳过休息'),
                        ),
                        const SizedBox(width: 15),
                        ElevatedButton(
                          onPressed: _isFreeMode ? _stopFreeMode : _stopPresetMode,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('结束学习'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                  
                  // 已移除底部“当前运”卡片，统一使用顶部总运显示
                ],
              ),
            ),
          ),
          // 日志按钮
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.history, size: 28),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LogScreen(logs: _logs),
                  ),
                );
              },
              tooltip: '日志',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                elevation: 2,
                shadowColor: Colors.black26,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _maybeShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getBool('onboarding_study_v1') ?? false;
      if (shown) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targets = <TargetFocus>[
          TargetFocus(
            identify: 'free',
            keyTarget: _freeBtnKey,
            shape: ShapeLightFocus.RRect,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                builder: (context, controller) => _buildGuideCard(
                  '自由模式',
                  '每3–5分钟休息10秒，90分钟休息20分钟；休息后自动继续，更高效！',
                ),
              ),
            ],
          ),
          TargetFocus(
            identify: 'preset',
            keyTarget: _presetBtnKey,
            shape: ShapeLightFocus.RRect,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                builder: (context, controller) => _buildGuideCard(
                  '预设模式',
                  '任务未完成不计入学习时长；完成后一次性结算。',
                ),
              ),
            ],
          ),
        ];
        _coach = TutorialCoachMark(
          targets: targets,
          textSkip: '跳过',
          hideSkip: false,
          colorShadow: Colors.black54,
          onClickTarget: (target) {},
          onClickOverlay: (target) {},
          onFinish: () => _markStudyOnboardingShown(),
          onSkip: () { _markStudyOnboardingShown(); return true; },
        );
        _coach!.show(context: context);
      });
    } catch (_) {}
  }

  Future<void> _markStudyOnboardingShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_study_v1', true);
    } catch (_) {}
  }

  Widget _buildGuideCard(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

