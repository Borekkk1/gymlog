import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class WorkoutTabScreen extends StatefulWidget {
  const WorkoutTabScreen({super.key});
  @override
  State<WorkoutTabScreen> createState() => _WorkoutTabScreenState();
}

class _WorkoutTabScreenState extends State<WorkoutTabScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _recent = [];
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
          .select('id, nazwa, started_at, ended_at, serie(cwiczenie_id, cwiczenia(nazwa))')
          .eq('is_draft', false)
          .order('started_at', ascending: false)
          .limit(10);
      setState(() {
        _recent = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  String _duration(Map<String, dynamic> w) {
    if (w['ended_at'] == null) return '';
    final dur = DateTime.parse(w['ended_at']).difference(DateTime.parse(w['started_at']));
    return '${dur.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Workout', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
            ),
            // Start new workout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => context.push('/workout/active'),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: AppTheme.accent, size: 28),
                      SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New Workout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          Text('Start an empty workout', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.accent)))
            else if (_recent.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('REPEAT WORKOUT', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _recent.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 0),
                  itemBuilder: (_, i) {
                    final w = _recent[i];
                    final series = w['serie'] as List;
                    final exNames = series.map((s) => s['cwiczenia']?['nazwa'] ?? '').where((n) => n.isNotEmpty).toSet().take(3).join(', ');
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      title: Text(w['nazwa'] ?? 'Workout', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDate(w['started_at']), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          if (exNames.isNotEmpty)
                            Text(exNames, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_duration(w), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
                        ],
                      ),
                      onTap: () => context.push('/workout/active', extra: {'repeatWorkoutId': w['id']}),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(child: Text('No previous workouts', style: TextStyle(color: AppTheme.textSecondary))),
              ),
          ],
        ),
      ),
    );
  }
}
