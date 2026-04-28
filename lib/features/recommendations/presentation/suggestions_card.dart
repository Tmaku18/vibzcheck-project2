import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/application/session_controller.dart';
import '../application/recommendation_providers.dart';
import '../domain/suggestion.dart';

/// "Vibzcheck helper" card: shows the top-3 rule-based recommendations for
/// the session with explainable factors and a one-tap add-to-queue action.
class SuggestionsCard extends ConsumerWidget {
  const SuggestionsCard({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final suggestionsAsync =
        ref.watch(sessionSuggestionsProvider(sessionId));

    return Card(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 18, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  'Vibzcheck helper',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Rule-based · explainable',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            suggestionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Could not compute suggestions: $e',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              data: (suggestions) {
                if (suggestions.isEmpty) {
                  return Text(
                    'No suggestions yet. Add a couple of tracks and the '
                    'helper will propose what to play next.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final s in suggestions)
                      _SuggestionRow(suggestion: s, sessionId: sessionId),
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

class _SuggestionRow extends ConsumerStatefulWidget {
  const _SuggestionRow({required this.suggestion, required this.sessionId});

  final Suggestion suggestion;
  final String sessionId;

  @override
  ConsumerState<_SuggestionRow> createState() => _SuggestionRowState();
}

class _SuggestionRowState extends ConsumerState<_SuggestionRow> {
  bool _adding = false;
  bool _added = false;
  bool _expanded = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      await ref.read(sessionControllerProvider).addTrack(
            sessionId: widget.sessionId,
            track: widget.suggestion.track,
          );
      if (!mounted) return;
      setState(() {
        _adding = false;
        _added = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _adding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.suggestion;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${s.track.artist}  ·  ${s.primaryReason}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  s.score.toStringAsFixed(1),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                _added
                    ? Icon(Icons.check_circle,
                        color: theme.colorScheme.primary)
                    : IconButton(
                        tooltip: 'Add to queue',
                        onPressed: _adding ? null : _add,
                        icon: _adding
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_circle_outline),
                      ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final f in s.factors)
                      _FactorChip(
                        label: f.label,
                        weight: f.weight,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactorChip extends StatelessWidget {
  const _FactorChip({required this.label, required this.weight});

  final String label;
  final double weight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = weight >= 0;
    final color = positive
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label  ${positive ? '+' : ''}${weight.toStringAsFixed(2)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
