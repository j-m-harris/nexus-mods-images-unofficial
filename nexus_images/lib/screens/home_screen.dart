import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/nexus_image.dart';
import '../services/nexus_api.dart';
import '../theme.dart';
import '../widgets/image_card.dart';
import '../widgets/facets_bar.dart';
import '../widgets/lightbox.dart';
import '../widgets/skeleton_card.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

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

  bool get _hasActiveSearch =>
      (_searchText != null && _searchText!.isNotEmpty) || _gameId != null;

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
      );
      if (generation != _fetchGeneration || !mounted) return;
      setState(() {
        _images.addAll(result.nodes);
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

  void _openLightbox(NexusImage image) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LightboxView(image: image)),
    );
  }

  void _goHome() {
    if (_hasActiveSearch) {
      _searchText = null;
      _gameId = null;
      _sort = SortOption.newest;
      _activeFacets = {};
    }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _performSearch();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Feed refreshed',
            style: TextStyle(color: NexusColors.textPrimary),
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
    setState(() => _currentTab = 0);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: NexusColors.surface.withValues(alpha: 0.6),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: const SizedBox.expand(),
          ),
        ),
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
                  if (_hasActiveSearch)
                    Text(
                      _searchSummary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: NexusColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_currentTab == 0)
            PopupMenuButton<SortOption>(
              icon: Icon(PhosphorIcons.arrowsDownUp(),
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
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildFeed(),
          SearchScreen(
            games: _games,
            onSearch: _onSearchSubmitted,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) {
          if (i == 0) {
            _goHome();
          } else {
            setState(() => _currentTab = i);
          }
        },
        backgroundColor: NexusColors.surface,
        selectedItemColor: NexusColors.primary,
        unselectedItemColor: NexusColors.textMuted,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.house()),
            activeIcon: Icon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIcons.magnifyingGlass()),
            activeIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold)),
            label: 'Search',
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    if (_loading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: topInset),
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ImageCard(
                image: _images[index],
                onTap: () => _openLightbox(_images[index]),
                onCategoryTap: (value) => _toggleFacet('category', value),
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
        ],
      ),
    );
  }
}
