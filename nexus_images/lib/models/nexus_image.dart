class NexusImage {
  final String id;
  final String name;
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

  NexusImage({
    required this.id,
    required this.name,
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
  });

  factory NexusImage.fromJson(Map<String, dynamic> json) {
    return NexusImage(
      id: json['id'].toString(),
      name: json['name'] ?? '',
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
    );
  }

  String get displayTitle => caption ?? name;
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

  String get formattedDownloads {
    final s = downloads.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
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
