import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/nexus_image.dart';

enum SortOption {
  newest('createdAt', 'DESC', 'Newest'),
  oldest('createdAt', 'ASC', 'Oldest'),
  mostViewed('views', 'DESC', 'Most Viewed'),
  topRated('rating', 'DESC', 'Top Rated'),
  random('random', '', 'Random');

  final String field;
  final String direction;
  final String label;
  const SortOption(this.field, this.direction, this.label);
}

class NexusApi {
  static const _apiUrl = 'https://api.nexusmods.com/v2/graphql';
  static const _gamesUrl =
      'https://data.nexusmods.com/file/nexus-data/games.json';

  // Each request also gets a timeout, so a stalled connection fails fast and
  // is retried rather than hanging the feed.
  static const _timeout = Duration(seconds: 20);
  // Transient failures (429 rate-limit, 5xx origin errors — the latter is what
  // this API actually returns under load) are retried with exponential backoff
  // before giving up. A 429's Retry-After header, when present, overrides the
  // backoff. Kept short so a genuinely down server still surfaces quickly.
  static const _maxRetries = 3;
  static const _baseBackoff = Duration(milliseconds: 500);

  /// Sends a request via [send], retrying on transient failures (HTTP 429 and
  /// 5xx) with exponential backoff. Honours a `Retry-After` header on a 429.
  /// Returns the final response; the caller still handles non-2xx as before.
  static Future<http.Response> _sendWithRetry(
      Future<http.Response> Function() send) async {
    var attempt = 0;
    while (true) {
      http.Response? res;
      try {
        res = await send().timeout(_timeout);
        if (!_isTransient(res.statusCode) || attempt >= _maxRetries) {
          return res;
        }
      } catch (e) {
        // Network error / timeout: also transient. Rethrow once retries run out.
        if (attempt >= _maxRetries) rethrow;
      }
      final wait = _retryAfter(res) ?? _baseBackoff * (1 << attempt);
      await Future<void>.delayed(wait);
      attempt++;
    }
  }

  static bool _isTransient(int status) =>
      status == 429 || (status >= 500 && status < 600);

  /// Parses a `Retry-After` header (delay in seconds; the HTTP-date form is
  /// uncommon here and ignored). Returns null when absent or unparseable.
  static Duration? _retryAfter(http.Response? res) {
    final raw = res?.headers['retry-after'];
    if (raw == null) return null;
    final secs = int.tryParse(raw.trim());
    return secs == null ? null : Duration(seconds: secs);
  }

  static const _query = '''
    query MediaSearch(
      \$facets: MediaFacet,
      \$filter: MediaSearchFilter,
      \$sort: [MediaSearchSort!],
      \$offset: Int,
      \$count: Int
    ) {
      media(
        facets: \$facets,
        filter: \$filter,
        sort: \$sort,
        offset: \$offset,
        count: \$count
      ) {
        totalCount
        facets { facet value count }
        nodes {
          ... on Image {
            id name title caption description
            url thumbnailUrl views rating
            createdAt siteUrl adult
            category { name }
            game { name domainName }
            owner { name avatar memberId }
          }
        }
      }
    }
  ''';

  static Future<List<NexusGame>> loadGames() async {
    final res = await _sendWithRetry(() => http.get(Uri.parse(_gamesUrl)));
    if (res.statusCode != 200) {
      throw Exception('Failed to load games: ${res.statusCode}');
    }
    final List<dynamic> data = json.decode(res.body);
    final games = data.map((g) => NexusGame.fromJson(g)).toList();
    games.sort((a, b) => b.downloads.compareTo(a.downloads));
    return games;
  }

  static Future<MediaSearchResult> search({
    String? searchText,
    int? gameId,
    SortOption sort = SortOption.newest,
    int offset = 0,
    int count = 20,
    Map<String, Set<String>> activeFacets = const {},
    int? randomSeed,
    bool includeAdult = true,
  }) async {
    final filter = <String, dynamic>{
      'type': [
        {'value': 'image', 'op': 'EQUALS'}
      ],
    };

    if (!includeAdult) {
      // The value must be a raw boolean — the API rejects "false" as a string.
      filter['adultContent'] = [
        {'value': false, 'op': 'EQUALS'}
      ];
    }

    if (gameId != null) {
      filter['gameId'] = [
        {'value': '$gameId', 'op': 'EQUALS'}
      ];
    }

    if (searchText != null && searchText.isNotEmpty) {
      filter['generalSearch'] = [
        {'value': searchText, 'op': 'EQUALS'}
      ];
    }

    List<Map<String, dynamic>> sortVar;
    if (sort == SortOption.random) {
      sortVar = [
        {
          'random': {'seed': randomSeed ?? Random().nextInt(100000)}
        }
      ];
    } else {
      sortVar = [
        {
          sort.field: {'direction': sort.direction}
        }
      ];
    }

    final facets = <String, dynamic>{
      'category': activeFacets['category']?.toList() ?? [],
    };

    final variables = {
      'facets': facets,
      'filter': filter,
      'sort': sortVar,
      'offset': offset,
      'count': count,
    };

    final res = await _sendWithRetry(() => http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Application-Name': 'Flutter_NM_Image_Browser',
          },
          body: json.encode({'query': _query, 'variables': variables}),
        ));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
    }

    final body = json.decode(res.body);

    if (body['errors'] != null) {
      final errors = (body['errors'] as List)
          .map((e) => e['message'].toString())
          .join('; ');
      throw Exception(errors);
    }

    final media = body['data']['media'];
    final nodes = (media['nodes'] as List)
        .map((n) => NexusImage.fromJson(n))
        .toList();
    final facetItems = (media['facets'] as List?)
            ?.map((f) => FacetItem.fromJson(f))
            .toList() ??
        [];

    return MediaSearchResult(
      totalCount: media['totalCount'] ?? 0,
      nodes: nodes,
      facets: facetItems,
    );
  }
}
