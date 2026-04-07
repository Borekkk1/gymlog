import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../exercises/exercises_screen.dart';

class ActiveSet {
  double weight;
  int reps;
  String? side; // null, 'L', 'R'
  bool done;
  String note;
  double? prevWeight;
  int? prevReps;
  String? prevDate;

  ActiveSet({this.weight = 0, this.reps = 10, this.side, this.done = false, this.note = '', this.prevWeight, this.prevReps, this.prevDate});
}

class ActiveExercise {
  final String exerciseId;
  final String name;
  final String type; // bilateral / unilateral
  List<ActiveSet> sets;

  ActiveExercise({required this.exerciseId, required this.name, required this.type}) : sets = [];
}

class ActiveWorkoutScreen extends StatefulWidget {
  final String? templateId;
  final String? repeatWorkoutId;
  const ActiveWorkoutScreen({super.key, this.templateId, this.repeatWorkoutId});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final _supabase = Supabase.instance.client;
  final List<ActiveExercise> _exercises = [];
  String _workoutName = '';
  late final Stopwatch _stopwatch = Stopwatch()..start();
  late final Timer _timer;
  String _elapsed = '0:00';
  int _restSeconds = 90;
  int _restCountdown = 0;
  bool _restActive = false;
  final bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _workoutName = 'Workout ${now.day}.${now.month}';
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        final e = _stopwatch.elapsed;
        _elapsed = '${e.inMinutes}:${(e.inSeconds % 60).toString().padLeft(2, '0')}';
        if (_restActive && _restCountdown > 0) {
          _restCountdown--;
          if (_restCountdown == 0) _restActive = false;
        }
      });
    });
    if (widget.repeatWorkoutId != null) _loadRepeatWorkout();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadRepeatWorkout() async {
    final series = await _supabase
        .from('serie')
        .select('*, cwiczenia(id, nazwa, typ)')
        .eq('trening_id', widget.repeatWorkoutId!);

    final exMap = <String, ActiveExercise>{};
    for (final s in series) {
      final exId = s['cwiczenie_id'] as String;
      if (!exMap.containsKey(exId)) {
        exMap[exId] = ActiveExercise(
          exerciseId: exId,
          name: s['cwiczenia']['nazwa'],
          type: s['cwiczenia']['typ'],
        );
      }
    }
    for (final ex in exMap.values) {
      final exSeries = series.where((s) => s['cwiczenie_id'] == ex.exerciseId).toList();
      final prevDate = exSeries.isNotEmpty ? exSeries.first['completed_at'] : null;
      if (ex.type == 'unilateral') {
        final lSeries = exSeries.where((s) => s['strona'] == 'L').toList();
        final rSeries = exSeries.where((s) => s['strona'] == 'P').toList();
        final count = lSeries.length > rSeries.length ? lSeries.length : rSeries.length;
        for (int i = 0; i < count; i++) {
          if (i < lSeries.length) {
            ex.sets.add(ActiveSet(side: 'L', weight: (lSeries[i]['ciezar'] as num).toDouble(), reps: lSeries[i]['powt'],
              prevWeight: (lSeries[i]['ciezar'] as num).toDouble(), prevReps: lSeries[i]['powt'], prevDate: prevDate));
          }
          if (i < rSeries.length) {
            ex.sets.add(ActiveSet(side: 'R', weight: (rSeries[i]['ciezar'] as num).toDouble(), reps: rSeries[i]['powt'],
              prevWeight: (rSeries[i]['ciezar'] as num).toDouble(), prevReps: rSeries[i]['powt'], prevDate: prevDate));
          }
        }
      } else {
        for (final s in exSeries) {
          ex.sets.add(ActiveSet(weight: (s['ciezar'] as num).toDouble(), reps: s['powt'],
            prevWeight: (s['ciezar'] as num).toDouble(), prevReps: s['powt'], prevDate: prevDate));
        }
      }
    }
    if (mounted) setState(() => _exercises.addAll(exMap.values));
  }

  Future<void> _addExercise() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ExercisesScreen(pickMode: true)),
    );
    if (result == null) return;

    final ex = ActiveExercise(exerciseId: result['id'], name: result['nazwa'], type: result['typ']);

    // Load previous data for this exercise
    final prev = await _supabase
        .from('serie')
        .select('ciezar, powt, strona, completed_at')
        .eq('cwiczenie_id', result['id'])
        .order('completed_at', ascending: false)
        .limit(10);

    if (result['typ'] == 'unilateral') {
      final lPrev = prev.where((s) => s['strona'] == 'L').take(3).toList();
      final rPrev = prev.where((s) => s['strona'] == 'P').take(3).toList();
      final count = 3;
      for (int i = 0; i < count; i++) {
        ex.sets.add(ActiveSet(side: 'L',
          weight: i < lPrev.length ? (lPrev[i]['ciezar'] as num).toDouble() : 0,
          reps: i < lPrev.length ? lPrev[i]['powt'] : 10,
          prevWeight: i < lPrev.length ? (lPrev[i]['ciezar'] as num).toDouble() : null,
          prevReps: i < lPrev.length ? lPrev[i]['powt'] : null,
          prevDate: i < lPrev.length ? lPrev[i]['completed_at'] : null,
        ));
        ex.sets.add(ActiveSet(side: 'R',
          weight: i < rPrev.length ? (rPrev[i]['ciezar'] as num).toDouble() : 0,
          reps: i < rPrev.length ? rPrev[i]['powt'] : 10,
          prevWeight: i < rPrev.length ? (rPrev[i]['ciezar'] as num).toDouble() : null,
          prevReps: i < rPrev.length ? rPrev[i]['powt'] : null,
          prevDate: i < rPrev.length ? rPrev[i]['completed_at'] : null,
        ));
      }
    } else {
      for (int i = 0; i < 3; i++) {
        ex.sets.add(ActiveSet(
          weight: i < prev.length ? (prev[i]['ciezar'] as num).toDouble() : 0,
          reps: i < prev.length ? prev[i]['powt'] : 10,
          prevWeight: i < prev.length ? (prev[i]['ciezar'] as num).toDouble() : null,
          prevReps: i < prev.length ? prev[i]['powt'] : null,
          prevDate: i < prev.length ? prev[i]['completed_at'] : null,
        ));
      }
    }
    setState(() => _exercises.add(ex));
  }

  void _startRest() => setState(() { _restCountdown = _restSeconds; _restActive = true; });

  Future<void> _finish() async {
    final allDone = _exercises.every((ex) => ex.sets.every((s) => s.done));
    if (!allDone) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Unfinished sets'),
          content: const Text('Some sets are not checked. Finish anyway?'),
          actions: [
            CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
            CupertinoDialogAction(isDestructiveAction: true, child: const Text('Finish'), onPressed: () => Navigator.pop(context, true)),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final duration = _stopwatch.elapsed;
    final serieList = <Map<String, dynamic>>[];
    for (final ex in _exercises) {
      for (int i = 0; i < ex.sets.length; i++) {
        final s = ex.sets[i];
        if (s.done || s.weight > 0 || s.reps > 0) {
          serieList.add({'exerciseId': ex.exerciseId, 'setNum': i + 1, 'weight': s.weight, 'reps': s.reps, 'side': s.side, 'note': s.note});
        }
      }
    }

    context.push('/workout/finish', extra: {
      'name': _workoutName,
      'duration': duration.inMinutes,
      'series': serieList,
    });
  }

  void _showMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(child: const Text('Reorder Exercises'), onPressed: () { Navigator.pop(context); }),
          CupertinoActionSheetAction(child: const Text('Save as Draft'), onPressed: () { Navigator.pop(context); }),
          CupertinoActionSheetAction(child: const Text('Workout Settings'), onPressed: () { Navigator.pop(context); }),
          CupertinoActionSheetAction(isDestructiveAction: true, child: const Text('Delete Workout'),
            onPressed: () { Navigator.pop(context); _confirmDiscard(); }),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
      ),
    );
  }

  void _confirmDiscard() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('Progress will not be saved.'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(isDestructiveAction: true, child: const Text('Delete'), onPressed: () { Navigator.pop(context); context.go('/workout'); }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          onPressed: _confirmDiscard,
        ),
        title: GestureDetector(
          onTap: () => _editName(),
          child: Text(_workoutName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz), onPressed: _showMenu),
          TextButton(
            onPressed: _saving ? null : _finish,
            child: const Text('Finish', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Start time + rest time row
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _InfoChip(label: 'Start Time', value: _startTimeStr()),
                const SizedBox(width: 24),
                _InfoChip(label: 'Rest Time', value: _formatRest(_restSeconds)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Exercise list
          Expanded(
            child: _exercises.isEmpty
                ? _EmptyState(onAdd: _addExercise)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _exercises.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _exercises.length) {
                        return Column(
                          children: [
                            const Divider(height: 1),
                            _AddButton(label: '+ Add Exercise', onTap: _addExercise),
                            _AddButton(label: '+ Add Superset', onTap: () {}),
                          ],
                        );
                      }
                      return _ExerciseCard(
                        exercise: _exercises[i],
                        onUpdate: () => setState(() {}),
                        onSetDone: () { _startRest(); setState(() {}); },
                        onRemove: () => setState(() => _exercises.removeAt(i)),
                      );
                    },
                  ),
          ),
          // Bottom toolbar
          _BottomBar(
            restCountdown: _restCountdown,
            restSeconds: _restSeconds,
            restActive: _restActive,
            elapsed: _elapsed,
            onRestTap: () => _editRestTime(),
            exercises: _exercises,
          ),
        ],
      ),
    );
  }

  String _startTimeStr() {
    final now = DateTime.now().subtract(_stopwatch.elapsed);
    final h = now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hh = h % 12 == 0 ? 12 : h % 12;
    return 'Today, $hh:$m $ampm';
  }

  String _formatRest(int s) {
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _editName() {
    final ctrl = TextEditingController(text: _workoutName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Workout Name'),
        content: TextFormField(controller: ctrl, autofocus: true, style: const TextStyle(color: AppTheme.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () { setState(() => _workoutName = ctrl.text); Navigator.pop(context); }, child: const Text('Save')),
        ],
      ),
    );
  }

  void _editRestTime() {
    int temp = _restSeconds;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Rest Time', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.remove_circle_outline), iconSize: 32, onPressed: () => setModal(() => temp = (temp - 15).clamp(15, 600))),
                  SizedBox(width: 80, child: Text('${temp ~/ 60}:${(temp % 60).toString().padLeft(2, '0')}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.add_circle_outline), iconSize: 32, onPressed: () => setModal(() => temp = (temp + 15).clamp(15, 600))),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [30, 60, 90, 120, 180, 240].map((s) => GestureDetector(
                  onTap: () => setModal(() => temp = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: temp == s ? AppTheme.accent : AppTheme.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}', style: TextStyle(color: temp == s ? Colors.white : AppTheme.textSecondary, fontSize: 13)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () { setState(() => _restSeconds = temp); Navigator.pop(context); },
                child: const Text('Set'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('$label  ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🏋️', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('Add your first exercise', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: onAdd, child: const Text('Add Exercise')),
    ]),
  );
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w500)),
    onTap: onTap,
  );
}

