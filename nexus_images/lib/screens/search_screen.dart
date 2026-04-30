import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/nexus_image.dart';
import '../services/nexus_api.dart';
import '../theme.dart';

class SearchScreen extends StatefulWidget {
  final List<NexusGame> games;
  final void Function({
    String? searchText,
    int? gameId,
    SortOption sort,
    int perPage,
  }) onSearch;
  final VoidCallback? onCancel;

  const SearchScreen({
    super.key,
    required this.games,
    required this.onSearch,
    this.onCancel,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _gameFilterController = TextEditingController();
  SortOption _sort = SortOption.newest;
  int? _selectedGameId;
  String? _selectedGameName;
  int _perPage = 20;

  void _doSearch() {
    FocusScope.of(context).unfocus();
    widget.onSearch(
      searchText: _searchController.text.trim(),
      gameId: _selectedGameId,
      sort: _sort,
      perPage: _perPage,
    );
  }

  void _showGamePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NexusColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        var filtered = widget.games.toList();
        return StatefulBuilder(
          builder: (ctx, setSheetState) => SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NexusColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _gameFilterController,
                    style: const TextStyle(
                        color: NexusColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search games...',
                      prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                          color: NexusColors.textMuted, size: 20),
                    ),
                    onChanged: (val) {
                      final lower = val.toLowerCase();
                      setSheetState(() {
                        filtered = val.isEmpty
                            ? widget.games
                            : widget.games
                                .where((g) =>
                                    g.name.toLowerCase().contains(lower) ||
                                    g.domainName
                                        .toLowerCase()
                                        .contains(lower))
                                .toList();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: NexusColors.border,
                            child: Icon(PhosphorIcons.squaresFour(),
                                color: NexusColors.textMuted, size: 18),
                          ),
                          title: const Text('All Games',
                              style:
                                  TextStyle(color: NexusColors.textPrimary)),
                          selected: _selectedGameId == null,
                          selectedColor: NexusColors.primary,
                          onTap: () {
                            setState(() {
                              _selectedGameId = null;
                              _selectedGameName = null;
                            });
                            _gameFilterController.clear();
                            Navigator.pop(ctx);
                          },
                        );
                      }
                      final game = filtered[i - 1];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: NexusColors.border,
                          child: Text(
                            game.name.isNotEmpty
                                ? game.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: NexusColors.primary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(game.name,
                            style: const TextStyle(
                                color: NexusColors.textPrimary)),
                        subtitle: Text(
                          '${game.formattedDownloads} downloads · ${game.formattedMods} mods',
                          style: const TextStyle(
                              color: NexusColors.textMuted, fontSize: 12),
                        ),
                        selected: _selectedGameId == game.id,
                        selectedColor: NexusColors.primary,
                        onTap: () {
                          setState(() {
                            _selectedGameId = game.id;
                            _selectedGameName = game.name;
                          });
                          _gameFilterController.clear();
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top + kToolbarHeight;
    const navBarHeight = 48.0;
    final bottomInset = media.padding.bottom + navBarHeight;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, bottomInset + 16),
        children: [
          if (widget.onCancel != null)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  widget.onCancel!();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    PhosphorIcons.x(PhosphorIconsStyle.bold),
                    size: 18,
                    color: NexusColors.textMuted,
                  ),
                ),
              ),
            ),
          if (widget.onCancel != null) const SizedBox(height: 4),
          // Search field
          TextField(
            controller: _searchController,
            style:
                const TextStyle(color: NexusColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search images...',
              prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                  color: NexusColors.textMuted),
              filled: true,
              fillColor: NexusColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _doSearch(),
          ),
          const SizedBox(height: 20),

          // Game selector
          const Text('GAME',
              style: TextStyle(
                  fontSize: 11,
                  color: NexusColors.textMuted,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showGamePicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: NexusColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.gameController(),
                      color: NexusColors.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedGameName ?? 'All Games',
                      style: TextStyle(
                        color: _selectedGameName != null
                            ? NexusColors.textPrimary
                            : NexusColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(PhosphorIcons.caretRight(),
                      color: NexusColors.textMuted, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sort
          const Text('SORT BY',
              style: TextStyle(
                  fontSize: 11,
                  color: NexusColors.textMuted,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SortOption.values.map((s) {
              final isActive = s == _sort;
              return GestureDetector(
                onTap: () => setState(() => _sort = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? NexusColors.primary
                        : NexusColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.label,
                    style: TextStyle(
                      color: isActive
                          ? NexusColors.textPrimary
                          : NexusColors.textMuted,
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Search button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _doSearch,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Search',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _gameFilterController.dispose();
    super.dispose();
  }
}
