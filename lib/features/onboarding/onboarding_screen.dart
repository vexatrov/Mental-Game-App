import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sembast/sembast.dart';

import '../../data/providers.dart';
import '../../data/repository.dart';
import '../about/about_screen.dart';

/// Whether this device has seen the intro. Device state, so it lives in the
/// never-exported `meta` store.
abstract final class Onboarding {
  static const _docId = 'onboarding';

  static Future<bool> isDone(WidgetRef ref) async =>
      await Stores.ref(Stores.meta)
          .record(_docId)
          .get(ref.read(databaseProvider)) !=
      null;

  static Future<void> markDone(WidgetRef ref) => Stores.ref(Stores.meta)
      .record(_docId)
      .put(ref.read(databaseProvider), {'id': _docId, 'done': true});
}

class _Page {
  const _Page({
    required this.icon,
    required this.title,
    required this.body,
    this.points = const [],
  });

  final IconData icon;
  final String title;
  final String body;
  final List<(IconData, String)> points;
}

const _pages = [
  _Page(
    icon: Icons.menu_book_outlined,
    title: 'Welcome to Trader\'s Mind',
    body: 'A daily notebook for your mental game, built on the system Jared '
        'Tendler lays out in The Mental Game of Trading. His tools, organised '
        'so you can use them every session.',
  ),
  _Page(
    icon: Icons.wb_sunny_outlined,
    title: 'How a trading day works',
    body: 'Three moments, each a tap away on the Today screen.',
    points: [
      (Icons.wb_sunny_outlined,
          'Before the open: a short warm-up. Review your maps and drill your '
              'correction lines.'),
      (Icons.bolt,
          'While trading: quick notes, timed check-ins, and Reset when '
              'something starts building.'),
      (Icons.nights_stay_outlined,
          'After the close: a cool-down. Score your decisions and get the day '
              'out of your head.'),
    ],
  ),
  _Page(
    icon: Icons.psychology_outlined,
    title: 'Fix the cause, not the symptom',
    body: 'Emotions are signals. The app helps you read them and work back to '
        'what\'s driving them.',
    points: [
      (Icons.stacked_bar_chart,
          'Maps show how each emotion builds, level by level.'),
      (Icons.psychology,
          'Mental Hand Histories dig into the flawed logic behind a reaction.'),
      (Icons.show_chart,
          'Session scores and the Inchworm show your range moving forward.'),
    ],
  ),
  _Page(
    icon: Icons.lock_outline,
    title: 'Your notes stay yours',
    body: 'No account, no ads, no tracking. Everything is stored on this '
        'phone. Turn on automatic backup in Settings so you never lose it.',
    points: [
      (Icons.health_and_safety_outlined,
          'A self-help journal, not therapy or medical care.'),
      (Icons.trending_flat, 'Nothing here is financial advice.'),
    ],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await Onboarding.markDone(ref);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('onboardingSkip'),
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                    children: [
                      if (i == 0)
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset('assets/icon/icon.png',
                                width: 104, height: 104),
                          ),
                        )
                      else
                        Center(
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(page.icon,
                                size: 44,
                                color: theme.colorScheme.onPrimaryContainer),
                          ),
                        ),
                      const SizedBox(height: 28),
                      Text(page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 14),
                      Text(page.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      for (final (icon, text) in page.points)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, color: theme.colorScheme.primary),
                              const SizedBox(width: 14),
                              Expanded(child: Text(text)),
                            ],
                          ),
                        ),
                      if (i == 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'The app works on its own, but it makes the most '
                          'sense once you\'ve read the book.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => openLink(context, Links.book),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('About the book'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Independent app, not affiliated with the author or '
                          'publisher.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboardingNext'),
                  onPressed: last
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut),
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
