import '../task.dart';

String getRecurrenceName(RecurrencePattern pattern) {
  switch (pattern) {
    case RecurrencePattern.none:
      return 'One-time';
    case RecurrencePattern.daily:
      return 'Daily';
    case RecurrencePattern.weekly:
      return 'Weekly';
    case RecurrencePattern.monthly:
      return 'Monthly';
    case RecurrencePattern.yearly:
      return 'Yearly';
  }
}

int getRecurrenceDays(RecurrencePattern pattern) {
  switch (pattern) {
    case RecurrencePattern.daily:
      return 1;
    case RecurrencePattern.weekly:
      return 7;
    case RecurrencePattern.monthly:
      return 30;
    case RecurrencePattern.yearly:
      return 365;
    default:
      return 0;
  }
}
