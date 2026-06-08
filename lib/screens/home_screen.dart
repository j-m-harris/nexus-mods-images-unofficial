import 'dart:math';
import 'package:flutter/material.dart';
import '../models/nexus_image.dart';
import '../services/nexus_api.dart';
import '../theme.dart';
import '../widgets/image_card.dart';
import '../widgets/image_grid_tile.dart';
import '../widgets/planetarium_view.dart';
import '../widgets/facets_bar.dart';
import '../widgets/lightbox.dart';
import '../widgets/skeleton_card.dart';
import 'search_screen.dart';

/// The available layouts for the main listing.
enum FeedLayout { list, grid, sphere }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _navBarHeight = 48;

  int _currentTab = 0;
  FeedLayout _layout = FeedLayout.list;

  final ScrollController _scrollController = ScrollController();
  List<NexusGame> _games = [];
  List<NexusImage> _images = [];
  List<FacetItem> _facets = [];
  Map<String, Set<String>> _activeFacets = {};

  int _totalCount = 0;
  int _currentOffset = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _fetchGeneration = 0;

  String? _searchText;
  int? _gameId;
  SortOption _sort = SortOption.newest;
  int _perPage = 20;
  int? _randomSeed;

  bool get _hasActiveSearch =>
      (_searchText != null && _searchText!.isNotEmpty) || _gameId != null;

  bool get _hasNonDefaultSort => _sort != SortOption.newest;

  String get _searchSummary {
    final parts = <String>[];
    if (_searchText != null && _searchText!.isNotEmpty) {
      parts.add('"$_searchText"');
    }
    if (_gameId != null) {
      final game = _games.where((g) => g.id == _gameId).firstOrNull;
      if (game != null) parts.add(game.name);
    }
    return parts.join(' in ');
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadGames();
    _performSearch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGames() async {
    try {
      final games = await NexusApi.loadGames();
      if (mounted) setState(() => _games = games);
    } catch (e) {
      debugPrint('Failed to load games: $e');
    }
  }

  void _onScroll() {
    if (_loadingMore || _currentOffset >= _totalCount) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 600) {
      _loadNextPage();
    }
  }

  Future<void> _performSearch() async {
    final generation = ++_fetchGeneration;
    _randomSeed =
        _sort == SortOption.random ? Random().nextInt(100000) : null;
    setState(() {
      _loading = true;
      _error = null;
      _images = [];
      _currentOffset = 0;
      _totalCount = 0;
    });

    try {
      final result = await NexusApi.search(
        searchText: _searchText,
        gameId: _gameId,
        sort: _sort,
        offset: 0,
        count: _perPage,
        activeFacets: _activeFacets,
        randomSeed: _randomSeed,
      );
      if (generation != _fetchGeneration || !mounted) return;
      setState(() {
        _images = result.nodes;
        _totalCount = result.totalCount;
        _currentOffset = result.nodes.length;
        _facets = result.facets;
        _loading = false;
      });
    } catch (e) {
      if (generation != _fetchGeneration || !mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || _currentOffset >= _totalCount) return;
    final generation = _fetchGeneration;
    setState(() => _loadingMore = true);

    try {
      final result = await NexusApi.search(
        searchText: _searchText,
        gameId: _gameId,
        sort: _sort,
        offset: _currentOffset,
        count: _perPage,
        activeFacets: _activeFacets,
        randomSeed: _randomSeed,
      );
      if (generation != _fetchGeneration || !mounted) return;
      final seenIds = _images.map((img) => img.id).toSet();
      final newNodes =
          result.nodes.where((img) => seenIds.add(img.id)).toList();
      setState(() {
        _images.addAll(newNodes);
        _totalCount = result.totalCount;
        _currentOffset += result.nodes.length;
        _facets = result.facets;
        _loadingMore = false;
      });
    } catch (e) {
      if (generation != _fetchGeneration || !mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _toggleFacet(String facetName, String value) {
    setState(() {
      _activeFacets.putIfAbsent(facetName, () => {});
      if (_activeFacets[facetName]!.contains(value)) {
        _activeFacets[facetName]!.remove(value);
        if (_activeFacets[facetName]!.isEmpty) {
          _activeFacets.remove(facetName);
        }
      } else {
        _activeFacets[facetName]!.add(value);
      }
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _performSearch();
  }

  void _addFacet(String facetName, String value) {
    final existing = _activeFacets[facetName];
    if (existing != null && existing.contains(value)) return;
    setState(() {
      _activeFacets.putIfAbsent(facetName, () => {}).add(value);
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _performSearch();
  }

  void _openLightbox(NexusImage image) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => LightboxView(image: image),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _goHome() {
    setState(() {
      _searchText = null;
      _gameId = null;
      _sort = SortOption.newest;
      _activeFacets = {};
      _currentTab = 0;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _performSearch();
    _showToast('All filters removed');
  }

  void _refreshFeed() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _performSearch();
    _showToast('Showing latest results');
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: NexusColors.textPrimary),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: NexusColors.darkBrown,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
  }

  void _onSearchSubmitted({
    String? searchText,
    int? gameId,
    SortOption sort = SortOption.newest,
    int perPage = 20,
  }) {
    _searchText = searchText;
    _gameId = gameId;
    _sort = sort;
    _perPage = perPage;
    _activeFacets = {};
    setState(() => _currentTab = 0);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _performSearch();
  }

  void _filterByGameDomain(String domain) {
    final game = _games.where((g) => g.domainName == domain).firstOrNull;
    if (game == null) return;
    if (_gameId == game.id) return;
    setState(() {
      _gameId = game.id;
      _currentTab = 0;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _performSearch();
  }

  void _clearSearch() {
    setState(() {
      _searchText = null;
      _gameId = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _performSearch();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.background,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: NexusColors.surface,
        title: Row(
          children: [
            GestureDetector(
              onTap: _goHome,
              child: Image.asset(
                'assets/icon.png',
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nexus Mods Images Unofficial',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: NexusColors.primary,
                    ),
                  ),
                  if (_hasActiveSearch || _hasNonDefaultSort)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_hasActiveSearch) ...[
                          Flexible(
                            child: Text(
                              _searchSummary,
                              style: const TextStyle(
                                fontSize: 12,
                                color: NexusColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: _clearSearch,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 8, 2),
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: NexusColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                        if (_hasNonDefaultSort) ...[
                          if (_hasActiveSearch) const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _sort.label,
                              style: const TextStyle(
                                fontSize: 11,
                                color: NexusColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_currentTab == 0)
            PopupMenuButton<SortOption>(
              icon: Icon(Icons.swap_vert,
                  color: NexusColors.textPrimary),
              color: NexusColors.surface,
              onSelected: (sort) {
                _sort = sort;
                if (_scrollController.hasClients) _scrollController.jumpTo(0);
                _performSearch();
              },
              itemBuilder: (_) => SortOption.values
                  .map((s) => PopupMenuItem(
                        value: s,
                        child: Text(
                          s.label,
                          style: TextStyle(
                            color: s == _sort
                                ? NexusColors.primary
                                : NexusColors.textPrimary,
                            fontWeight: s == _sort
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
        elevation: 0,
      ),
      body: Stack(
        children: [
          Offstage(
            offstage: _currentTab != 0,
            child: TickerMode(
              enabled: _currentTab == 0,
              child: _buildFeed(),
            ),
          ),
          Offstage(
            offstage: _currentTab != 1,
            child: TickerMode(
              enabled: _currentTab == 1,
              child: SearchScreen(
                games: _games,
                onSearch: _onSearchSubmitted,
                onCancel: () => setState(() => _currentTab = 0),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  IconData get _layoutIcon {
    switch (_layout) {
      case FeedLayout.list:
        return Icons.view_agenda_outlined;
      case FeedLayout.grid:
        return Icons.grid_view;
      case FeedLayout.sphere:
        return Icons.public;
    }
  }

  void _cycleLayout() {
    setState(() {
      _layout = FeedLayout
          .values[(_layout.index + 1) % FeedLayout.values.length];
    });
  }

  Widget _buildBottomNav() {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return Container(
      height: _navBarHeight + bottomSafe,
      padding: EdgeInsets.only(bottom: bottomSafe),
      decoration: const BoxDecoration(
        color: NexusColors.surface,
        border: Border(
          top: BorderSide(color: NexusColors.border, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navButton(
            icon: _currentTab == 0
                ? Icons.home
                : Icons.home_outlined,
            active: _currentTab == 0,
            onTap: () {
              if (_currentTab == 0) {
                _goHome();
              } else {
                setState(() => _currentTab = 0);
              }
            },
          ),
          _navButton(
            icon: _currentTab == 1
                ? Icons.search
                : Icons.search,
            active: _currentTab == 1,
            onTap: () => setState(() => _currentTab = 1),
          ),
          _navButton(
            icon: _layoutIcon,
            active: _layout != FeedLayout.list,
            onTap: _cycleLayout,
          ),
          _navButton(
            icon: Icons.refresh,
            active: false,
            onTap: _refreshFeed,
          ),
        ],
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _navBarHeight,
          child: Center(
            child: Icon(
              icon,
              color: NexusColors.textMuted,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top + kToolbarHeight;
    final bottomInset = media.padding.bottom + _navBarHeight;

    if (_loading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
        itemCount: 5,
        itemBuilder: (_, __) => const SkeletonCard(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error: $_error',
                style: const TextStyle(color: NexusColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _performSearch,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_images.isEmpty) {
      return const Center(
        child: Text(
          'No images found.',
          style: TextStyle(color: NexusColors.textMuted, fontSize: 16),
        ),
      );
    }

    if (_layout == FeedLayout.sphere) {
      return Padding(
        padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
        child: PlanetariumView(
          images: _images,
          onImageTap: _openLightbox,
          active: _currentTab == 0,
        ),
      );
    }

    return RefreshIndicator(
      color: NexusColors.primary,
      backgroundColor: NexusColors.surface,
      onRefresh: () async {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
        await _performSearch();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topInset)),
          if (_facets.isNotEmpty)
            SliverToBoxAdapter(
              child: FacetsBar(
                facets: _facets,
                activeFacets: _activeFacets,
                onToggle: _toggleFacet,
              ),
            ),
          if (_layout == FeedLayout.grid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ImageGridTile(
                    image: _images[index],
                    onTap: () => _openLightbox(_images[index]),
                  ),
                  childCount: _images.length,
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => ImageCard(
                  image: _images[index],
                  onTap: () => _openLightbox(_images[index]),
                  onCategoryTap: (value) => _addFacet('category', value),
                  onGameTap: _filterByGameDomain,
                ),
                childCount: _images.length,
              ),
            ),
          if (_loadingMore)
            const SliverToBoxAdapter(child: SkeletonCard()),
          if (_currentOffset >= _totalCount && _images.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'You\'re all caught up',
                    style: TextStyle(color: NexusColors.darkBrown, fontSize: 14),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
        ],
      ),
    );
  }
}
