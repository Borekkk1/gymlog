import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String exerciseType;
  const ExerciseDetailScreen({super.key, required this.exerciseId, required this.exerciseName, required this.exerciseType});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabs;

  double? _estimated1rm;
  double? _maxWeight;
  double? _maxVolume;
  String? _best1rmDate;
  String? _maxWeightDate;
  List<Map<String, dynamic>> _history = [];
  List<FlSpot> _progressSpots = [];
  String? _muscleGroup;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      // Load exercise metadata
      try {
        final ex = await _supabase
            .from('cwiczenia')
            .select('grupa_miesniowa')
            .eq('id', widget.exerciseId)
            .single();
        _muscleGroup = ex['grupa_miesniowa'] as String?;
      } catch (_) {}

      final series = await _supabase
          .from('serie')
          .select('ciezar, powt, strona, completed_at, trening_id')
          .eq('cwiczenie_id', widget.exerciseId)
          .order('completed_at', ascending: false);

      if (series.isEmpty) { setState(() => _loading = false); return; }

      double best1rm = 0;
      double maxW = 0;
      double maxVol = 0;
      String? best1rmDate;
      String? maxWDate;

      final byDate = <String, List<Map<String, dynamic>>>{};
      for (final s in series) {
        final dt = DateTime.parse(s['completed_at']).toLocal();
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        byDate.putIfAbsent(key, () => []).add(s);

        final w = (s['ciezar'] as num).toDouble();
        final r = (s['powt'] as num).toDouble();
        final orm = w * (1 + r / 30);
        if (orm > best1rm) { best1rm = orm; best1rmDate = s['completed_at']; }
        if (w > maxW) { maxW = w; maxWDate = s['completed_at']; }
        maxVol += w * r;
      }

      final sortedDates = byDate.keys.toList()..sort();
      final spots = <FlSpot>[];
      for (int i = 0; i < sortedDates.length; i++) {
        final daySeries = byDate[sortedDates[i]]!;
        double dayBest = 0;
        for (final s in daySeries) {
          final w = (s['ciezar'] as num).toDouble();
          final r = (s['powt'] as num).toDouble();
          final orm = w * (1 + r / 30);
          if (orm > dayBest) dayBest = orm;
        }
        spots.add(FlSpot(i.toDouble(), double.parse(dayBest.toStringAsFixed(1))));
      }

      final historyByWorkout = <String, List<Map<String, dynamic>>>{};
      for (final s in series) {
        historyByWorkout.putIfAbsent(s['trening_id'] as String, () => []).add(s);
      }
      final historyList = historyByWorkout.entries.map((e) => {
        'trening_id': e.key,
        'date': e.value.first['completed_at'],
        'series': e.value,
      }).toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      setState(() {
        _estimated1rm = best1rm;
        _maxWeight = maxW;
        _maxVolume = maxVol;
        _best1rmDate = best1rmDate;
        _maxWeightDate = maxWDate;
        _history = historyList.cast<Map<String, dynamic>>();
        _progressSpots = spots;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '--';
    final dt = DateTime.parse(iso).toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  double _nRM(double oneRM, int n) => n == 1 ? oneRM : oneRM / (1 + n / 30);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.exerciseName, style: const TextStyle(fontSize: 15)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [Tab(text: 'Stats'), Tab(text: 'History'), Tab(text: 'Guide')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : TabBarView(
              controller: _tabs,
              children: [
                _StatsTab(this),
                _HistoryTab(this),
                _GuideTab(
                  name: widget.exerciseName,
                  type: widget.exerciseType,
                  muscleGroup: _muscleGroup,
                ),
              ],
            ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final _ExerciseDetailScreenState s;
  const _StatsTab(this.s);

  @override
  Widget build(BuildContext context) {
    if (s._estimated1rm == null) {
      return const Center(child: Text('No data yet', style: TextStyle(color: AppTheme.textSecondary)));
    }
    final orm = s._estimated1rm!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ESTIMATED 1 REP MAX', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${orm.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Text(s._fmtDate(s._best1rmDate), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MAX WEIGHT', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${s._maxWeight?.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(s._fmtDate(s._maxWeightDate), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ]),
          )),
          const SizedBox(width: 10),
          Expanded(child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TOTAL VOLUME', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${((s._maxVolume ?? 0) / 1000).toStringAsFixed(1)}K kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          )),
        ]),
        const SizedBox(height: 20),
        if (s._progressSpots.length >= 2) ...[
          const Text('Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 36,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                )),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [LineChartBarData(
                spots: s._progressSpots,
                isCurved: true,
                color: AppTheme.accent,
                barWidth: 2.5,
                dotData: FlDotData(getDotPainter: (_, _, _, i) => FlDotCirclePainter(
                  radius: i == s._progressSpots.length - 1 ? 4 : 2,
                  color: AppTheme.accent, strokeWidth: 1.5, strokeColor: AppTheme.background,
                )),
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                  colors: [AppTheme.accent.withAlpha(60), AppTheme.accent.withAlpha(0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                )),
              )],
            )),
          ),
          const SizedBox(height: 20),
        ],
        const Text('Rep Maxes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Expanded(child: Text('REPS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
                Expanded(child: Text('ESTIMATED', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
                Expanded(child: Text('ACHIEVED', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
              ]),
            ),
            const Divider(height: 1),
            ...List.generate(12, (i) {
              final n = i + 1;
              final est = s._nRM(orm, n);
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Expanded(child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w500))),
                    Expanded(child: Text('${est.toStringAsFixed(1)} kg', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary))),
                    const Expanded(child: Text('—', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textTertiary))),
                  ]),
                ),
                if (n < 12) const Divider(height: 1, indent: 16),
              ]);
            }),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('Estimated maxes are calculated from your best set using the Epley formula.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final _ExerciseDetailScreenState s;
  const _HistoryTab(this.s);

  String _fmtDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (s._history.isEmpty) return const Center(child: Text('No history', style: TextStyle(color: AppTheme.textSecondary)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: s._history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final session = s._history[i];
        final series = session['series'] as List;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fmtDate(session['date']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            ...series.asMap().entries.map((e) {
              final set = e.value;
              final side = set['strona'] != null ? ' · ${set['strona']}' : '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 24, child: Text('${e.key + 1}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                  Text('${set['ciezar']}kg × ${set['powt']}$side', style: const TextStyle(fontSize: 14)),
                ]),
              );
            }),
          ]),
        );
      },
    );
  }
}