class _ExerciseCard extends StatelessWidget {
  final ActiveExercise exercise;
  final VoidCallback onUpdate;
  final VoidCallback onSetDone;
  final VoidCallback onRemove;

  const _ExerciseCard({required this.exercise, required this.onUpdate, required this.onSetDone, required this.onRemove});

  void _addSet(VoidCallback update) {
    if (exercise.type == 'unilateral') {
      exercise.sets.add(ActiveSet(side: 'L'));
      exercise.sets.add(ActiveSet(side: 'R'));
    } else {
      exercise.sets.add(ActiveSet());
    }
    update();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.accent)),
                if (exercise.type == 'unilateral')
                  const Text('Unilateral · L/R tracked separately', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
            ),
            IconButton(icon: const Icon(Icons.timer_outlined, color: AppTheme.textSecondary, size: 20), onPressed: () {}),
            IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20), onPressed: onRemove),
          ]),
        ),
        // Column headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const SizedBox(width: 28, child: Text('SET', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            if (exercise.type == 'unilateral') const SizedBox(width: 28),
            const Expanded(child: Text('YESTERDAY ↑', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
            const SizedBox(width: 8),
            const SizedBox(width: 64, child: Text('KG', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
            const SizedBox(width: 4),
            const SizedBox(width: 52, child: Text('REPS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
            const SizedBox(width: 40),
          ]),
        ),
        ...exercise.sets.asMap().entries.map((e) => _SetRow(
          index: e.key,
          set: e.value,
          isUnilateral: exercise.type == 'unilateral',
          onDone: () { e.value.done = !e.value.done; if (e.value.done) {
            onSetDone();
          } else {
            onUpdate();
          } },
          onUpdate: onUpdate,
        )),
        TextButton.icon(
          onPressed: () => _addSet(onUpdate),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Set'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary, padding: const EdgeInsets.symmetric(horizontal: 16)),
        ),
      ],
    );
  }
}

