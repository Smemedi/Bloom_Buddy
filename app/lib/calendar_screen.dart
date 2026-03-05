import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'task.dart';

// modular widgets and utilities
import 'widgets/calendar_header.dart';
import 'widgets/task_list.dart';
import 'widgets/dialogs.dart';
import 'utils/recurrence_utils.dart';
import 'utils/notification_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Map<String, List<PlantTask>> _tasks = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    NotificationService.initializeNotifications();
    _loadTasks();
  }

  List<PlantTask> _getTasksForDay(DateTime day) {
    final key = _formatDate(day);
    return _tasks[key] ?? [];
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('plant_tasks_v2');
    if (data != null) {
      try {
        // load tasks from JSON string
        final Map<String, dynamic> map = jsonDecode(data);
        map.forEach((dateStr, tasksList) {
          _tasks[dateStr] = (tasksList as List)
              .map((t) => PlantTask.fromJson(t as Map<String, dynamic>))
              .toList();
        });
      } catch (e) {
        print('Error loading tasks: $e');
      }
    }
    setState(() {});
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> stringMap = {};
    _tasks.forEach((key, value) {
      stringMap[key] = value.map((t) => t.toJson()).toList();
    });
    await prefs.setString('plant_tasks_v2', jsonEncode(stringMap));
  }

  void _addTask(String title, RecurrencePattern recurrence) {
    final dayKey = _formatDate(_selectedDay);
    final taskId = const Uuid().v4();
    final task = PlantTask(
      id: taskId,
      title: title,
      createdDate: DateTime.now(),
      recurrence: recurrence,
    );

    // add the initial task
    final list = _tasks[dayKey] ?? [];
    list.add(task);
    _tasks[dayKey] = list;

    // add recurring instances
    if (recurrence != RecurrencePattern.none) {
      _addRecurringInstances(_selectedDay, task, recurrence);
    }

    _saveTasks();
    NotificationService.scheduleNotification(task, _selectedDay);
    setState(() {});
  }

  void _addRecurringInstances(
    DateTime startDate, PlantTask originalTask, RecurrencePattern pattern) {
    final endDate = startDate.add(Duration(days: 365));
    DateTime currentDate = startDate.add(
      Duration(days: getRecurrenceDays(pattern)),
    );

    while (currentDate.isBefore(endDate)) {
      final dateKey = _formatDate(currentDate);
      final list = _tasks[dateKey] ?? [];
      // create a new task instance with the same title but different date
      final recurringTask = PlantTask(
        id: const Uuid().v4(),
        title: originalTask.title,
        createdDate: currentDate,
        recurrence: pattern,
      );
      list.add(recurringTask);
      _tasks[dateKey] = list;
      NotificationService.scheduleNotification(recurringTask, currentDate);

      currentDate =
          currentDate.add(Duration(days: getRecurrenceDays(pattern)));
    }
  }

  Future<void> _showTestNotification() async {
    try {
      await NotificationService.showTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test notification sent!')),
        );
      }
    } catch (e) {
      print('Error showing test notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _removeTask(PlantTask task) {
    if (task.recurrence != RecurrencePattern.none) {
      // Show confirmation dialog for recurring task
      showDeleteRecurringTaskDialog(
        context,
        task,
        () => _deleteSingleTask(task),
        () => _deleteAllRecurringTaskInstances(task),
      );
    } else {
      // Delete single task directly
      _deleteSingleTask(task);
    }
  }

  void _deleteSingleTask(PlantTask task) {
    final dayKey = _formatDate(_selectedDay);
    final list = _tasks[dayKey];
    if (list != null) {
      list.removeWhere((t) => t.id == task.id);
      if (list.isEmpty) {
        _tasks.remove(dayKey);
      } else {
        _tasks[dayKey] = list;
      }
      _saveTasks();

      // Cancel notification
      NotificationService.cancelNotification(task.id.hashCode);

      setState(() {});
    }
  }

  void _deleteAllRecurringTaskInstances(PlantTask task) {
    final taskTitle = task.title;
    final taskRecurrence = task.recurrence;

    // Collect all task IDs to cancel notifications
    final taskIdsToCancel = <int>[];
    _tasks.forEach((dateKey, tasks) {
      for (var t in tasks) {
        if (t.title == taskTitle && t.recurrence == taskRecurrence) {
          taskIdsToCancel.add(t.id.hashCode);
        }
      }
    });

    // Find and delete all tasks with the same title and recurrence pattern
    _tasks.forEach((dateKey, tasks) {
      tasks.removeWhere(
          (t) => t.title == taskTitle && t.recurrence == taskRecurrence);
    });

    // Remove empty date entries
    _tasks.removeWhere((dateKey, tasks) => tasks.isEmpty);

    // Cancel all notifications
    for (var taskId in taskIdsToCancel) {
      NotificationService.cancelNotification(taskId);
    }

    _saveTasks();
    setState(() {});
  }

  void _toggleTaskCompletion(PlantTask task) {
    task.isCompleted = !task.isCompleted;
    _saveTasks();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tasksForDay = _getTasksForDay(_selectedDay);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Test Notification',
            onPressed: _showTestNotification,
          ),
        ],
      ),
      body: Column(
        children: [
          CalendarHeader(
            focusedDay: _focusedDay,
            onMonthChanged: (month) {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, month, 1);
              });
            },
            onYearChanged: (year) {
              setState(() {
                _focusedDay = DateTime(year, _focusedDay.month, 1);
              });
            },
            onTodayPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          ),
          TableCalendar<PlantTask>(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              return _getTasksForDay(day);
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Selected Date: ${_formatDate(_selectedDay)}",
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TaskList(
              tasks: tasksForDay,
              onToggleCompletion: _toggleTaskCompletion,
              onRemove: _removeTask,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTaskDialog(context, _addTask),
        child: const Icon(Icons.add),
      ),
    );
  }
}
