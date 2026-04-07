import 'package:flutter/material.dart';
import '../utils/task.dart';
import '../utils/recurrence_utils.dart';

/// Displays a dialog that allows the user to enter a task title and select a
/// recurrence pattern. The [onSave] callback is invoked when the user taps
/// the Save button with the entered title and chosen recurrence.
Future<void> showAddTaskDialog(
  BuildContext context,
  void Function(String title, RecurrencePattern recurrence) onSave,
) async {
  final controller = TextEditingController();
  RecurrencePattern selectedRecurrence = RecurrencePattern.none;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Enter a task',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Quick suggestions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Water Plant'),
                      onPressed: () {
                        controller.text = 'Water Plant';
                      },
                    ),
                    ActionChip(
                      label: const Text('Fertilize Plant'),
                      onPressed: () {
                        controller.text = 'Fertilize Plant';
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Recurrence:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButton<RecurrencePattern>(
                  isExpanded: true,
                  value: selectedRecurrence,
                  onChanged: (RecurrencePattern? value) {
                    if (value != null) {
                      setState(() {
                        selectedRecurrence = value;
                      });
                    }
                  },
                  items: RecurrencePattern.values
                      .map((pattern) {
                        return DropdownMenuItem(
                          value: pattern,
                          child: Text(getRecurrenceName(pattern)),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    onSave(text, selectedRecurrence);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showDeleteRecurringTaskDialog(
  BuildContext context,
  PlantTask task,
  VoidCallback onDeleteOne,
  VoidCallback onDeleteAll,
) async {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete Recurring Task'),
        content: const Text(
          'This is a recurring task. Do you want to delete just this instance or all instances?',
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () {
                  onDeleteOne();
                  Navigator.of(context).pop();
                },
                child: const Text('Delete One'),
              ),
              ElevatedButton(
                onPressed: () {
                  onDeleteAll();
                  Navigator.of(context).pop();
                },
                child: const Text('Delete All'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
