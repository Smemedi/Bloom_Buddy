import 'package:flutter/material.dart';

typedef MonthChanged = void Function(int month);
typedef YearChanged = void Function(int year);
typedef TodayCallback = void Function();

class CalendarHeader extends StatelessWidget {
  final DateTime focusedDay;
  final MonthChanged onMonthChanged;
  final YearChanged onYearChanged;
  final TodayCallback onTodayPressed;

  const CalendarHeader({
    Key? key,
    required this.focusedDay,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onTodayPressed,
  }) : super(key: key);

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DropdownButton<int>(
            value: focusedDay.month,
            onChanged: (int? month) {
              if (month != null) {
                onMonthChanged(month);
              }
            },
            items: List.generate(12, (index) {
              final monthNum = index + 1;
              final monthName = _getMonthName(monthNum);
              return DropdownMenuItem(
                value: monthNum,
                child: Text(monthName),
              );
            }),
          ),
          const SizedBox(width: 16),
          DropdownButton<int>(
            value: focusedDay.year,
            onChanged: (int? year) {
              if (year != null) {
                onYearChanged(year);
              }
            },
            items: List.generate(
              201,
              (index) {
                final year = 2000 + index;
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onTodayPressed,
            child: const Text('Today'),
          ),
        ],
      ),
    );
  }
}
