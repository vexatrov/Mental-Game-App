import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/about/about_screen.dart';
import 'features/drill/drill_screen.dart';
import 'features/game/analysis_editor_screen.dart';
import 'features/game/game_screen.dart';
import 'features/game/session_editor_screen.dart';
import 'features/home/home_screen.dart';
import 'features/journal/journal_editor_screen.dart';
import 'features/journal/journal_screen.dart';
import 'features/maps/map_editor_screen.dart';
import 'features/maps/map_history_screen.dart';
import 'features/maps/map_review_screen.dart';
import 'features/maps/maps_screen.dart';
import 'features/mhh/mhh_editor_screen.dart';
import 'features/mhh/mhh_screen.dart';
import 'features/reset/reset_screen.dart';
import 'features/routine/check_in_ticker.dart';
import 'features/routine/routine_screen.dart';
import 'domain/routine.dart';
import 'features/settings/settings_screen.dart';
import 'services/auto_backup.dart';

GoRouter buildRouter() {
  final rootKey = GlobalKey<NavigatorState>();
  String? q(GoRouterState s, String key) => s.uri.queryParameters[key];

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/journal', builder: (_, _) => const JournalScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/mhh', builder: (_, _) => const MhhScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/maps', builder: (_, _) => const MapsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/game', builder: (_, _) => const GameScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/journal/edit',
        builder: (_, s) => JournalEditorScreen(
          id: q(s, 'id'),
          initialProblem: q(s, 'problem'),
        ),
      ),
      GoRoute(
        path: '/mhh/edit',
        builder: (_, s) =>
            MhhEditorScreen(id: q(s, 'id'), fromEntryId: q(s, 'entry')),
      ),
      GoRoute(
        path: '/maps/edit',
        builder: (_, s) => MapEditorScreen(id: q(s, 'id')!),
      ),
      GoRoute(
        path: '/maps/review',
        builder: (_, _) => const MapReviewScreen(),
      ),
      GoRoute(
        path: '/maps/history',
        builder: (_, s) => MapHistoryScreen(seriesId: q(s, 'series')!),
      ),
      GoRoute(
        path: '/game/session',
        builder: (_, s) => SessionEditorScreen(id: q(s, 'id')),
      ),
      GoRoute(
        path: '/game/analysis',
        builder: (_, _) => const AnalysisEditorScreen(),
      ),
      GoRoute(
        path: '/reset',
        builder: (_, s) => ResetScreen(initialProblem: q(s, 'problem')),
      ),
      GoRoute(
        path: '/drill',
        builder: (_, _) => const DrillScreen(),
      ),
      GoRoute(
        path: '/routine',
        builder: (_, s) =>
            RoutineScreen(phase: RoutinePhase.parse(q(s, 'phase'))),
      ),
      GoRoute(
        path: '/about',
        builder: (_, _) => const AboutScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});

class MentalGameApp extends ConsumerStatefulWidget {
  const MentalGameApp({super.key});

  static const seed = Color(0xFF2E7D74);

  @override
  ConsumerState<MentalGameApp> createState() => _MentalGameAppState();
}

class _MentalGameAppState extends ConsumerState<MentalGameApp>
    with WidgetsBindingObserver {
  bool _backingUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _backup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Leaving the app is the natural moment to save: nothing is mid-edit.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backup();
    }
  }

  Future<void> _backup() async {
    if (_backingUp) return;
    _backingUp = true;
    try {
      await ref.read(autoBackupProvider).run();
    } catch (_) {
      // Errors are recorded on the backup state and shown in Settings.
    } finally {
      _backingUp = false;
    }
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
        seedColor: MentalGameApp.seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "Trader's Mind",
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CheckInTicker(child: shell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note),
              label: 'Journal'),
          NavigationDestination(
              icon: Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology),
              label: 'Hand History'),
          NavigationDestination(
              icon: Icon(Icons.stacked_bar_chart_outlined),
              selectedIcon: Icon(Icons.stacked_bar_chart),
              label: 'Maps'),
          NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart),
              label: 'Game'),
        ],
      ),
    );
  }
}
