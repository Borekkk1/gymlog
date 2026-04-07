import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _index(String loc) {
    if (loc.startsWith('/analytics')) return 1;
    if (loc.startsWith('/workout')) return 2;
    if (loc.startsWith('/exercises')) return 3;
    if (loc.startsWith('/more')) return 4;
    return 0;
  }

  void _onTap(BuildContext ctx, int i) {
    switch (i) {
      case 0: ctx.go('/');
      case 1: ctx.go('/analytics');
      case 2: ctx.go('/workout');
      case 3: ctx.go('/exercises');
      case 4: ctx.go('/more');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _index(loc),
            onTap: (i) => _onTap(context, i),
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Feed'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Analytics'),
              BottomNavigationBarItem(icon: Icon(Icons.directions_run_outlined), activeIcon: Icon(Icons.directions_run), label: 'Workout'),
              BottomNavigationBarItem(icon: Icon(Icons.fitness_center_outlined), activeIcon: Icon(Icons.fitness_center), label: 'Exercises'),
              BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
            ],
          ),
        ),
      ),
    );
  }
}
