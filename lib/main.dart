import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://vderfviqeeacpboannlo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkZXJmdmlxZWVhY3Bib2FubmxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUyNDU4NzAsImV4cCI6MjA5MDgyMTg3MH0.Dhn_leiQGA1ukzz4h9EqyhjyhvlWMR96FsBRxHM7yic',
  );
  runApp(const ProviderScope(child: GymLogApp()));
}

class GymLogApp extends ConsumerWidget {
  const GymLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GymLog',
      theme: AppTheme.dark(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
