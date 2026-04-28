import 'package:flutter/material.dart';

import '../../domain/queue_track.dart';

/// Single row in the shared queue list. Handles its own vote button states
/// while delegating the actual transaction to the provided callbacks.
class QueueTrackTile extends StatelessWidget {
  const QueueTrackTile({
    super.key,
    required this.track,
    required this.currentUserId,
    required this.onUpvote,
    required this.onDownvote,
    this.onRemove,
    this.rank,
  });

  final QueueTrack track;
  final String currentUserId;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback? onRemove;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myVote = track.voteOf(currentUserId);
    final upColor =
        myVote > 0 ? theme.colorScheme.primary : theme.colorScheme.outline;
    final downColor =
        myVote < 0 ? theme.colorScheme.error : theme.colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            if (rank != null) ...[
              SizedBox(
                width: 24,
                child: Text(
                  '${rank!}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: track.artworkUrl != null
                    ? Image.network(
                        track.artworkUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _ArtworkFallback(
                          color: theme.colorScheme.surfaceContainerHigh,
                        ),
                      )
                    : _ArtworkFallback(
                        color: theme.colorScheme.surfaceContainerHigh,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Added by ${track.addedByName}  ·  ${track.durationLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Upvote',
                  onPressed: onUpvote,
                  icon: Icon(Icons.thumb_up_outlined, color: upColor),
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  '${track.voteScore}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: 'Downvote',
                  onPressed: onDownvote,
                  icon: Icon(Icons.thumb_down_outlined, color: downColor),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Remove from queue',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: const Icon(Icons.music_note),
    );
  }
}
