class NexusImage {
  final String id;
  final String name;
  final String? title;
  final String? caption;
  final String? description;
  final String url;
  final String thumbnailUrl;
  final int views;
  final double rating;
  final String? createdAt;
  final String? siteUrl;
  final String? categoryName;
  final String? gameName;
  final String? gameDomain;
  final String? ownerName;
  final String? ownerAvatar;
  final int? ownerMemberId;
  final bool adult;

  NexusImage({
    required this.id,
    required this.name,
    this.title,
    this.caption,
    this.description,
    required this.url,
    required this.thumbnailUrl,
    required this.views,
    required this.rating,
    this.createdAt,
    this.siteUrl,
    this.categoryName,
    this.gameName,
    this.gameDomain,
    this.ownerName,
    this.ownerAvatar,
    this.ownerMemberId,
    this.adult = false,
  });

  factory NexusImage.fromJson(Map<String, dynamic> json) {
    return NexusImage(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      title: json['title'],
      caption: json['caption'],
      description: json['description'],
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      views: json['views'] ?? 0,
      rating: (json['rating'] ?? 0).toDouble(),
      createdAt: json['createdAt'],
      siteUrl: json['siteUrl'],
      categoryName: json['category']?['name'],
      gameName: json['game']?['name'],
      gameDomain: json['game']?['domainName'],
      ownerName: json['owner']?['name'],
      ownerAvatar: json['owner']?['avatar'],
      ownerMemberId: json['owner']?['memberId'],
      adult: json['adult'] == true,
    );
  }

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    if (caption != null && caption!.isNotEmpty) return caption!;
    return '';
  }

  String? get displayDescription => _stripDescription(inline: false);

  String? get displayDescriptionInline => _stripDescription(inline: true);

  String? _stripDescription({required bool inline}) {
    final raw = description;
    if (raw == null || raw.isEmpty) return raw;
    final breakReplacement = inline ? ' ' : '\n';
    final paragraphReplacement = inline ? ' ' : '\n\n';
    final stripped = raw
        .replaceAll(
            RegExp(r'<br\s*/?>', caseSensitive: false), breakReplacement)
        .replaceAll(
            RegExp(r'</p\s*>', caseSensitive: false), paragraphReplacement)
        .replaceAll(RegExp(r'<[^>]*>'), '');
    final decoded = stripped
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    final debbcoded = decoded
        .replaceAll(
            RegExp(r'\[img\b[^\]]*\][\s\S]*?\[/img\]', caseSensitive: false),
            '')
        .replaceAllMapped(
            RegExp(r'\[url\b[^\]]*\]([\s\S]*?)\[/url\]', caseSensitive: false),
            (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'\[/?[a-zA-Z][a-zA-Z0-9]*(=[^\]]*)?\]'), '');
    if (inline) {
      return debbcoded.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return debbcoded.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

class NexusGame {
  final int id;
  final String name;
  final String domainName;
  final int downloads;
  final int mods;

  NexusGame({
    required this.id,
    required this.name,
    required this.domainName,
    required this.downloads,
    required this.mods,
  });

  factory NexusGame.fromJson(Map<String, dynamic> json) {
    return NexusGame(
      id: json['id'],
      name: json['name'] ?? '',
      domainName: json['domain_name'] ?? '',
      downloads: json['downloads'] ?? 0,
      mods: json['mods'] ?? 0,
    );
  }

  static String _commaFormat(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String get formattedDownloads => _commaFormat(downloads);
  String get formattedMods => _commaFormat(mods);
}

class FacetItem {
  final String facet;
  final String value;
  final int count;

  FacetItem({
    required this.facet,
    required this.value,
    required this.count,
  });

  factory FacetItem.fromJson(Map<String, dynamic> json) {
    return FacetItem(
      facet: json['facet'] ?? '',
      value: json['value'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class MediaSearchResult {
  final int totalCount;
  final List<NexusImage> nodes;
  final List<FacetItem> facets;

  MediaSearchResult({
    required this.totalCount,
    required this.nodes,
    required this.facets,
  });
}
