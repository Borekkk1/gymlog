import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _workouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _supabase
          .from('treningi')
          .select('*, serie(cwiczenie_id, ciezar, powt)')
          .eq('is_draft', false)
          .order('started_at', ascending: false);
      setState(() {
        _workouts = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // Group workouts by year-month
  Map<String, List<Map<String, dynamic>>> _groupByMonth() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final w in _workouts) {
      final dt = DateTime.parse(w['started_at']).toLocal();
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(w);
    }
    return map;
  }

  Set<int> _workoutDaysInMonth(List<Map<String, dynamic>> workouts, int year, int month) {
    return workouts
        .map((w) => DateTime.parse(w['started_at']).toLocal())
        .where((d) => d.year == year && d.month == month)
        .map((d) => d.day)
        .toSet();
  }

  double _totalVolume(List<Map<String, dynamic>> workouts) {
    double v = 0;
    for (final w in workouts) {
      for (final s in (w['serie'] as List)) {
        v += (s['ciezar'] as num) * (s['powt'] as num);
      }
    }
    return v;
  }

  Duration _totalDuration(List<Map<String, dynamic>> workouts) {
    Duration total = Duration.zero;
    for (final w in workouts) {
      if (w['ended_at'] != null) {
        final s = DateTime.parse(w['started_at']);
        final e = DateTime.parse(w['ended_at']);
        total += e.difference(s);
      }
    }
    return total;
  }

  int _streakWeeks() {
    if (_workouts.isEmpty) return 0;
    final dates = _workouts
        .map((w) => DateTime.parse(w['started_at']).toLocal())
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime? lastWeekStart;
    for (final d in dates) {
      final weekStart = d.subtract(Duration(days: d.weekday - 1));
      if (lastWeekStart == null) {
        lastWeekStart = weekStart;
        streak = 1;
      } else {
        final diff = lastWeekStart.difference(weekStart).inDays;
        if (diff == 7) {
          streak++;
          lastWeekStart = weekStart;
        } else if (diff > 7) {
          break;
        }
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMonth();
    final months = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.accent,
                child: CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, color: AppTheme.accent, size: 28),
                            const Spacer(),
                            const Text('Feed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            const Icon(Icons.notifications_outlined, color: AppTheme.accent, size: 28),
                          ],
                        ),
                      ),
                    ),
                    if (_workouts.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('💪', style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text('No workouts yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                              SizedBox(height: 8),
                              Text('Go to Workout tab to start!', style: TextStyle(color: AppTheme.textTertiary, fontSize: 14)),
                            ],
                          ),
                        ),
                      )
                    else
                      for (final monthKey in months)
                        _MonthSection(
                          monthKey: monthKey,
                          workouts: grouped[monthKey]!,
                          allWorkouts: _workouts,
                          streakWeeks: _streakWeeks(),
                        ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  final String monthKey;
  final List<Map<String, dynamic>> workouts;
  final List<Map<String, dynamic>> allWorkouts;
  final int streakWeeks;

  const _MonthSection({
    required this.monthKey,
    required this.workouts,
    required this.allWorkouts,
    required this.streakWeeks,
  });

  Set<int> get _workoutDays {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return workouts
        .map((w) => DateTime.parse(w['started_at']).toLocal())
        .where((d) => d.year == year && d.month == month)
        .map((d) => d.day)
        .toSet();
  }

  double get _totalVolume {
    double v = 0;
    for (final w in workouts) {
      for (final s in (w['serie'] as List)) {
        v += (s['ciezar'] as num) * (s['powt'] as num);
      }
    }
    return v;
  }

  String get _totalTime {
    Duration total = Duration.zero;
    for (final w in workouts) {
      if (w['ended_at'] != null) {
        total += DateTime.parse(w['ended_at']).difference(DateTime.parse(w['started_at']));
      }
    }
    final h = total.inHours;
    final m = total.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String get _monthLabel {
    final parts = monthKey.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[dt.month - 1]}, ${dt.year}';
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    final parts = monthKey.split('-');
    return int.parse(parts[0]) == now.year && int.parse(parts[1]) == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final days = _workoutDays;
    final isCurrentMonth = _isCurrentMonth;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_monthLabel,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    ],
                  ),
                ),
                if (isCurrentMonth) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text('$streakWeeks week${streakWeeks != 1 ? 's' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Calendar + stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _CalendarWidget(year: year, month: month, workoutDays: days),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _StatBox(value: '${workouts.length}', label: workouts.length == 1 ? 'WORKOUT' : 'WORKOUTS'),
                      const SizedBox(height: 6),
                      _StatBox(value: _totalVolume > 1000 ? '${(_totalVolume / 1000).toStringAsFixed(1)}K' : _totalVolume.toStringAsFixed(0), label: 'VOLUME'),
                      const SizedBox(height: 6),
                      _StatBox(value: _totalTime, label: 'TIME'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Workout cards for this month
          ...workouts.map((w) => _WorkoutCard(workout: w)),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ),
    );
  }
}

class _CalendarWidget extends StatelessWidget {
  final int year;
  final int month;
  final Set<int> workoutDays;

  const _CalendarWidget({required this.year, required this.month, required this.workoutDays});

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final today = DateTime.now();
    final isCurrentMonth = today.year == year && today.month == month;

    return Column(
      children: [
        // Day labels
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) =>
            Expanded(child: Center(child: Text(d,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500))))).toList(),
        ),
        const SizedBox(height: 4),
        // Days grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (_, i) {
            if (i < startWeekday) return const SizedBox();
            final day = i - startWeekday + 1;
            final hasWorkout = workoutDays.contains(day);
            final isToday = isCurrentMonth && today.day == day;
            return Container(
              decoration: BoxDecoration(
                color: hasWorkout ? AppTheme.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !hasWorkout
                    ? Border.all(color: AppTheme.accent, width: 1)
                    : null,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: hasWorkout || isToday ? FontWeight.w700 : FontWeight.w400,
                    color: hasWorkout ? Colors.white : (isToday ? AppTheme.accent : AppTheme.textSecondary),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Map<String, dynamic> workout;
  const _WorkoutCard({required this.workout});

  String _timeAgo(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final series = workout['serie'] as List;
    // Get unique exercise count (approximate from serie data)
    final exerciseCount = (series.map((s) => s['cwiczenie_id']).toSet()).length;
    Duration dur = Duration.zero;
    if (workout['ended_at'] != null) {
      dur = DateTime.parse(workout['ended_at']).difference(DateTime.parse(workout['started_at']));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center, color: AppTheme.textSecondary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('You · ${_timeAgo(workout['started_at'])}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(workout['nazwa'] ?? 'Workout',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '$exerciseCount exercise${exerciseCount != 1 ? 's' : ''} · ${dur.inMinutes}m',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
