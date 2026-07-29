// lib/widgets/field_card.dart

import 'package:flutter/material.dart';
import '../theme.dart';

class FieldCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool isRequired;

  const FieldCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasValue
            ? AppTheme.success.withValues(alpha: 0.06)
            : (isRequired
                ? AppTheme.warning.withValues(alpha: 0.06)
                : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasValue
              ? AppTheme.success.withValues(alpha: 0.3)
              : (isRequired
                  ? AppTheme.warning.withValues(alpha: 0.3)
                  : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value : '—',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        hasValue ? AppTheme.textPrimary : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            hasValue ? Icons.check_circle : Icons.radio_button_unchecked,
            color: hasValue ? AppTheme.success : Colors.grey.shade300,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class ConfidenceBar extends StatelessWidget {
  final int confidence;

  const ConfidenceBar({super.key, required this.confidence});

  Color get _color {
    if (confidence >= 75) return AppTheme.success;
    if (confidence >= 50) return Colors.orange;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Confidence',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              '$confidence%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: confidence / 100,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}

class LeadTypeBadge extends StatelessWidget {
  final String leadType;

  const LeadTypeBadge({super.key, required this.leadType});

  @override
  Widget build(BuildContext context) {
    final isSales = leadType.toLowerCase().contains('sales');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSales
            ? AppTheme.primary.withValues(alpha: 0.12)
            : AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSales ? Icons.trending_up : Icons.support_agent,
            size: 13,
            color: isSales ? AppTheme.primary : AppTheme.accent,
          ),
          const SizedBox(width: 4),
          Text(
            leadType,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSales ? AppTheme.primary : AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'high':
        color = AppTheme.error;
        break;
      case 'medium':
        color = AppTheme.warning;
        break;
      default:
        color = AppTheme.accent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class SentimentBadge extends StatelessWidget {
  final String sentiment;

  const SentimentBadge({super.key, required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final normalized = sentiment.toLowerCase();
    final color = normalized.contains('positive')
        ? AppTheme.success
        : normalized.contains('negative') || normalized.contains('frustrated')
            ? AppTheme.error
            : normalized.contains('concerned')
                ? AppTheme.warning
                : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        sentiment,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
