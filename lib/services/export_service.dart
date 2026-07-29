// lib/services/export_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/lead.dart';

class ExportService {
  static Future<String?> exportToCsv(List<Lead> leads) async {
    try {
      final rows = <List<dynamic>>[];

      // Header
      rows.add([
        'Lead ID',
        'Date & Time',
        'Lead Type',
        'Name',
        'Phone',
        'Address',
        'Location/Area',
        'Product Interest',
        'Transcript',
        'Status',
        'Confidence %',
        'Intent',
        'Sentiment',
        'Priority',
        'Lead Score',
        'AI Summary',
        'Next Action',
        'Latitude',
        'Longitude',
        'Survey Status',
        'Survey Started At',
        'Survey Arrived At',
        'Survey Distance Meters',
        'Survey Note',
      ]);

      // Data rows
      for (final lead in leads) {
        rows.add([
          lead.leadId,
          lead.dateTime,
          lead.leadType,
          lead.name,
          lead.phone,
          lead.address,
          lead.location,
          lead.productInterest,
          lead.transcript,
          lead.status,
          lead.confidence,
          lead.intent,
          lead.sentiment,
          lead.priority,
          lead.leadScore,
          lead.aiSummary,
          lead.nextAction,
          lead.latitude,
          lead.longitude,
          lead.surveyStatus,
          lead.surveyStartedAt,
          lead.surveyArrivedAt,
          lead.surveyDistanceMeters,
          lead.surveyNote,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/bangla_crm_leads_$timestamp.csv');
      await file.writeAsString('\uFEFF$csv', encoding: utf8); // BOM for Excel

      // Share / download
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Bangla CRM Leads Export',
        ),
      );

      return file.path;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> exportSurveyReport(List<Lead> leads) async {
    try {
      final rows = <List<dynamic>>[];
      rows.add([
        'Lead ID',
        'Name',
        'Phone',
        'Address',
        'Location',
        'Survey Status',
        'Started At',
        'Arrived At',
        'Distance Meters',
        'Latitude',
        'Longitude',
        'Survey Note',
      ]);

      for (final lead in leads) {
        rows.add([
          lead.leadId,
          lead.name,
          lead.phone,
          lead.address,
          lead.location,
          lead.surveyStatus,
          lead.surveyStartedAt,
          lead.surveyArrivedAt,
          lead.surveyDistanceMeters,
          lead.latitude,
          lead.longitude,
          lead.surveyNote,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/bangla_crm_survey_report_$timestamp.csv');
      await file.writeAsString('\uFEFF$csv', encoding: utf8);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Bangla CRM Survey Report',
        ),
      );

      return file.path;
    } catch (e) {
      return null;
    }
  }
}
