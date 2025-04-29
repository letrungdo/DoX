class GeneratedImage {
  final String? downloadTokens;
  final Metadata? metadata;

  const GeneratedImage({
    this.downloadTokens,
    this.metadata,
  });

  factory GeneratedImage.fromJson(Map<String, dynamic> json) {
    return GeneratedImage(
      downloadTokens: json['downloadTokens'],
      metadata: Metadata.fromJson(json['metadata']),
    );
  }
}

class Metadata {
  final String? creator;
  final String? visibility;

  const Metadata({this.creator, this.visibility});

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(creator: json['creator'], visibility: json['visibility']);
  }

  Map<String, dynamic> toJson() {
    return {'creator': creator, 'visibility': visibility};
  }
}
