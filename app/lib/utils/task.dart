
enum RecurrencePattern { none, daily, weekly, monthly, yearly }

class PlantTask {
  final String id;
  final String title;
  final DateTime createdDate;
  final RecurrencePattern recurrence;
  bool isCompleted;

  PlantTask({
    required this.id,
    required this.title,
    required this.createdDate,
    this.recurrence = RecurrencePattern.none,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdDate': createdDate.toIso8601String(),
      'recurrence': recurrence.name,
      'isCompleted': isCompleted,
    };
  }

  factory PlantTask.fromJson(Map<String, dynamic> json) {
    final recurrenceStr = (json['recurrence'] as String?) ?? 'none';
    return PlantTask(
      id: json['id'] as String,
      title: json['title'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      recurrence: RecurrencePattern.values
          .firstWhere((e) => e.name == recurrenceStr, orElse: () => RecurrencePattern.none),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}
