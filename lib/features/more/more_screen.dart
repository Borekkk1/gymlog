import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _exportData(BuildContext context) async {
    final supabase = Supabase.instance.client;
    try {
      final treningi = await supabase.from('treningi').select().eq('is_draft', false).order('started_at', ascending: false);
      final serie = await supabase.from('serie').select('*, cwiczenia(nazwa)');

      final lines = <String>['date,workout,exercise,set,kg,reps,side,note'];
      for (final t in treningi) {
        final wSeries = serie.where((s) => s['trening_id'] == t['id']).toList();
        for (final s in wSeries) {
          lines.add([
            t['started_at'],
            t['nazwa'] ?? '',
            s['cwiczenia']?['nazwa'] ?? '',
            s['numer_serii'],
            s['ciezar'],
            s['powt'],
            s['strona'] ?? '',
            s['note'] ?? '',
          ].join(','));
        }
      }

      final csv = lines.join('\n');
      await Clipboard.setData(ClipboardData(text: csv));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${treningi.length} workouts copied to clipboard as CSV'),
          backgroundColor: AppTheme.surface2,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.accent));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Not logged in';
    final unit = ref.watch(unitProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('More', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: const BoxDecoration(color: AppTheme.surface2, shape: BoxShape.circle),
                      child: const Icon(Icons.person, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email.split('@').first, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    )),
                  ]),
                ),
              ),
              _Section(title: 'DATA', items: [
                _Item(icon: Icons.download_outlined, label: 'Export Data (CSV)', onTap: () => _exportData(context)),
              ]),
              _Section(title: 'SETTINGS', items: [
                _Item(
                  icon: Icons.fitness_center_outlined,
                  label: 'Units',
                  trailing: unit,
                  onTap: () => ref.read(unitProvider.notifier).toggle(),
                ),
              ]),
              _Section(title: 'ACCOUNT', items: [
                _Item(icon: Icons.logout_rounded, label: 'Sign Out', isDestructive: true,
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/auth');
                  }),
              ]),
              const SizedBox(height: 32),
              const Text('GymLog v1.0', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Item> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
      ),
      Container(
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(children: items.asMap().entries.map((e) => Column(children: [
          e.value,
          if (e.key < items.length - 1) const Divider(height: 1, indent: 56),
        ])).toList()),
      ),
      const SizedBox(height: 16),
    ]),
  );
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool isDestructive;
  final VoidCallback onTap;

  const _Item({required this.icon, required this.label, this.trailing, this.isDestructive = false, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: isDestructive ? AppTheme.accent : AppTheme.textSecondary, size: 22),
    title: Text(label, style: TextStyle(color: isDestructive ? AppTheme.accent : AppTheme.textPrimary, fontSize: 15)),
    trailing: trailing != null
        ? Text(trailing!, style: const TextStyle(color: AppTheme.textSecondary))
        : const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
    onTap: onTap,
  );
}
