import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_controller.dart';
import '../data/track_search_repository.dart';
import '../domain/track.dart';

class AddTrackScreen extends ConsumerStatefulWidget {
  const AddTrackScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<AddTrackScreen> createState() => _AddTrackScreenState();
}

class _AddTrackScreenState extends ConsumerState<AddTrackScreen> {
  static const _moodFilters = <String>[
    'hype',
    'chill',
    'feelgood',
    'dance',
    'melancholy',
    'moody',
    'synth',
    'rap',
  ];

  final _searchController = TextEditingController();
  List<Track> _results = const [];
  Timer? _debounce;
  bool _searching = false;
  final Set<String> _addedIds = <String>{};
  String? _selectedMood;

  Iterable<Track> get _filteredResults {
    final mood = _selectedMood;
    if (mood == null) return _results;
    return _results.where((t) => t.moodTags.contains(mood));
  }

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(trackSearchRepositoryProvider)
          .search(query);
      if (!mounted) return;
      setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addToQueue(Track track) async {
    final id = '${track.source.asString}_${track.sourceId}';
    setState(() => _addedIds.add(id));
    try {
      await ref.read(sessionControllerProvider).addTrack(
            sessionId: widget.sessionId,
            track: track,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "${track.title}"')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _addedIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a track'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search tracks, artists, moods...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _runSearch('');
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _moodFilters.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedMood == null,
                      onSelected: (_) =>
                          setState(() => _selectedMood = null),
                    );
                  }
                  final mood = _moodFilters[i - 1];
                  return ChoiceChip(
                    label: Text('#$mood'),
                    selected: _selectedMood == mood,
                    onSelected: (selected) => setState(
                      () => _selectedMood = selected ? mood : null,
                    ),
                  );
                },
              ),
            ),
            if (_searching)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            Expanded(
              child: Builder(builder: (_) {
                final filtered = _filteredResults.toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _selectedMood != null
                            ? 'No tracks tagged #$_selectedMood match '
                                '"${_searchController.text}".'
                            : 'No tracks match "${_searchController.text}".',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final track = filtered[i];
                        final id =
                            '${track.source.asString}_${track.sourceId}';
                        final added = _addedIds.contains(id);
                        return Card(
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: track.artworkUrl != null
                                    ? Image.network(
                                        track.artworkUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: theme
                                              .colorScheme.surfaceContainerHigh,
                                          child: const Icon(Icons.music_note),
                                        ),
                                      )
                                    : Container(
                                        color: theme
                                            .colorScheme.surfaceContainerHigh,
                                        child: const Icon(Icons.music_note),
                                      ),
                              ),
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${track.artist}  ·  ${track.durationLabel}'
                              '${track.moodTags.isNotEmpty ? '  ·  ${track.moodTags.join(', ')}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: added
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  )
                                : IconButton(
                                    tooltip: 'Add to queue',
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => _addToQueue(track),
                                  ),
                          ),
                        );
                      },
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
