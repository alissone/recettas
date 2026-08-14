/// An exercise in the shared catalog. Rows with a null userId are the
/// hand-seeded global list; [imagePath] points at the "habits" storage
/// bucket and is also set by hand. [videoPath], by contrast, is a
/// relative path into the assets/exercises/ Flutter asset bundle, not a
/// storage object key - the demo videos ship with the app itself.
class Exercise {
  final String id;
  final String? userId;
  final String name;
  final String? namePt;
  final String? description;
  final String? muscleGroup;
  final String? imagePath;
  final String? videoPath;
  final int sortOrder;
  final DateTime? createdAt;

  const Exercise({
    required this.id,
    this.userId,
    required this.name,
    this.namePt,
    this.description,
    this.muscleGroup,
    this.imagePath,
    this.videoPath,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'] ?? '',
      namePt: json['name_pt'],
      description: json['description'],
      muscleGroup: json['muscle_group'],
      imagePath: json['image_path'],
      videoPath: json['video_path'],
      sortOrder: json['sort_order'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
