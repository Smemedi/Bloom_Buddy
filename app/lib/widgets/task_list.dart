import 'package:flutter/material.dart';
import '../utils/task.dart';
import '../utils/recurrence_utils.dart';

class TaskList extends StatelessWidget {
  final List<PlantTask> tasks;
  final ValueChanged<PlantTask> onToggleCompletion;
  final ValueChanged<PlantTask> onRemove;

  const TaskList({
    Key? key,
    required this.tasks,
    required this.onToggleCompletion,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks for this day'));
    }
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return ListTile(
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (_) => onToggleCompletion(task),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration:
                  task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: task.recurrence != RecurrencePattern.none
              ? Text(
                  getRecurrenceName(task.recurrence),
                  style: const TextStyle(fontSize: 12),
                )
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => onRemove(task),
          ),
        );
      },
    );
  }
}
