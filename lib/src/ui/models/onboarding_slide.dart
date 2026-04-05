class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.description,
    this.highlights = const <String>[],
  });

  final String title;
  final String description;
  final List<String> highlights;
}
