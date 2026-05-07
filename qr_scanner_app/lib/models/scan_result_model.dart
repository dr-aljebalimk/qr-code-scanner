class ScanResultModel {
  final String id;
  final String url;
  final DateTime scannedAt;

  const ScanResultModel({
    required this.id,
    required this.url,
    required this.scannedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'scannedAt': scannedAt.toIso8601String(),
      };

  factory ScanResultModel.fromJson(Map<String, dynamic> json) =>
      ScanResultModel(
        id: json['id'] as String,
        url: json['url'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
      );

  String get displayUrl {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return '${uri.host}${uri.path.isNotEmpty && uri.path != '/' ? uri.path : ''}';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(scannedAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
