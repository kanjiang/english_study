class Word {
  const Word({
    required this.id,
    required this.en,
    required this.zh,
    required this.category,
    required this.imageAsset,
    required this.audioAsset,
  });

  final String id;
  final String en;
  final String zh;
  final String category;
  final String imageAsset;
  final String audioAsset;
}
