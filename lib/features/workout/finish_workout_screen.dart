import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class FinishWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic> workoutData;
  const FinishWorkoutScreen({super.key, required this.workoutData});

  @override
  State<FinishWorkoutScreen> createState() => _FinishWorkoutScreenState();
}

class _FinishWorkoutScreenState extends State<FinishWorkoutScreen> {
  final _supabase = Supabase.instance.client;
  late final TextEditingController _nameCtrl;
  final _noteCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bodyweightCtrl = TextEditingController();
  int? _intensity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.workoutData['name'] ?? 'Workout');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _locationCtrl.dispose();
    _bodyweightCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      final series = widget.workoutData['series'] as List;
      final duration = widget.workoutData['duration'] as int;

      final treningRes = await _supabase.from('treningi').insert({
        'user_id': userId,
        'nazwa': _nameCtrl.text.trim(),
        'started_at': DateTime.now().subtract(Duration(minutes: duration)).toIso8601String(),
        'ended_at': DateTime.now().toIso8601String(),
        'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        'intensity': _intensity,
        'location': _locationCtrl.text.isEmpty ? null : _locationCtrl.text,
        'bodyweight': double.tryParse(_bodyweightCtrl.text),
        'is_draft': false,
      }).select().single();

      if (series.isNotEmpty) {
        await _supabase.from('serie').insert(series.map((s) => {
          'trening_id': treningRes['id'],
          'cwiczenie_id': s['exerciseId'],
          'numer_serii': s['setNum'],
          'powt': s['reps'],
          'ciezar': s['weight'],
          'strona': s['side'],
          'note': s['note']?.isEmpty == true ? null : s['note'],
        }).toList());
      }

      if (mounted) context.go('/');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.workoutData['duration'] as int;
    final series = widget.workoutData['series'] as List;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Finish Workout'),
        leading: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back', style: TextStyle(color: AppTheme.accent))),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                : const Text('Submit', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Summary stats
          Row(children: [
            _SummaryChip(label: 'Duration', value: '${duration}m'),
            const SizedBox(width: 12),
            _SummaryChip(label: 'Sets', value: '${series.length}'),
            const SizedBox(width: 12),
            _SummaryChip(label: 'Volume', value: () {
              double v = 0;
              for (final s in series) {
                v += (s['weight'] as double) * (s['reps'] as int);
              }
              return v > 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
            }()),
          ]),
          const SizedBox(height: 20),
          _Field(label: 'Name', child: TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Workout name'),
          )),
          const SizedBox(height: 12),
          // Intensity
          _Field(label: 'Intensity (optional)', child: Row(
            children: List.generate(10, (i) {
              final val = i + 1;
              final selected = _intensity == val;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _intensity = selected ? null : val),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accent : AppTheme.surface2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$val', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppTheme.textSecondary)),
                ),
              ));
            }),
          )),
          const SizedBox(height: 12),
          _Field(label: 'Note (optional)', child: TextField(
            controller: _noteCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Add a note...'),
          )),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Field(label: 'Location (optional)', child: TextField(
              controller: _locationCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(hintText: 'Gym, Home...'),
            ))),
            const SizedBox(width: 12),
            Expanded(child: _Field(label: 'Bodyweight kg (optional)', child: TextField(
              controller: _bodyweightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(hintText: '75.0'),
            ))),
          ]),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _saving ? null : _submit, child: const Text('Submit Workout')),
        ]),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ]),
    ),
  );
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      child,
    ],
  );
}