class _GuideTab extends StatelessWidget {
  final String name;
  final String type;
  final String? muscleGroup;

  const _GuideTab({required this.name, required this.type, this.muscleGroup});

  static const _guides = <String, Map<String, String>>{
    'Chest': {
      'primary': 'Pectoralis Major',
      'secondary': 'Anterior Deltoid, Triceps',
      'tips': '• Keep shoulder blades retracted and depressed\n• Control the eccentric (lowering) phase\n• Full range of motion for maximum muscle activation\n• Maintain consistent bar path',
    },
    'Back': {
      'primary': 'Latissimus Dorsi, Rhomboids',
      'secondary': 'Biceps, Rear Deltoid, Trapezius',
      'tips': '• Initiate the pull with your elbows, not hands\n• Squeeze shoulder blades together at contraction\n• Avoid using momentum or swinging\n• Maintain a neutral spine throughout',
    },
    'Shoulders': {
      'primary': 'Deltoids (Anterior, Lateral, Posterior)',
      'secondary': 'Trapezius, Rotator Cuff',
      'tips': '• Avoid shrugging — keep shoulders down\n• Control the weight through full ROM\n• Warm up rotator cuff before heavy pressing\n• Use lighter weights for isolation movements',
    },
    'Arms': {
      'primary': 'Biceps Brachii / Triceps Brachii',
      'secondary': 'Brachialis, Forearms',
      'tips': '• Keep elbows stationary during curls\n• Full extension on tricep movements\n• Avoid swinging or using momentum\n• Mind-muscle connection is key for arms',
    },
    'Legs': {
      'primary': 'Quadriceps, Hamstrings, Glutes',
      'secondary': 'Calves, Hip Flexors, Adductors',
      'tips': '• Knees track over toes during squats\n• Push through the full foot, not just toes\n• Keep core braced and spine neutral\n• Full depth for optimal quad/glute activation',
    },
    'Core': {
      'primary': 'Rectus Abdominis, Obliques',
      'secondary': 'Transverse Abdominis, Erector Spinae',
      'tips': '• Breathe out on contraction\n• Avoid pulling on your neck during crunches\n• Engage deep core before movement starts\n• Quality reps over quantity',
    },
    'Cardio': {
      'primary': 'Cardiovascular System',
      'secondary': 'Multiple muscle groups depending on activity',
      'tips': '• Warm up for 5 minutes at low intensity\n• Monitor heart rate for target zone\n• Cool down and stretch after session\n• Stay hydrated throughout',
    },
  };

  @override
  Widget build(BuildContext context) {
    final guide = _guides[muscleGroup];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.fitness_center, color: AppTheme.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 12),
              _InfoRow(label: 'Type', value: type == 'unilateral' ? 'Unilateral (L/R)' : 'Bilateral'),
              if (muscleGroup != null) _InfoRow(label: 'Muscle Group', value: muscleGroup!),
            ]),
          ),
          if (guide != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('MUSCLES WORKED', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                _InfoRow(label: 'Primary', value: guide['primary']!),
                _InfoRow(label: 'Secondary', value: guide['secondary']!),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('FORM TIPS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Text(guide['tips']!, style: const TextStyle(fontSize: 14, height: 1.6)),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 32),
            const Center(child: Text('Guide data for this muscle group is not available yet.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center)),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GENERAL TIPS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              SizedBox(height: 10),
              Text(
                '• Always warm up before lifting heavy\n'
                '• Progressive overload: increase weight/reps over time\n'
                '• Rest 2-3 min between heavy compound sets\n'
                '• Rest 60-90s between isolation sets\n'
                '• Track your progress to stay motivated',
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
