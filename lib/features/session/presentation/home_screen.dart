import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/widgets/error_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../application/session_providers.dart';
import 'widgets/session_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(authStateChangesProvider).value;
    final sessionsAsync = ref.watch(mySessionsProvider);

    final displayName = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!.trim()
        : (currentUser?.email?.split('@').first ?? 'there');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibzcheck'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mySessionsProvider);
            await Future<void>.delayed(const Duration(milliseconds: 350));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Welcome back, $displayName',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Start a session or join one your friends are running.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Start a session'),
                      onPressed: () => context.push('/create-session'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Join with code'),
                      onPressed: () => context.push('/join-session'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Your sessions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              sessionsAsync.when(
                data: (sessions) {
                  if (sessions.isEmpty) return const _EmptyState();
                  return Column(
                    children: [
                      for (final session in sessions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SessionCard(
                            session: session,
                            isOwner: session.ownerId == currentUser?.uid,
                            onTap: () =>
                                context.push('/session/${session.id}'),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => ErrorScreen(
                  error: error,
                  onRetry: () => ref.invalidate(mySessionsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.queue_music, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'No sessions yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start a session to build a shared queue, or ask a friend for '
              'their 6-character join code.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
