enum AiCommandIntent {
  createRepair,
  createSale,
  stockEntry,
  viewFinanceToday,
  viewFinanceWeek,
  viewFinanceMonth,
  findCustomer,
  viewDebt,
  viewPendingRepairs,
  attendanceIn,
  attendanceOut,
  stockCheck,
  unknown,
}

class AiCommandResult {
  final AiCommandIntent intent;
  final String rawText;

  /// Text remaining after stripping the intent keyword — used to pre-fill AI sheets.
  final String? payload;

  const AiCommandResult({
    required this.intent,
    required this.rawText,
    this.payload,
  });

  bool get isCreate =>
      intent == AiCommandIntent.createRepair ||
      intent == AiCommandIntent.createSale ||
      intent == AiCommandIntent.stockEntry;
}
