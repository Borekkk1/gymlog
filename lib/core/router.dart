import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/shell/app_shell.dart';
import '../features/feed/feed_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/workout/workout_tab_screen.dart';
import '../features/workout/active_workout_screen.dart';
import '../features/workout/finish_workout_screen.dart';
import '../features/exercises/exercises_screen.dart';
import '../features/exercises/exercise_detail_screen.dart';
import '../features/more/more_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) => null, // TODO: re-enable auth before iOS build
    routes: [
      GoRoute(
        path: '/workout/active',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ActiveWorkoutScreen(
            templateId: extra?['templateId'],
            repeatWorkoutId: extra?['repeatWorkoutId'],
          );
        },
      ),
      GoRoute(
        path: '/workout/finish',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return FinishWorkoutScreen(workoutData: extra);
        },
      ),
      GoRoute(
        path: '/exercise/:id',
        builder: (_, state) => ExerciseDetailScreen(
          exerciseId: state.pathParameters['id']!,
          exerciseName: (state.extra as Map?)?['name'] ?? '',
          exerciseType: (state.extra as Map?)?['type'] ?? 'bilateral',
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const FeedScreen()),
          GoRoute(path: '/analytics', builder: (_, _) => const AnalyticsScreen()),
          GoRoute(path: '/workout', builder: (_, _) => const WorkoutTabScreen()),
          GoRoute(path: '/exercises', builder: (_, _) => const ExercisesScreen()),
          GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
        ],
      ),
    ],
  );
});
