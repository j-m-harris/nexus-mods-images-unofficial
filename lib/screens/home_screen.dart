import 'dart:math';
import 'package:flutter/material.dart';
import '../models/feed_layout.dart';
import '../models/nexus_image.dart';
import '../services/adult_reveal_session.dart';
import '../services/nexus_api.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/image_card.dart';
import '../widgets/image_grid_tile.dart';
import '../widgets/planetarium_view.dart';
import '../widgets/facets_bar.dart';
import '../widgets/lightbox.dart';
import '../widgets/skeleton_card.dart';
import 'favourites_screen.dart';
import 'search_screen.dart';

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

  /// What [SettingsService.includeAdultInFeed] was when the feed last
  /// fetched, so [_onSettingsChanged] can tell whether a mode change actually
  /// affects the query.
  bool _includedAdultInFeed = SettingsService.instance.includeAdultInFeed;

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
    SettingsService.instance.addListener(_onSettingsChanged);
    // Rebuild when an adult image is revealed elsewhere (the lightbox), so
    // the listing behind it unveils the matching card/tile.
    AdultRevealSession.instance.addListener(_onRevealsChanged);
    _loadGames();
    _performSearch();
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    AdultRevealSession.instance.removeListener(_onRevealsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onRevealsChanged() {
    if (mounted) setState(() {});
  }

  /// The adult-content setting only changes what the API is asked for when it
  /// crosses the Hide boundary — Blur and Show fetch identical content. So a
  /// Hide flip refetches from the top, while Blur <-> Show just rebuilds (the
  /// veils and the sphere's texture key react to the mode at build time),
  /// keeping the scroll position and avoiding a needless request.
  void _onSettingsChanged() {
    if (!mounted) return;
    final includeAdult = SettingsService.instance.includeAdultInFeed;
    if (includeAdult == _includedAdultInFeed) {
      setState(() {});
      return;
    }
    _includedAdultInFeed = includeAdult;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _performSearch();
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
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 600) {
      _loadNextPage();
    }
  }

  /// Re-evaluates the load-more condition after the feed rebuilds. Switching
  /// layouts changes the scroll extent (the grid is denser than the list), so
  /// the current position may land inside the trigger zone — or stop filling
  /// the viewport — without any scroll gesture to fire [_onScroll]. We wait a
  /// frame so the new layout is laid out before reading the scroll position.
  void _maybeLoadMoreAfterLayoutChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
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
        includeAdult: SettingsService.instance.includeAdultInFeed,
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
        includeAdult: SettingsService.instance.includeAdultInFeed,
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
    final index = _images.indexWhere((img) => img.id == image.id);
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        // _images is passed live: _loadNextPage appends to the same list
        // instance, so the pager can keep swiping into newly fetched pages.
        pageBuilder: (_, __, ___) => LightboxPager(
          images: _images,
          initialIndex: index < 0 ? 0 : index,
          fromFavourites: false,
          onRequestMore: _loadNextPage,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// A minimal settings surface (the natural home for future options). The
  /// adult-content switch takes effect immediately: [SettingsService] notifies
  /// and [_onSettingsChanged] refetches the feed with the new filter.
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NexusColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: ListenableBuilder(
          listenable: SettingsService.instance,
          builder: (ctx, _) => Column(
            mainAxisSize: MainAxisSize.min,
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    color: NexusColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ADULT CONTENT',
                    style: TextStyle(
                      color: NexusColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              RadioGroup<AdultContentMode>(
                groupValue: SettingsService.instance.adultMode,
                onChanged: (mode) {
                  if (mode != null) {
                    SettingsService.instance.setAdultMode(mode);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (mode, label, detail) in const [
                      (
                        AdultContentMode.hide,
                        'Hide',
                        'Left out of the feed entirely.',
                      ),
                      (
                        AdultContentMode.blur,
                        'Blur',
                        'Shown, but blurred until tapped.',
                      ),
                      (
                        AdultContentMode.show,
                        'Show',
                        'Shown normally.',
                      ),
                    ])
                      RadioListTile<AdultContentMode>(
                        value: mode,
                        dense: true,
                        activeColor: NexusColors.primary,
                        title: Text(
                          label,
                          style: const TextStyle(
                            color: NexusColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          detail,
                          style: const TextStyle(
                            color: NexusColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
                  // Search term and sort only describe the feed, so keep the
                  // subheader off the search and favourites tabs.
                  if (_currentTab == 0 &&
                      (_hasActiveSearch || _hasNonDefaultSort))
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
          IconButton(
            icon: Icon(Icons.tune, color: NexusColors.textPrimary),
            tooltip: 'Settings',
            onPressed: _showSettingsSheet,
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
              // Only the visible tab contributes Heroes; otherwise the feed and
              // favourites grids would register duplicate `image-<id>` tags.
              child: HeroMode(
                enabled: _currentTab == 0,
                child: _buildFeed(),
              ),
            ),
          ),
          Offstage(
            offstage: _currentTab != 1,
            child: TickerMode(
              enabled: _currentTab == 1,
              // The tabs all stay mounted, so the offstage search field keeps
              // its slot in the route's focus scope. Without this, popping the
              // lightbox back onto the feed restores focus to that hidden field
              // and the keyboard springs up unbidden. Excluding focus while the
              // search tab is inactive releases the field and blocks that
              // restoration.
              child: ExcludeFocus(
                excluding: _currentTab != 1,
                child: SearchScreen(
                  games: _games,
                  onSearch: _onSearchSubmitted,
                  onCancel: () => setState(() => _currentTab = 0),
                ),
              ),
            ),
          ),
          Offstage(
            offstage: _currentTab != 2,
            child: TickerMode(
              enabled: _currentTab == 2,
              child: HeroMode(
                enabled: _currentTab == 2,
                child: FavouritesScreen(
                  layout: _layout,
                  active: _currentTab == 2,
                ),
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
    _maybeLoadMoreAfterLayoutChange();
  }

  /// Long-pressing the layout button opens a sheet listing all three views
  /// with a short description, as an alternative to tap-to-cycle.
  void _showLayoutMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NexusColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(NexusRadii.large)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'VIEW',
                    style: TextStyle(
                      color: NexusColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              _layoutMenuTile(sheetContext, FeedLayout.list,
                  Icons.view_agenda_outlined, 'List',
                  'Full-width cards with author, stats and details'),
              _layoutMenuTile(sheetContext, FeedLayout.grid, Icons.grid_view,
                  'Grid', 'Compact three-column thumbnail grid'),
              _layoutMenuTile(sheetContext, FeedLayout.sphere, Icons.public,
                  'Sphere', '3D planetarium — drag to look around the images'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _layoutMenuTile(
    BuildContext sheetContext,
    FeedLayout layout,
    IconData icon,
    String title,
    String description,
  ) {
    final selected = _layout == layout;
    final color = selected ? NexusColors.primary : NexusColors.textPrimary;
    return InkWell(
      onTap: () {
        Navigator.of(sheetContext).pop();
        if (_layout != layout) {
          setState(() => _layout = layout);
          _maybeLoadMoreAfterLayoutChange();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: NexusColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: NexusColors.primary, size: 20),
          ],
        ),
      ),
    );
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
            icon: _currentTab == 2
                ? Icons.favorite
                : Icons.favorite_border,
            active: _currentTab == 2,
            onTap: () => setState(() => _currentTab = 2),
          ),
          _navButton(
            icon: _layoutIcon,
            active: _layout != FeedLayout.list,
            onTap: _cycleLayout,
            onLongPress: _showLayoutMenu,
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
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
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

    if (_images.isEmpty && !_loading) {
      return const Center(
        child: Text(
          'No images found.',
          style: TextStyle(color: NexusColors.textMuted, fontSize: 16),
        ),
      );
    }

    if (_layout == FeedLayout.sphere) {
      // Checked before _loading so the sphere stays mounted through a refresh:
      // unmounting it would discard the camera orientation and live tiles and
      // flash list-style skeletons. PlanetariumView absorbs the feed swap in
      // place (didUpdateWidget clears every cell when the feed is replaced),
      // so an emptied-then-refilled list just recycles the tiles.
      return Padding(
        padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
        child: PlanetariumView(
          // Adult tiles bake the veil into their textures at load time, so a
          // mode change must rebuild them — remounting on mode change is the
          // simple way to force that (a refetch alone may keep every tile).
          key: ValueKey(SettingsService.instance.adultMode),
          images: _images,
          onImageTap: _openLightbox,
          onRequestMore: _loadNextPage,
          canLoadMore: _currentOffset < _totalCount,
          active: _currentTab == 0,
        ),
      );
    }

    if (_loading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
        itemCount: 5,
        itemBuilder: (_, __) => const SkeletonCard(),
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
