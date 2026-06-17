class Recipe {
  final String id;
  final String name;
  final String? image;
  final String? prepTime;
  final String? totalTime;
  final List<RecipeSection> sections;
  final DateTime? createdAt;

  Recipe({
    required this.id,
    required this.name,
    this.image,
    this.prepTime,
    this.totalTime,
    required this.sections,
    this.createdAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    List<RecipeSection> parsedSections;

    if (rawSections is List) {
      parsedSections =
          rawSections.map((s) => RecipeSection.fromJson(s)).toList();
    } else {
      parsedSections = [];
    }

    return Recipe(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      image: json['image'],
      prepTime: json['prep_time'],
      totalTime: json['total_time'],
      sections: parsedSections,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'image': image,
      'prep_time': prepTime,
      'total_time': totalTime,
      'sections': sections.map((s) => s.toMap()).toList(),
    };
  }
}

class RecipeSection {
  final String title;
  final List<String> items;

  RecipeSection({required this.title, required this.items});

  factory RecipeSection.fromJson(Map<String, dynamic> json) {
    return RecipeSection(
      title: json['title'] ?? '',
      items:
          (json['items'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'items': items,
    };
  }
}
