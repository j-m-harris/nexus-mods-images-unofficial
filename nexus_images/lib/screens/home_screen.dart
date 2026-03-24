import 'package:flutter/material.dart';
import '../models/nexus_image.dart';
import '../services/nexus_api.dart';
import '../widgets/image_card.dart';
import '../widgets/facets_bar.dart';
import '../widgets/lightbox.dart';
import '../widgets/search_controls.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  // Current search params
  String? _searchText;
  int? _gameId;
  SortOption _sort = SortOption.newest;
  int _perPage = 20;

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
    if (currentScroll >= maxScroll - 400) {
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

  void _onSearch({
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
    _scrollController.jumpTo(0);
    _performSearch();
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
    _scrollController.jumpTo(0);
    _performSearch();
  }

  void _openLightbox(NexusImage image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LightboxView(image: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nexus Mods Image Browser',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search controls
          SearchControls(
            games: _games,
            onSearch: _onSearch,
          ),

          // Facets bar
          if (_facets.isNotEmpty)
            FacetsBar(
              facets: _facets,
              activeFacets: _activeFacets,
              onToggle: _toggleFacet,
            ),

          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _images.isEmpty
                      ? ''
                      : 'Loaded ${_images.length} of ${_totalCount}',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12),
                ),
                Text(
                  _totalCount > 0
                      ? '${_totalCount} total images'
                      : '',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD35400)),
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
                style: const TextStyle(color: Color(0xFFE74C3C)),
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
          style: TextStyle(color: Color(0xFF888888), fontSize: 16),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 600;
    final crossAxisCount = isWide ? 3 : 2;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => ImageCard(
                image: _images[index],
                onTap: () => _openLightbox(_images[index]),
              ),
              childCount: _images.length,
            ),
          ),
        ),
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFD35400),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        if (_currentOffset >= _totalCount && _images.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'All images loaded.',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
