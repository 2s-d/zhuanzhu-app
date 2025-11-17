import 'package:flutter/material.dart';
import 'dart:async';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class UserScreen extends StatefulWidget {
  final Color seedColor;
  final int currentPoints; // 以0.1为单位的运
  final void Function(Color newSeed) onApplyTheme;
  final void Function(int spendTenths) onSpendTenths;

  const UserScreen({
    super.key,
    required this.seedColor,
    required this.currentPoints,
    required this.onApplyTheme,
    required this.onSpendTenths,
  });

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late Color _previewSeed;
  final TextEditingController _spendController = TextEditingController();
  late int _pointsTenths; // 本页实时可用运（0.1为单位）
  final GlobalKey _spendKey = GlobalKey();
  TutorialCoachMark? _coach;
  // 提示音选择与预览
  int _shortSoundIndex = 1; // 1~5
  int _longSoundIndex = 2;  // 1~5
  final AudioPlayer _previewPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  final List<Color> _palette = const [
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.indigo,
    Colors.red,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _previewSeed = widget.seedColor;
    _pointsTenths = widget.currentPoints;
    _maybeShowOnboarding();
    _loadSoundSelections();
  }

  @override
  void dispose() {
    _spendController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: _previewSeed);
    final available = (_pointsTenths / 10.0).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('用户'),
        backgroundColor: scheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('主题颜色', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _palette.map((c) {
                final selected = c.value == _previewSeed.value;
                return GestureDetector(
                  onTap: () => setState(() => _previewSeed = c),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black : Colors.white,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => widget.onApplyTheme(_previewSeed),
                  icon: const Icon(Icons.check),
                  label: const Text('应用主题'),
                ),
                const SizedBox(width: 10),
                Text('预览色：', style: TextStyle(color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('提示音', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            _buildSoundRow(
              title: '短休提示音（3~5分钟）',
              value: _shortSoundIndex,
              onChanged: (v) => _updateShortSound(v),
              onPreview: () => _previewShortAsset(_shortSoundIndex),
              itemsCount: 5,
            ),
            const SizedBox(height: 10),
            _buildSoundRow(
              title: '长休提示音（90分钟）',
              value: _longSoundIndex,
              onChanged: (v) => _updateLongSound(v),
              onPreview: () => _previewLongAsset(_longSoundIndex),
              itemsCount: 4,
            ),
            const SizedBox(height: 24),
            // 用容器包裹整个“消耗运”区域以确保高亮能准确框住
            Container(
              key: _spendKey,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('消耗  运', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('运：$available', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _quickSpendButton(10), // 10运
                      _quickSpendButton(30),
                      _quickSpendButton(100),
                      _quickSpendButton(200),
                      _quickSpendButton(500),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text('提示：该页面只是轮廓示例，后续可扩展用户资料、皮肤商城等。', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getBool('onboarding_user_v1') ?? false;
      if (shown) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targets = <TargetFocus>[
          TargetFocus(
            identify: 'spend',
            keyTarget: _spendKey,
            shape: ShapeLightFocus.RRect,
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                builder: (context, controller) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('消耗运', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('何种情况下会消耗掉运取决于自己', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  );
                },
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
          onFinish: () async {
            final p = await SharedPreferences.getInstance();
            await p.setBool('onboarding_user_v1', true);
          },
          onSkip: () {
            SharedPreferences.getInstance().then((p) {
              p.setBool('onboarding_user_v1', true);
            });
            return true;
          },
        );
        _coach!.show(context: context);
      });
    } catch (_) {}
  }

  // ========== 提示音设置 ==========
  List<String> _assetCandidatesForShort(int idx) => [
        'assets/sounds/s$idx.mp3',
        'assets/sounds/s$idx.wav',
      ];
  List<String> _assetCandidatesForLong(int idx) => [
        'assets/sounds/l$idx.mp3',
        'assets/sounds/l$idx.wav',
      ];

  Future<void> _loadSoundSelections() async {
    try {
      final sp = await SharedPreferences.getInstance();
      setState(() {
        _shortSoundIndex = sp.getInt('sound_short_index') ?? 1;
        final loadedLong = sp.getInt('sound_long_index') ?? 2;
        // 长音只有 1~4，做个容错裁剪
        _longSoundIndex = loadedLong.clamp(1, 4);
      });
    } catch (_) {}
  }

  Future<void> _updateShortSound(int v) async {
    setState(() => _shortSoundIndex = v);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt('sound_short_index', v);
    } catch (_) {}
  }

  Future<void> _updateLongSound(int v) async {
    setState(() => _longSoundIndex = v);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt('sound_long_index', v);
    } catch (_) {}
  }

  Future<bool> _debugAssetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }
  Future<void> _previewByCandidates(List<String> candidates) async {
    try {
      await _previewPlayer.stop();
    } catch (_) {}
    bool played = false;
    String _toPlayerAsset(String p) {
      // audioplayers 的 AssetSource 会在内部加上 "assets/" 前缀
      // 若我们再传 "assets/..." 则会变成 "assets/assets/..."
      return p.startsWith('assets/') ? p.substring(7) : p;
    }
    for (final path in candidates) {
      final exists = await _debugAssetExists(path);
      if (!exists) {
        continue;
      }
      try {
        final playPath = _toPlayerAsset(path);
        await _previewPlayer.play(AssetSource(playPath));
        played = true;
        break;
      } catch (_) {}
    }
    if (!played) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到本地提示音资产，已回退系统音效'), duration: Duration(seconds: 2)),
        );
      }
      SystemSound.play(SystemSoundType.alert);
    }
  }
  Future<void> _previewShortAsset(int idx) => _previewByCandidates(_assetCandidatesForShort(idx));
  Future<void> _previewLongAsset(int idx) => _previewByCandidates(_assetCandidatesForLong(idx));

  Widget _buildSoundRow({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
    required VoidCallback onPreview,
    required int itemsCount,
  }) {
    return Row(
      children: [
        Expanded(child: Text(title)),
        DropdownButton<int>(
          value: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: List.generate(itemsCount, (i) => i + 1).map((i) {
            return DropdownMenuItem(
              value: i,
              child: Text('音色 $i'),
            );
          }).toList(),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onPreview,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('预览'),
        ),
      ],
    );
  }

  Widget _quickSpendButton(int amount) {
    return OutlinedButton(
      onPressed: () {
        _spendFixed(amount);
      },
      child: Text('$amount 运'),
    );
  }

  void _spendFixed(int amount) {
    final int tenths = (amount * 10);
    if (tenths > _pointsTenths) {
      _showToast(context, '可用运不足');
      return;
    }
    setState(() {
      _pointsTenths -= tenths;
    });
    widget.onSpendTenths(tenths); // 通知主页面同步扣减
    _showToast(context, '消耗 ${amount.toStringAsFixed(1).replaceAll('.0', '')} 运');
  }

  void _onSpend() {
    final raw = _spendController.text.trim();
    if (raw.isEmpty) return;
    final double? value = double.tryParse(raw);
    if (value == null || value <= 0) return;
    final int tenths = (value * 10).round();
    if (tenths > widget.currentPoints) {
      _showToast(context, '可用运不足');
      return;
    }
    widget.onSpendTenths(tenths);
    _showToast(context, '已花掉 ${value.toStringAsFixed(1)} 运');
    _spendController.clear();
  }

  void _showToast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}


