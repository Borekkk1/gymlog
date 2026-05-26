import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/shell/app_shell.dart';
import '../features/feed/feed_screen.dart';
import '../features/feed/workout_detail_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/workout/workout_tab_screen.dart';
import '../features/workout/active_workout_screen.dart';
import '../features/workout/finish_workout_screen.dart';
import '../features/exercises/exercises_screen.dart';
import '../features/exercises/exercise_detail_screen.dart';
import '../features/more/more_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = state.matchedLocation.startsWith('/auth');
      if (session == null && !isAuth) return '/auth';
      if (session != null && isAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/auth/forgot', builder: (_, _) => const ForgotPasswordScreen()),
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
        path: '/workout/detail/:id',
        builder: (_, state) => WorkoutDetailScreen(workoutId: state.pathParameters['id']!),
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
