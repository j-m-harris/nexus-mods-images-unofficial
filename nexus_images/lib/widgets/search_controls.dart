import 'package:flutter/material.dart';
import '../models/nexus_image.dart';
import '../services/nexus_api.dart';

class SearchControls extends StatefulWidget {
  final List<NexusGame> games;
  final void Function({
    String? searchText,
    int? gameId,
    SortOption sort,
    int perPage,
  }) onSearch;

  const SearchControls({
    super.key,
    required this.games,
    required this.onSearch,
  });

  @override
  State<SearchControls> createState() => _SearchControlsState();
}

class _SearchControlsState extends State<SearchControls> {
  final _searchController = TextEditingController();
  final _gameFilterController = TextEditingController();
  SortOption _sort = SortOption.newest;
  int? _selectedGameId;
  int _perPage = 20;
  List<NexusGame> _filteredGames = [];

  @override
  void initState() {
    super.initState();
    _filteredGames = widget.games;
  }

  @override
  void didUpdateWidget(SearchControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.games != widget.games) {
      _filteredGames = widget.games;
    }
  }

  void _filterGames(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGames = widget.games;
        _selectedGameId = null;
      } else {
        final lower = query.toLowerCase();
        _filteredGames = widget.games
            .where((g) =>
                g.name.toLowerCase().contains(lower) ||
                g.domainName.toLowerCase().contains(lower))
            .toList();
        if (_filteredGames.isNotEmpty) {
          _selectedGameId = _filteredGames.first.id;
        }
      }
    });
  }

  void _doSearch() {
    widget.onSearch(
      searchText: _searchController.text.trim(),
      gameId: _selectedGameId,
      sort: _sort,
      perPage: _perPage,
    );
  }

  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filters',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD35400))),
              const SizedBox(height: 16),

              // Game filter
              const Text('Game',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(
                controller: _gameFilterController,
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Type to filter games...',
                ),
                onChanged: (val) {
                  _filterGames(val);
                  setSheetState(() {});
                },
              ),
              if (_filteredGames.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF2A2A4A)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    itemCount: _filteredGames.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return ListTile(
                          dense: true,
                          title: const Text('All Games',
                              style: TextStyle(
                                  color: Color(0xFFE0E0E0), fontSize: 13)),
                          selected: _selectedGameId == null,
                          selectedColor: const Color(0xFFD35400),
                          onTap: () {
                            setState(() => _selectedGameId = null);
                            setSheetState(() {});
                          },
                        );
                      }
                      final game = _filteredGames[i - 1];
                      return ListTile(
                        dense: true,
                        title: Text(game.name,
                            style: const TextStyle(
                                color: Color(0xFFE0E0E0), fontSize: 13)),
                        selected: _selectedGameId == game.id,
                        selectedColor: const Color(0xFFD35400),
                        onTap: () {
                          setState(() => _selectedGameId = game.id);
                          setSheetState(() {});
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Sort
              const Text('Sort By',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              DropdownButtonFormField<SortOption>(
                initialValue: _sort,
                dropdownColor: const Color(0xFF16213E),
                style:
                    const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
                items: SortOption.values
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s.label)))
                    .toList(),
                onChanged: (val) {
                  setState(() => _sort = val!);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 16),

              // Per page
              const Text('Per Page',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: _perPage.toString(),

                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: Color(0xFFE0E0E0), fontSize: 14),
                      onChanged: (val) {
                        final n = int.tryParse(val);
                        if (n != null && n >= 1 && n <= 50) {
                          setState(() => _perPage = n);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('(1-50)',
                      style:
                          TextStyle(color: Color(0xFF888888), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 20),

              // Search button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _doSearch();
                  },
                  child: const Text('Apply & Search'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search images...',
                prefixIcon:
                    Icon(Icons.search, color: Color(0xFF888888), size: 20),
                isDense: true,
              ),
              onSubmitted: (_) => _doSearch(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFFD35400)),
            onPressed: _showFiltersSheet,
            tooltip: 'Filters',
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _doSearch,
            child: const Text('Search'),
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
