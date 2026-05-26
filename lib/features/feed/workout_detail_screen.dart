import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String workoutId;
  const WorkoutDetailScreen({super.key, required this.workoutId});
  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _workout;
  List<Map<String, dynamic>> _series = [];
  Map<String, String> _exerciseNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await _supabase
          .from('treningi')
          .select()
          .eq('id', widget.workoutId)
          .single();

      final series = await _supabase
          .from('serie')
          .select('*, cwiczenia(id, nazwa, grupa_miesniowa, typ)')
          .eq('trening_id', widget.workoutId)
          .order('numer_serii');

      final names = <String, String>{};
      for (final s in series) {
        if (s['cwiczenia'] != null) {
          names[s['cwiczenie_id']] = s['cwiczenia']['nazwa'];
        }
      }

      setState(() {
        _workout = Map<String, dynamic>.from(w);
        _series = List<Map<String, dynamic>>.from(series);
        _exerciseNames = names;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Duration get _duration {
    if (_workout == null || _workout!['ended_at'] == null) return Duration.zero;
    return DateTime.parse(_workout!['ended_at']).difference(DateTime.parse(_workout!['started_at']));
  }

  double get _totalVolume {
    double v = 0;
    for (final s in _series) {
      v += (s['ciezar'] as num).toDouble() * (s['powt'] as num).toDouble();
    }
    return v;
  }

  String _fmtDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day} · $h:$m';
  }

  Map<String, List<Map<String, dynamic>>> _groupByExercise() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final s in _series) {
      final id = s['cwiczenie_id'] as String;
      map.putIfAbsent(id, () => []).add(s);
    }
    return map;
  }

  Future<void> _deleteWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete workout?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _supabase.from('serie').delete().eq('trening_id', widget.workoutId);
    await _supabase.from('treningi').delete().eq('id', widget.workoutId);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_workout?['nazwa'] ?? 'Workout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.repeat_rounded, size: 22),
            tooltip: 'Repeat workout',
            onPressed: () => context.push('/workout/active', extra: {'repeatWorkoutId': widget.workoutId}),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            color: AppTheme.surface2,
            onSelected: (v) { if (v == 'delete') _deleteWorkout(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete Workout', style: TextStyle(color: AppTheme.accent))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _workout == null
              ? const Center(child: Text('Workout not found', style: TextStyle(color: AppTheme.textSecondary)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date
                      Text(_fmtDate(_workout!['started_at']), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      const SizedBox(height: 16),
                      // Stats row
                      Row(children: [
                        _Stat(value: '${_duration.inMinutes}', unit: 'min', label: 'Duration'),
                        const SizedBox(width: 12),
                        _Stat(value: '${_series.length}', unit: '', label: 'Sets'),
                        const SizedBox(width: 12),
                        _Stat(
                          value: _totalVolume > 1000 ? (_totalVolume / 1000).toStringAsFixed(1) : _totalVolume.toStringAsFixed(0),
                          unit: _totalVolume > 1000 ? 'K kg' : 'kg',
                          label: 'Volume',
                        ),
                      ]),
                      if (_workout!['intensity'] != null) ...[
                        const SizedBox(height: 16),
                        Row(children: [
                          const Text('Intensity  ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ...List.generate(10, (i) => Container(
                            width: 22, height: 22,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: i < (_workout!['intensity'] as int) ? AppTheme.accent : AppTheme.surface2,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(child: Text('${i + 1}', style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: i < (_workout!['intensity'] as int) ? Colors.white : AppTheme.textTertiary,
                            ))),
                          )),
                        ]),
                      ],
                      if (_workout!['note'] != null && (_workout!['note'] as String).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NOTE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              Text(_workout!['note'], style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                      if (_workout!['location'] != null || _workout!['bodyweight'] != null) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          if (_workout!['location'] != null) ...[
                            const Icon(Icons.location_on_outlined, color: AppTheme.textSecondary, size: 16),
                            const SizedBox(width: 4),
                            Text(_workout!['location'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            const SizedBox(width: 16),
                          ],
                          if (_workout!['bodyweight'] != null) ...[
                            const Icon(Icons.monitor_weight_outlined, color: AppTheme.textSecondary, size: 16),
                            const SizedBox(width: 4),
                            Text('${_workout!['bodyweight']} kg', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ]),
                      ],
                      const SizedBox(height: 24),
                      // Exercises
                      ..._groupByExercise().entries.map((entry) {
                        final exName = _exerciseNames[entry.key] ?? 'Unknown';
                        final sets = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exName, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 10),
                              // Header
                              const Row(children: [
                                SizedBox(width: 36, child: Text('SET', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600))),
                                Expanded(child: Text('KG', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                                Expanded(child: Text('REPS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                                SizedBox(width: 50, child: Text('VOL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                              ]),
                              const Divider(height: 12),
                              ...sets.asMap().entries.map((e) {
                                final s = e.value;
                                final w = (s['ciezar'] as num).toDouble();
                                final r = (s['powt'] as num).toInt();
                                final side = s['strona'] != null ? ' (${s['strona']})' : '';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(children: [
                                    SizedBox(width: 36, child: Text('${e.key + 1}$side', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                                    Expanded(child: Text('$w', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                                    Expanded(child: Text('$r', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                                    SizedBox(width: 50, child: Text((w * r).toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                                  ]),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, unit, label;
  const _Stat({required this.value, required this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              if (unit.isNotEmpty) Text(' $unit', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}
