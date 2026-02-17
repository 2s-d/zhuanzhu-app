import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/fortune.dart';
import 'home_screen.dart';
import 'log_screen.dart';
import '../models/log_entry.dart';
import 'user_screen.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data_repository.dart';

// 主页面（项目列表 + 今日运势）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Project> _projects = []; // 用户的学习项目列表
  int _globalPointsTenths = 1000; // 全局运（100.0运）
  final List<LogEntry> _globalLogs = []; // 全局日志
  DailyFortune? _todayFortune; // 今日运势
  DateTime? _lastCheckInDate; // 上次签到日期
  DateTime? _lastFortuneDate; // 上次抽运势的日期
  int _consecutiveCheckInDays = 0; // 连续签到天数
  // 主题色（示例：使用种子色快速预览应用主色调）
  Color _seedColor = Colors.blue;
  // 新手引导
  final GlobalKey _checkInKey = GlobalKey();
  final GlobalKey _fortuneKey = GlobalKey();
  final GlobalKey _userKey = GlobalKey();
  final GlobalKey _createProjectKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;
  
  double get _globalPoints => _globalPointsTenths / 10.0;
  Color get _appBarColor => ColorScheme.fromSeed(seedColor: _seedColor).inversePrimary;

  @override
  void initState() {
    super.initState();
    _initLoad();
    _maybeShowOnboarding();
  }

  Future<void> _initLoad() async {
    // 可通过 dart-define 开关控制（开发模式默认关闭，发布时显式开启）
    const enablePersistence = bool.fromEnvironment('ENABLE_PERSISTENCE', defaultValue: false);
    if (!enablePersistence) return;
    final repo = DataRepository.instance;
    final data = await repo.load();
    setState(() {
      _globalPointsTenths = data.globalPointsTenths;
      _projects
        ..clear()
        ..addAll(data.projects);
      _lastCheckInDate = data.lastCheckInDate;
      _lastFortuneDate = data.lastFortuneDate;
      _consecutiveCheckInDays = data.consecutiveCheckInDays ?? 0;
      if (data.themeSeedColorValue != null) {
        _seedColor = Color(data.themeSeedColorValue!);
      }
      // 加载今日运势（如果日期匹配则恢复，否则清空）
      if (data.todayFortune != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final fortuneDate = DateTime(data.todayFortune!.date.year, data.todayFortune!.date.month, data.todayFortune!.date.day);
        if (fortuneDate == today) {
          _todayFortune = data.todayFortune;
        } else {
          // 跨天了，清空运势
          _todayFortune = null;
        }
      }
    });
  }

  Future<void> _saveNow() async {
    // 开发模式默认关闭持久化，发布时显式开启
    const enablePersistence = bool.fromEnvironment('ENABLE_PERSISTENCE', defaultValue: false);
    if (!enablePersistence) return;
    final repo = DataRepository.instance;
    final data = AppData(
      globalPointsTenths: _globalPointsTenths,
      projects: _projects,
      lastCheckInDate: _lastCheckInDate,
      lastFortuneDate: _lastFortuneDate,
      todayFortune: _todayFortune,
      themeSeedColorValue: _seedColor.value,
      consecutiveCheckInDays: _consecutiveCheckInDays,
    );
    await repo.save(data);
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
            content: const Text('您今天已经签到过了\n明天再来吧！', style: TextStyle(fontSize: 16)),
          ),
        );
        return;
      }
    }
    
    _performCheckIn();
  }
  
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
    
    final earnedPoints = missedDays * 30;
    
    // 更新连续签到天数
    if (missedDays == 1) {
      // 连续签到，天数 +1
      _consecutiveCheckInDays = (_consecutiveCheckInDays ?? 0) + 1;
    } else {
      // 有漏签，重置为 1
      _consecutiveCheckInDays = 1;
    }
    
    setState(() {
      _globalPointsTenths += earnedPoints * 10;
      _lastCheckInDate = now;
      _consecutiveCheckInDays = _consecutiveCheckInDays;
    });
    _saveNow();
    
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
            const Text('还活着就很幸运了', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (missedDays == 1)
              const Text('签到 1 天', style: TextStyle(fontSize: 16))
            else
              Text('补签 $missedDays 天', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text('获得 +$earnedPoints 运', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 10),
            const Text('越努力越幸运', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // 创建新项目
  void _showCreateProjectDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建学习项目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入你要学习的内容'),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '项目名称',
                hintText: '例如：学习编程',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
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
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _projects.add(Project(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: controller.text.trim(),
                    createdAt: DateTime.now(),
                  ));
                });
                _saveNow();
                Navigator.of(context).pop();
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  // 打开学习页面
  void _openStudyScreen(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudyScreen(
          project: project,
          globalPoints: _globalPoints, // 初始全局总运（用于子页展示）
          onApplyGlobalRewards: (int shortRest, int longRest, int perMinuteTenths) {
            // 全局应用：将奖励配置应用到所有项目
            setState(() {
              for (final p in _projects) {
                p.rewardShortRest = shortRest;
                p.rewardLongRest = longRest;
                p.rewardPerMinuteTenths = perMinuteTenths;
              }
            });
            _saveNow();
          },
          onGlobalTenthsDelta: (int deltaTenths) {
            // 学习过程中的实时全局运变更
            setState(() {
              _globalPointsTenths += deltaTenths;
            });
            _saveNow();
          },
          onProjectTenthsDelta: (int deltaTenths) {
            setState(() {
              project.totalPointsTenths += deltaTenths;
            });
            _saveNow();
          },
          onProjectMinutesDelta: (int deltaMinutes) {
            // 自由模式：学习分钟实时计入项目累计，保证中断也不丢失
            setState(() {
              project.totalStudyMinutes += deltaMinutes;
            });
            _saveNow();
          },
          onStudyComplete: (studyMinutes, earnedPoints) {
            // 学习完成后仅更新项目数据（全局运已在实时回调中累加过）
            setState(() {
              project.totalStudyMinutes += studyMinutes;
            });
            _saveNow();
          },
          onRequestSave: _saveNow,
        ),
      ),
    );
  }

  // 抽取今日运势
  void _drawFortune() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 检查今天是否已经抽过运势
    if (_lastFortuneDate != null) {
      final lastDraw = DateTime(_lastFortuneDate!.year, _lastFortuneDate!.month, _lastFortuneDate!.day);
      if (lastDraw == today && _todayFortune != null) {
        // 今天已经抽过，哥不允许重新抽取
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 30),
                SizedBox(width: 10),
                Text('提示'),
              ],
            ),
            content: Text(
              '今日运势已抽取：${_todayFortune!.level.name}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
        return;
      }
    }
    
    setState(() {
      _todayFortune = DailyFortune.generate();
      _lastFortuneDate = now;
    });
    _saveNow();
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _todayFortune!.level == FortuneLevel.daJi
                  ? Icons.star
                  : _todayFortune!.level == FortuneLevel.xiaoJi
                      ? Icons.star_half
                      : Icons.star_border,
              color: Colors.amber,
              size: 30,
            ),
            const SizedBox(width: 10),
            const Text('今日运势'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _todayFortune!.level.name,
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            const SizedBox(height: 20),
            Text(
              _todayFortune!.message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 每次进入或重建时，确保“今日运势”与当前日期一致：
    // 如果跨天了，则重置为可抽取状态
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastFortuneDate != null && _todayFortune != null) {
      final last = DateTime(_lastFortuneDate!.year, _lastFortuneDate!.month, _lastFortuneDate!.day);
      if (last != today) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _todayFortune = null;
              _lastFortuneDate = null;
            });
          }
        });
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('专注'),
            const SizedBox(width: 8),
            IconButton(
              key: _userKey,
              icon: const Icon(Icons.person_outline),
              tooltip: '用户',
              onPressed: _openUserScreen,
            ),
          ],
        ),
        backgroundColor: _appBarColor,
        actions: [
          IconButton(
            key: _checkInKey,
            icon: const Icon(Icons.calendar_today),
            onPressed: _showCheckInDialog,
            tooltip: '签到',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                '运: ${_globalPoints.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 上2/3: 项目列表区域
          Expanded(
            flex: 2,
            child: _projects.isEmpty
                ? _buildEmptyProjectList()
                : _buildProjectList(),
          ),
          
          // 下1/3: 今日运势
          Expanded(
            flex: 1,
            child: _buildFortuneSection(),
          ),
        ],
      ),
    );
  }

  // 打开用户页面（主题色/花掉运）
  void _openUserScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserScreen(
          seedColor: _seedColor,
          currentPoints: _globalPointsTenths,
          projects: _projects,
          lastCheckInDate: _lastCheckInDate,
          consecutiveCheckInDays: _consecutiveCheckInDays,
          onApplyTheme: (Color newSeed) {
            setState(() {
              _seedColor = newSeed;
            });
            _saveNow();
          },
          onSpendTenths: (int tenthsToSpend) {
            if (tenthsToSpend <= 0) return;
            setState(() {
              _globalPointsTenths = (_globalPointsTenths - tenthsToSpend).clamp(0, 1 << 30);
            });
            _saveNow();
          },
        ),
      ),
    );
  }

  // 空项目列表（新用户）
  Widget _buildEmptyProjectList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            '还没有学习项目',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            key: _createProjectKey,
            onPressed: _showCreateProjectDialog,
            icon: const Icon(Icons.add),
            label: const Text('创建项目'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  // 项目列表（老用户）- 格子状排列
  Widget _buildProjectList() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 每行2个
        crossAxisSpacing: 12, // 横向间距
        mainAxisSpacing: 12, // 纵向间距
        childAspectRatio: 1.1, // 宽高比
      ),
      itemCount: _projects.length + 1, // +1 for add button
      itemBuilder: (context, index) {
        if (index == _projects.length) {
          // 添加按钮
          return Card(
            elevation: 2,
            child: InkWell(
              onTap: _showCreateProjectDialog,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 48, color: Colors.blue[700]),
                  const SizedBox(height: 8),
                  Text(
                    '创建项目',
                    style: TextStyle(fontSize: 16, color: Colors.blue[700], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }
        
        final project = _projects[index];
        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () => _openStudyScreen(project),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.book, color: Colors.blue[700], size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          project.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${project.totalStudyMinutes}分钟',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${(project.totalPointsTenths / 10).toStringAsFixed(1)}运',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 今日运势区域
  Widget _buildFortuneSection() {
    return Container(
      key: _fortuneKey,
      margin: const EdgeInsets.all(16), // 外边距
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(24), // 圆角
        border: Border.all(
          color: Colors.purple.withOpacity(0.3), // 边框颜色
          width: 3, // 更宽的边框
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          const Text(
            '今日运势',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
          ),
          const SizedBox(height: 15),
          if (_todayFortune == null)
            ElevatedButton.icon(
              onPressed: _drawFortune,
              icon: const Icon(Icons.auto_awesome, size: 24),
              label: const Text('抽取运势'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.withOpacity(0.2), width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _todayFortune!.level.name,
                          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _todayFortune!.message,
                          style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '明天再来吧',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // 首次进入显示“签到”与“今日运势”的引导
  Future<void> _maybeShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getBool('onboarding_main_v1') ?? false;
      if (shown) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTutorial();
      });
    } catch (_) {
      // 忽略错误（不影响正常使用）
    }
  }

  void _showTutorial() {
    final targets = <TargetFocus>[
      TargetFocus(
        identify: "check_in",
        keyTarget: _checkInKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildGuideCard(
                title: '签到',
                message: '每日手动签到可获得运（支持补签）。点击任意处继续。',
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "fortune",
        keyTarget: _fortuneKey,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildGuideCard(
                title: '今日运势',
                message: '每天可抽取一次运势，次日重置为“可抽取”。点击任意处结束引导。',
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "user",
        keyTarget: _userKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildGuideCard(
                title: '用户中心',
                message: '进入用户页面可更改主题颜色，并查看“消耗运”示例说明。',
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "create_project",
        keyTarget: _createProjectKey,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildGuideCard(
                title: '创建项目',
                message: '点击这里创建你的第一个学习项目，开始专注学习吧！',
              );
            },
          ),
        ],
      ),
    ];

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      textSkip: '跳过',
      hideSkip: false,
      colorShadow: Colors.black.withOpacity(0.6),
      onClickTarget: (target) {},
      onClickOverlay: (target) {},
      onFinish: _markOnboardingShown,
      onSkip: () { _markOnboardingShown(); return true; },
    );
    _tutorialCoachMark!.show(context: context);
  }

  Future<void> _markOnboardingShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_main_v1', true);
    } catch (_) {}
  }

  Widget _buildGuideCard({required String title, required String message}) {
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
          Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}

