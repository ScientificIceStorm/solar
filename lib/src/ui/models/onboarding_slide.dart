class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.imageAsset,
    this.highlights = const <String>[],
  });

  final String title;
  final String description;
  final String imageAsset;
  final List<String> highlights;
}
