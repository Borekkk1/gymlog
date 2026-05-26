import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class ExercisesScreen extends StatefulWidget {
  final bool pickMode;
  const ExercisesScreen({super.key, this.pickMode = false});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _filtered = [];
  String _search = '';
  String _filterGroup = 'All';
  bool _loading = true;
  bool _searching = false;

  final _groups = ['All', 'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Cardio'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _supabase.from('cwiczenia').select().order('nazwa');
    List<Map<String, dynamic>> recent = [];
    try {
      final recentSeries = await _supabase
          .from('serie')
          .select('cwiczenie_id, completed_at, cwiczenia(id, nazwa, typ, grupa_miesniowa)')
          .order('completed_at', ascending: false)
          .limit(50);
      final seen = <String>{};
      for (final s in recentSeries) {
        final id = s['cwiczenie_id'] as String;
        if (!seen.contains(id)) {
          seen.add(id);
          if (s['cwiczenia'] != null) recent.add(Map<String, dynamic>.from(s['cwiczenia']));
        }
      }
    } catch (_) {}

    setState(() {
      _all = List<Map<String, dynamic>>.from(all);
      _recent = recent;
      _filter();
      _loading = false;
    });
  }

  void _filter() {
    _filtered = _all.where((c) {
      final matchGroup = _filterGroup == 'All' || c['grupa_miesniowa'] == _filterGroup;
      final matchSearch = _search.isEmpty || c['nazwa'].toString().toLowerCase().contains(_search.toLowerCase());
      return matchGroup && matchSearch;
    }).toList();
  }

  Future<void> _addCustom() async {
    final nazwaCtrl = TextEditingController();
    String selectedGroup = 'Chest';
    String selectedType = 'bilateral';

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('New Exercise', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: nazwaCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(hintText: 'Exercise name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedGroup,
              dropdownColor: AppTheme.surface2,
              decoration: const InputDecoration(hintText: 'Muscle group'),
              items: ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Cardio']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setModal(() => selectedGroup = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setModal(() => selectedType = 'bilateral'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selectedType == 'bilateral' ? AppTheme.accent : AppTheme.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Bilateral', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => setModal(() => selectedType = 'unilateral'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selectedType == 'unilateral' ? AppTheme.orange : AppTheme.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Unilateral', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              )),
            ]),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (nazwaCtrl.text.trim().isEmpty) return;
                await _supabase.from('cwiczenia').insert({
                  'nazwa': nazwaCtrl.text.trim(),
                  'grupa_miesniowa': selectedGroup,
                  'typ': selectedType,
                  'custom': true,
                  'user_id': _supabase.auth.currentUser?.id,
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Add Exercise'),
            ),
          ]),
        ),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search exercises...',
                  border: InputBorder.none,
                  filled: false,
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                ),
                onChanged: (v) => setState(() { _search = v; _filter(); }),
              )
            : Text(widget.pickMode ? 'Add Exercise' : 'Exercises'),
        leading: widget.pickMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            : null,
        actions: [
          if (!widget.pickMode) ...[
            IconButton(icon: Icon(_searching ? Icons.close : Icons.search_rounded), onPressed: () {
              setState(() { _searching = !_searching; if (!_searching) { _search = ''; _filter(); } });
            }),
            IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addCustom),
          ] else
            IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {
              setState(() => _searching = true);
            }),
        ],
      ),
      body: Column(
        children: [
          // Group filter chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _groups.length,
              itemBuilder: (_, i) {
                final g = _groups[i];
                final sel = g == _filterGroup;
                return GestureDetector(
                  onTap: () => setState(() { _filterGroup = g; _filter(); }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.accent : AppTheme.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(g, style: TextStyle(
                      color: sel ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    )),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : ListView(
                    children: [
                      // Recent (only in non-search mode)
                      if (_recent.isNotEmpty && _search.isEmpty && _filterGroup == 'All') ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text('YOUR HISTORY', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        ),
                        ..._recent.map((c) => _ExerciseTile(exercise: c, pickMode: widget.pickMode)),
                        const Divider(height: 1),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text('ALL EXERCISES', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        ),
                      ],
                      ..._filtered.map((c) => _ExerciseTile(exercise: c, pickMode: widget.pickMode)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final bool pickMode;
  const _ExerciseTile({required this.exercise, required this.pickMode});

  @override
  Widget build(BuildContext context) {
    final isUnilateral = exercise['typ'] == 'unilateral';
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.fitness_center, color: AppTheme.textSecondary, size: 20),
      ),
      title: Text(exercise['nazwa'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(exercise['grupa_miesniowa'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUnilateral) Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.orange.withAlpha(38), borderRadius: BorderRadius.circular(5)),
            child: const Text('L/R', style: TextStyle(color: AppTheme.orange, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
        ],
      ),
      onTap: pickMode
          ? () => Navigator.pop(context, exercise)
          : () => context.push('/exercise/${exercise['id']}', extra: {'name': exercise['nazwa'], 'type': exercise['typ']}),
    );
  }
}
