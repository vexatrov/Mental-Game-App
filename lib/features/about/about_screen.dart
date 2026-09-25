import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/widgets.dart';

abstract final class Links {
  static final book =
      Uri.parse('https://jaredtendler.com/books/the-mental-game-of-trading/');
  static final author = Uri.parse('https://jaredtendler.com/');
  static final privacy = Uri.parse(
      'https://github.com/vexatrov/Mental-Game-App/blob/HEAD/docs/privacy-policy.md');
  static final source = Uri.parse('https://github.com/vexatrov/Mental-Game-App');
}

Future<void> openLink(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Couldn\'t open $uri')));
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/icon/icon.png', width: 56, height: 56),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trader\'s Mind', style: theme.textTheme.titleLarge),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (_, snap) => Text(
                        snap.hasData
                            ? 'Version ${snap.data!.version} (${snap.data!.buildNumber})'
                            : '',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SectionHeader('Built on Jared Tendler\'s work'),
          const Text(
            'The tools in this app (mapping your pattern, the Mental Hand '
            'History, the A- to C-game analysis, the Inchworm, Injecting Logic '
            'and the Strategic Reminder) were created by Jared Tendler and are '
            'explained in his book The Mental Game of Trading. This app is a '
            'notebook for putting them into practice every day.',
          ),
          const SizedBox(height: 8),
          const Text(
            'The app works best alongside the book: it explains why each tool '
            'works and how to use it well. If you haven\'t read it yet, we '
            'recommend starting there.',
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('openBook'),
            onPressed: () => openLink(context, Links.book),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Get The Mental Game of Trading'),
          ),
          TextButton(
            onPressed: () => openLink(context, Links.author),
            child: const Text('Jared Tendler\'s website'),
          ),
          const SizedBox(height: 4),
          Text(
            'Trader\'s Mind is an independent app. It is not affiliated with, '
            'endorsed by, or sponsored by Jared Tendler or his publisher.',
            style: theme.textTheme.bodySmall,
          ),
          const SectionHeader('Important'),
          const _Note(
            icon: Icons.health_and_safety_outlined,
            text: 'This is a self-help journal, not therapy or medical care. '
                'If trading is harming your wellbeing, or you are in crisis, '
                'please reach out to a licensed professional or local '
                'emergency services.',
          ),
          const _Note(
            icon: Icons.trending_flat,
            text: 'Nothing in this app is financial or investment advice. '
                'Trading involves risk of loss.',
          ),
          const _Note(
            icon: Icons.lock_outline,
            text: 'Your entries stay on your phone. The app has no account, no '
                'tracking and no ads. Backups go only where you choose.',
          ),
          const SectionHeader('More'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: () => openLink(context, Links.privacy),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code),
            title: const Text('Source code'),
            onTap: () => openLink(context, Links.source),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Trader\'s Mind',
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
