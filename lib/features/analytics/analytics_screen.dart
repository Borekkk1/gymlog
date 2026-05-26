import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic> _stats = {};
  Map<String, double> _muscleVolume = {};
  List<Map<String, dynamic>> _exerciseProgress = [];
  List<FlSpot> _bodyweightSpots = [];
  List<String> _bodyweightDates = [];
  String _selectedMetric = 'Max';
  int _selectedMonths = 3;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final treningi = await _supabase.from('treningi').select('id, started_at, ended_at, bodyweight').eq('is_draft', false);
      final serie = await _supabase.from('serie').select('ciezar, powt, cwiczenie_id, completed_at, cwiczenia(nazwa, grupa_miesniowa)');

      int totalWorkouts = treningi.length;
      Duration totalDuration = Duration.zero;
      for (final t in treningi) {
        if (t['ended_at'] != null) {
          totalDuration += DateTime.parse(t['ended_at']).difference(DateTime.parse(t['started_at']));
        }
      }

      final exerciseIds = <String>{};
      double totalVolume = 0;
      int totalSets = serie.length;
      int totalReps = 0;
      final muscleVol = <String, double>{};

      for (final s in serie) {
        final w = (s['ciezar'] as num).toDouble();
        final r = (s['powt'] as num).toDouble();
        totalVolume += w * r;
        totalReps += r.toInt();
        exerciseIds.add(s['cwiczenie_id']);
        final muscle = s['cwiczenia']?['grupa_miesniowa'] ?? 'Other';
        muscleVol[muscle] = (muscleVol[muscle] ?? 0) + w * r;
      }

      // Body weight tracking
      final bwEntries = treningi
          .where((t) => t['bodyweight'] != null)
          .toList()
        ..sort((a, b) => (a['started_at'] as String).compareTo(b['started_at'] as String));

      final bwSpots = <FlSpot>[];
      final bwDates = <String>[];
      for (int i = 0; i < bwEntries.length; i++) {
        bwSpots.add(FlSpot(i.toDouble(), (bwEntries[i]['bodyweight'] as num).toDouble()));
        final dt = DateTime.parse(bwEntries[i]['started_at']).toLocal();
        bwDates.add('${dt.day}/${dt.month}');
      }

      // Top exercises for progress chart
      final exerciseProgress = <Map<String, dynamic>>[];
      final exByName = <String, List<Map<String, dynamic>>>{};
      for (final s in serie) {
        final name = s['cwiczenia']?['nazwa'] ?? 'Unknown';
        exByName.putIfAbsent(name, () => []).add(s);
      }

      final cutoff = DateTime.now().subtract(Duration(days: _selectedMonths * 30));
      for (final entry in exByName.entries.take(5)) {
        final filtered = entry.value.where((s) => DateTime.parse(s['completed_at']).isAfter(cutoff)).toList();
        if (filtered.isEmpty) continue;

        final byDate = <String, double>{};
        for (final s in filtered) {
          final date = DateTime.parse(s['completed_at']).toLocal();
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final w = (s['ciezar'] as num).toDouble();
          final r = (s['powt'] as num).toDouble();
          final val = _selectedMetric == 'Max' ? w * (1 + r / 30) : w * r;
          if (!byDate.containsKey(key) || byDate[key]! < val) byDate[key] = val;
        }

        final sorted = byDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
        final latestVal = sorted.isNotEmpty ? sorted.last.value : 0.0;
        final spots = sorted.asMap().entries.map((e) => FlSpot(e.key.toDouble(), double.parse(e.value.value.toStringAsFixed(1)))).toList();

        exerciseProgress.add({
          'name': entry.key,
          'spots': spots,
          'latestVal': latestVal,
        });
      }

      setState(() {
        _stats = {
          'workouts': totalWorkouts,
          'duration': '${totalDuration.inHours}h ${totalDuration.inMinutes % 60}m',
          'exercises': exerciseIds.length,
          'sets': totalSets,
          'reps': totalReps,
          'volume': totalVolume > 1000 ? '${(totalVolume / 1000).toStringAsFixed(1)}K' : totalVolume.toStringAsFixed(0),
        };
        _muscleVolume = muscleVol;
        _exerciseProgress = exerciseProgress;
        _bodyweightSpots = bwSpots;
        _bodyweightDates = bwDates;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.accent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Center(child: Text('Analytics', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                      ),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          _StatTile(value: '${_stats['workouts'] ?? 0}', label: 'WORKOUTS'),
                          _StatTile(value: '${_stats['duration'] ?? '0h'}', label: 'DURATION'),
                          _StatTile(value: '${_stats['exercises'] ?? 0}', label: 'EXERCISES'),
                          _StatTile(value: '${_stats['sets'] ?? 0}', label: 'SETS'),
                          _StatTile(value: '${_stats['reps'] ?? 0}', label: 'REPS'),
                          _StatTile(value: '${_stats['volume'] ?? 0}', label: 'VOLUME'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Body weight section
                      if (_bodyweightSpots.isNotEmpty) ...[
                        const Text('Body Weight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _BodyWeightChart(spots: _bodyweightSpots, dates: _bodyweightDates),
                        const SizedBox(height: 24),
                      ],
                      const Text('Muscles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _MuscleChart(muscleVolume: _muscleVolume),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Exercises', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Row(
                            children: ['Vol', 'Max'].map((m) => GestureDetector(
                              onTap: () { setState(() { _selectedMetric = m; _load(); }); },
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _selectedMetric == m ? AppTheme.surface3 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _selectedMetric == m ? AppTheme.surface3 : Colors.transparent),
                                ),
                                child: Text(m, style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _selectedMetric == m ? FontWeight.w600 : FontWeight.w400,
                                  color: _selectedMetric == m ? AppTheme.textPrimary : AppTheme.textSecondary,
                                )),
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [1, 3, 6].map((m) => GestureDetector(
                          onTap: () { setState(() { _selectedMonths = m; _load(); }); },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _selectedMonths == m ? AppTheme.surface2 : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${m}M', style: TextStyle(
                              fontSize: 13,
                              color: _selectedMonths == m ? AppTheme.textPrimary : AppTheme.textSecondary,
                              fontWeight: _selectedMonths == m ? FontWeight.w600 : FontWeight.w400,
                            )),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                      ..._exerciseProgress.map((ex) => _ExerciseChart(
                        name: ex['name'],
                        spots: ex['spots'],
                        latestVal: ex['latestVal'],
                        metric: _selectedMetric,
                      )),
                      if (_exerciseProgress.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No exercise data yet', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value, label;
  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _BodyWeightChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<String> dates;
  const _BodyWeightChart({required this.spots, required this.dates});

  @override
  Widget build(BuildContext context) {
    final latest = spots.last.y;
    final first = spots.first.y;
    final diff = latest - first;
    final diffStr = diff >= 0 ? '+${diff.toStringAsFixed(1)}' : diff.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('${latest.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (diff >= 0 ? AppTheme.green : AppTheme.accent).withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$diffStr kg', style: TextStyle(
                color: diff >= 0 ? AppTheme.green : AppTheme.accent,
                fontSize: 12, fontWeight: FontWeight.w600,
              )),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: spots.length < 2
                ? const Center(child: Text('Need more data', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)))
                : LineChart(LineChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppTheme.blue,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          getDotPainter: (_, _, _, i) => FlDotCirclePainter(
                            radius: i == spots.length - 1 ? 4 : 2,
                            color: AppTheme.blue,
                            strokeWidth: 1.5,
                            strokeColor: AppTheme.surface,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [AppTheme.blue.withAlpha(60), AppTheme.blue.withAlpha(0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  )),
          ),
        ],
      ),
    );
  }
}

class _MuscleChart extends StatelessWidget {
  final Map<String, double> muscleVolume;
  const _MuscleChart({required this.muscleVolume});

  @override
  Widget build(BuildContext context) {
    if (muscleVolume.isEmpty) {
      return const SizedBox(height: 40, child: Center(child: Text('No data', style: TextStyle(color: AppTheme.textSecondary))));
    }
    final sorted = muscleVolume.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;
    return Column(
      children: sorted.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(width: 70, child: Text(e.key, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: e.value / maxVal,
                  backgroundColor: AppTheme.surface2,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  minHeight: 8,
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class _ExerciseChart extends StatelessWidget {
  final String name;
  final List<FlSpot> spots;
  final double latestVal;
  final String metric;
  const _ExerciseChart({required this.name, required this.spots, required this.latestVal, required this.metric});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              Text(
                metric == 'Max' ? '${latestVal.toStringAsFixed(1)} kg' : '${latestVal.toStringAsFixed(0)} kg',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: spots.length < 2
                ? const Center(child: Text('Not enough data', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)))
                : LineChart(LineChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppTheme.accent,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          getDotPainter: (_, _, _, i) => FlDotCirclePainter(
                            radius: i == spots.length - 1 ? 4 : 2,
                            color: AppTheme.accent,
                            strokeWidth: 1.5,
                            strokeColor: AppTheme.background,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [AppTheme.accent.withAlpha(60), AppTheme.accent.withAlpha(0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  )),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