class _SetRow extends StatefulWidget {
  final int index;
  final ActiveSet set;
  final bool isUnilateral;
  final VoidCallback onDone;
  final VoidCallback onUpdate;
  const _SetRow({required this.index, required this.set, required this.isUnilateral, required this.onDone, required this.onUpdate});
  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _wCtrl;
  late final TextEditingController _rCtrl;

  @override
  void initState() {
    super.initState();
    _wCtrl = TextEditingController(text: widget.set.weight > 0 ? widget.set.weight.toString() : '');
    _rCtrl = TextEditingController(text: widget.set.reps.toString());
  }

  @override
  void dispose() { _wCtrl.dispose(); _rCtrl.dispose(); super.dispose(); }

  String _prevLabel() {
    if (widget.set.prevWeight == null) return '--';
    return '${widget.set.prevWeight}x${widget.set.prevReps}';
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.set.done;
    final sideColor = widget.set.side == 'L' ? AppTheme.blue : AppTheme.orange;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: done ? AppTheme.accent.withOpacity(0.08) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Column(
        children: [
          Row(children: [
            SizedBox(width: 28, child: Text('${widget.index + 1}', textAlign: TextAlign.center,
              style: TextStyle(color: done ? AppTheme.accent : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
            const SizedBox(width: 8),
            if (widget.isUnilateral)
              Container(width: 24, height: 22, margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: sideColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Center(child: Text(widget.set.side ?? '', style: TextStyle(color: sideColor, fontWeight: FontWeight.w700, fontSize: 11)))),
            Expanded(
              child: Text(_prevLabel(), textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 64, child: TextFormField(
              controller: _wCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 6), hintText: '0'),
              onChanged: (v) { widget.set.weight = double.tryParse(v) ?? 0; widget.onUpdate(); },
            )),
            const SizedBox(width: 4),
            SizedBox(width: 52, child: TextFormField(
              controller: _rCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 6), hintText: '0'),
              onChanged: (v) { widget.set.reps = int.tryParse(v) ?? 0; widget.onUpdate(); },
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onDone,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: done ? AppTheme.accent : AppTheme.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.check, color: done ? Colors.white : AppTheme.textSecondary, size: 18),
              ),
            ),
          ]),
          // Note row (compact)
          if (widget.set.note.isNotEmpty || done == false)
            Padding(
              padding: const EdgeInsets.only(left: 36, right: 40),
              child: TextFormField(
                initialValue: widget.set.note,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Add note...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 2),
                  isDense: true,
                ),
                onChanged: (v) { widget.set.note = v; widget.onUpdate(); },
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int restCountdown;
  final int restSeconds;
  final bool restActive;
  final String elapsed;
  final VoidCallback onRestTap;
  final List<ActiveExercise> exercises;

  const _BottomBar({
    required this.restCountdown,
    required this.restSeconds,
    required this.restActive,
    required this.elapsed,
    required this.onRestTap,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context) {
    final displayTime = restActive ? restCountdown : restSeconds;
    final mins = displayTime ~/ 60;
    final secs = (displayTime % 60).toString().padLeft(2, '0');

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom, left: 12, right: 12, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Rest timer
          GestureDetector(
            onTap: onRestTap,
            child: Row(children: [
              Icon(Icons.timer_outlined, color: restActive ? AppTheme.accent : AppTheme.textSecondary, size: 18),
              const SizedBox(width: 4),
              Text('$mins:$secs',
                style: TextStyle(color: restActive ? AppTheme.accent : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
          ),
          // Tools
          _ToolBtn(icon: Icons.calculate_outlined, label: 'Plates', onTap: () => _showPlateCalc(context)),
          _ToolBtn(icon: Icons.trending_up_rounded, label: '1RM', onTap: () => _showRepMaxCalc(context)),
          _ToolBtn(icon: Icons.show_chart_rounded, label: 'Trend', onTap: () {}),
          _ToolBtn(icon: Icons.local_fire_department_outlined, label: 'Exertion', onTap: () => _showExertion(context)),
          // Elapsed
          Text(elapsed, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  void _showPlateCalc(BuildContext context) {
    double barWeight = 20;
    double targetWeight = 100;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final perSide = (targetWeight - barWeight) / 2;
          final plates = _calcPlates(perSide);
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Plate Calculator', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Target (kg)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  TextFormField(
                    initialValue: targetWeight.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(border: InputBorder.none, filled: false),
                    onChanged: (v) => setModal(() => targetWeight = double.tryParse(v) ?? 20),
                  ),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Barbell (kg)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  DropdownButton<double>(
                    value: barWeight,
                    dropdownColor: AppTheme.surface2,
                    items: [15.0, 20.0, 25.0].map((b) => DropdownMenuItem(value: b, child: Text('${b}kg', style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                    onChanged: (v) => setModal(() => barWeight = v!),
                  ),
                ])),
              ]),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Per side:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              perSide <= 0
                  ? const Text('Target must be greater than barbell weight', style: TextStyle(color: AppTheme.accent))
                  : Wrap(spacing: 8, runSpacing: 8, children: plates.entries.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: _plateColor(e.key), borderRadius: BorderRadius.circular(20)),
                    child: Text('${e.key}kg × ${e.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  )).toList()),
            ]),
          );
        },
      ),
    );
  }

  Map<double, int> _calcPlates(double perSide) {
    final plateSizes = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
    final result = <double, int>{};
    double remaining = perSide;
    for (final p in plateSizes) {
      final count = (remaining / p).floor();
      if (count > 0) { result[p] = count; remaining -= p * count; }
    }
    return result;
  }

  Color _plateColor(double kg) {
    if (kg >= 25) return const Color(0xFFE53935);
    if (kg >= 20) return const Color(0xFF1565C0);
    if (kg >= 15) return const Color(0xFFEF6C00);
    if (kg >= 10) return const Color(0xFF2E7D32);
    if (kg >= 5) return const Color(0xFF6A1B9A);
    return const Color(0xFF37474F);
  }

  void _showRepMaxCalc(BuildContext context) {
    double weight = 100;
    int reps = 5;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final oneRM = weight * (1 + reps / 30);
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Rep Max Calculator', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(children: [
                  const Text('Weight (kg)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  TextFormField(initialValue: weight.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(), onChanged: (v) => setModal(() => weight = double.tryParse(v) ?? 0)),
                ])),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  const Text('Reps', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  TextFormField(initialValue: reps.toString(), keyboardType: TextInputType.number,
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(), onChanged: (v) => setModal(() => reps = int.tryParse(v) ?? 1)),
                ])),
              ]),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ...List.generate(12, (i) {
                final n = i + 1;
                final est = n == 1 ? oneRM : oneRM / (1 + n / 30);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('$n RM', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    Text('${est.toStringAsFixed(1)} kg', style: TextStyle(
                      fontWeight: n == reps ? FontWeight.w700 : FontWeight.w400,
                      color: n == reps ? AppTheme.accent : AppTheme.textPrimary, fontSize: 14)),
                  ]),
                );
              }),
            ]),
          );
        },
      ),
    );
  }

  void _showExertion(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Exertion Tracking', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          SizedBox(height: 16),
          Text('Track your exertion levels to optimize recovery. Rate each workout after finishing.', style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppTheme.textSecondary, size: 20),
    ]),
  );
}
