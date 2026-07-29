/// An exercise in the shared catalog. Rows with a null userId are the
/// hand-seeded global list; [imagePath] points at the "habits" storage
/// bucket and is also set by hand.
class Exercise {
  final String id;
  final String? userId;
  final String name;
  final String? description;
  final String? muscleGroup;
  final String? imagePath;
  final int sortOrder;
  final DateTime? createdAt;

  const Exercise({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.muscleGroup,
    this.imagePath,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'] ?? '',
      description: json['description'],
      muscleGroup: json['muscle_group'],
      imagePath: json['image_path'],
      sortOrder: json['sort_order'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
