import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_state_provider.dart';
import 'glass_container.dart';

class WelcomeCard extends ConsumerWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showWelcome = ref.watch(showWelcomeProvider);

    if (!showWelcome) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.waving_hand, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Welcome to Essenmelia',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    ref.read(showWelcomeProvider.notifier).dismissWelcome();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your events, track steps, and organize your life with tags. Tap the + button to get started.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
