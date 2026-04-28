import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/widgets/error_screen.dart';
import '../../../core/widgets/loading_screen.dart';
import '../application/mood_summary.dart';
import '../application/session_controller.dart';
import '../application/session_providers.dart';
import '../domain/queue_track.dart';
import '../domain/session.dart';
import 'widgets/queue_track_tile.dart';

/// Live view of a single session: header with code + members, shared queue
/// with transaction-backed vote buttons, and an FAB to add a track.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionByIdProvider(sessionId));
    final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';

    return sessionAsync.when(
      loading: () => const LoadingScreen(message: 'Loading session...'),
      error: (e, _) => ErrorScreen(
        error: e,
        onRetry: () => ref.invalidate(sessionByIdProvider(sessionId)),
      ),
      data: (session) {
        if (session == null) {
          return _SessionNotFound(onBack: () => context.go('/'));
        }
        return _SessionView(session: session, currentUid: currentUid);
      },
    );
  }
}

class _SessionView extends ConsumerWidget {
  const _SessionView({required this.session, required this.currentUid});

  final Session session;
  final String currentUid;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(sessionControllerProvider);
    final navigator = GoRouter.of(context);
    try {
      await controller.leave(session.id);
      navigator.go('/');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not leave: $e')),
      );
    }
  }

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this session?'),
        content: const Text('Members will no longer be able to vote or add '
            'tracks. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final controller = ref.read(sessionControllerProvider);
    final navigator = GoRouter.of(context);
    try {
      await controller.end(session.id);
      navigator.go('/');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not end session: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queueAsync = ref.watch(sessionQueueProvider(session.id));
    final membersAsync = ref.watch(sessionMembersProvider(session.id));
    final isOwner = session.ownerId == currentUid;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Open chat',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => context.push('/session/${session.id}/chat'),
          ),
          if (isOwner)
            IconButton(
              tooltip: 'End session',
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: () => _end(context, ref),
            )
          else
            IconButton(
              tooltip: 'Leave session',
              icon: const Icon(Icons.logout),
              onPressed: () => _leave(context, ref),
            ),
        ],
      ),
      floatingActionButton: session.status == SessionStatus.ended
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/session/${session.id}/add-track'),
              icon: const Icon(Icons.add),
              label: const Text('Add track'),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            _SessionHeaderCard(
              session: session,
              mood: computeMoodSummary(queueAsync.value ?? const <QueueTrack>[]),
            ),
            const SizedBox(height: 16),
            membersAsync.when(
              data: (members) => _MembersStrip(
                memberDisplayNames:
                    members.map((m) => m.displayName).toList(),
              ),
              loading: () => const SizedBox(height: 36),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Queue',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${session.queueCount} track${session.queueCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            queueAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorScreen(
                error: e,
                onRetry: () =>
                    ref.invalidate(sessionQueueProvider(session.id)),
              ),
              data: (tracks) {
                if (tracks.isEmpty) return const _EmptyQueue();
                return Column(
                  children: [
                    for (var i = 0; i < tracks.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: QueueTrackTile(
                          track: tracks[i],
                          currentUserId: currentUid,
                          rank: i + 1,
                          onUpvote: () => ref
                              .read(sessionControllerProvider)
                              .castVote(
                                sessionId: session.id,
                                trackDocId: tracks[i].id,
                                direction: 1,
                              ),
                          onDownvote: () => ref
                              .read(sessionControllerProvider)
                              .castVote(
                                sessionId: session.id,
                                trackDocId: tracks[i].id,
                                direction: -1,
                              ),
                          onRemove: (isOwner ||
                                  tracks[i].addedBy == currentUid)
                              ? () => ref
                                  .read(sessionControllerProvider)
                                  .removeTrack(
                                    sessionId: session.id,
                                    trackDocId: tracks[i].id,
                                  )
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionHeaderCard extends StatelessWidget {
  const _SessionHeaderCard({required this.session, required this.mood});
  final Session session;
  final MoodSummary? mood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hosted by ${session.ownerName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Join code',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        session.code,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: session.code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mood == null
                        ? 'Mood: set the vibe with your first upvoted track'
                        : 'Mood: #${mood!.top}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersStrip extends StatelessWidget {
  const _MembersStrip({required this.memberDisplayNames});
  final List<String> memberDisplayNames;

  @override
  Widget build(BuildContext context) {
    if (memberDisplayNames.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: memberDisplayNames.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Chip(
          avatar: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              memberDisplayNames[i].isNotEmpty
                  ? memberDisplayNames[i][0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          label: Text(memberDisplayNames[i]),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.playlist_add, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Nothing queued yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "Add track" to search and queue the first song. '
              'Members can upvote and downvote to shape the order.',
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

class _SessionNotFound extends StatelessWidget {
  const _SessionNotFound({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_off, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Session not found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The session may have ended or you may have lost access.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: onBack, child: const Text('Go home')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
