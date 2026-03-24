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
            id name caption description
            url thumbnailUrl views rating
            createdAt siteUrl
            category { name }
            game { name domainName }
            owner { name avatar memberId }
          }
        }
      }
    }
  ''';

  static Future<List<NexusGame>> loadGames() async {
    final res = await http.get(Uri.parse(_gamesUrl));
    if (res.statusCode != 200) {
      throw Exception('Failed to load games: ${res.statusCode}');
    }
    final List<dynamic> data = json.decode(res.body);
    final games = data.map((g) => NexusGame.fromJson(g)).toList();
    games.sort((a, b) => a.name.compareTo(b.name));
    return games;
  }

  static Future<MediaSearchResult> search({
    String? searchText,
    int? gameId,
    SortOption sort = SortOption.newest,
    int offset = 0,
    int count = 20,
    Map<String, Set<String>> activeFacets = const {},
  }) async {
    final filter = <String, dynamic>{
      'type': [
        {'value': 'image', 'op': 'EQUALS'}
      ],
    };

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
          'random': {'seed': Random().nextInt(100000)}
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

    final res = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Application-Name': 'Flutter_NM_Image_Browser',
      },
      body: json.encode({'query': _query, 'variables': variables}),
    );

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
