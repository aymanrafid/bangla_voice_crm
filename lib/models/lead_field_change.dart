class LeadFieldChange {
  final String fieldKey;
  final String label;
  final String oldValue;
  final String newValue;

  const LeadFieldChange({
    required this.fieldKey,
    required this.label,
    required this.oldValue,
    required this.newValue,
  });

  bool get hasMeaningfulChange => oldValue.trim() != newValue.trim();
}
