import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum SeriesKind { bar, line }

class ChartPoint {
  final String x;
  final double y;

  const ChartPoint({required this.x, required this.y});
}

class HourlySeries {
  final String label;
  final SeriesKind kind;
  final Color color;
  final List<ChartPoint> points;

  const HourlySeries({
    required this.label,
    required this.kind,
    required this.color,
    required this.points,
  });
}

class DailyPoint {
  final String date;
  final double value;
  final double? trendValue;
  final bool highlighted;

  const DailyPoint({
    required this.date,
    required this.value,
    this.trendValue,
    this.highlighted = false,
  });
}

class StatusData {
  final String deviceIp;
  final String activationText;
  final double activationPercent;
  final String meterText;
  final double meterPercent;
  final List<String> readings;
  final DateTime updatedAt;

  const StatusData({
    required this.deviceIp,
    required this.activationText,
    required this.activationPercent,
    required this.meterText,
    required this.meterPercent,
    required this.readings,
    required this.updatedAt,
  });
}

class DashboardData {
  final List<String> labels;
  final List<HourlySeries> hourlySeries;
  final List<DailyPoint> dailyUsed;
  final StatusData status;
  final String sourceLabel;
  final bool live;

  DashboardData({
    required this.labels,
    required this.hourlySeries,
    required this.dailyUsed,
    required this.status,
    required this.sourceLabel,
    required this.live,
  });

  List<HourlySeries> get barSeries =>
      hourlySeries.where((series) => series.kind == SeriesKind.bar).toList();

  List<HourlySeries> get lineSeries =>
      hourlySeries.where((series) => series.kind == SeriesKind.line).toList();
}

class GeckoCommand {
  final String tpl;
  final String tph;

  const GeckoCommand(this.tpl, this.tph);
}

class DataService {
  static final Uri _defaultEndpoint = Uri.parse(
    'http://10.0.26.5/app/deskpad.cf',
  );

  final Uri endpoint;
  final http.Client _client;
  final List<String> availableDates;

  DataService({
    Uri? endpoint,
    http.Client? client,
    DateTime? anchorDate,
    int days = 5,
  }) : endpoint = endpoint ?? _defaultEndpoint,
       _client = client ?? http.Client(),
       availableDates = _buildDates(anchorDate ?? DateTime(2026, 5, 20), days);

  Future<DashboardData> fetchDashboard({String? date}) {
    return fetchCommand(const GeckoCommand('file', 'init'), date: date);
  }

  Future<DashboardData> refresh({String? date}) {
    return fetchCommand(const GeckoCommand('file', 'graph'), date: date);
  }

  Future<DashboardData> fetchSection(String tpl, {String? date}) {
    return fetchCommand(GeckoCommand(tpl, 'init'), date: date);
  }

  Future<DashboardData> pumpOn({String? date}) {
    return fetchCommand(const GeckoCommand('file', 'pump_on'), date: date);
  }

  Future<DashboardData> pumpOff({String? date}) {
    return fetchCommand(const GeckoCommand('file', 'pump_off'), date: date);
  }

  Future<DashboardData> fetchCommand(
    GeckoCommand command, {
    String? date,
  }) async {
    try {
      final payload = await _fetchGeckoPayload(command);
      return _parsePayload(payload, command, date: date, live: true);
    } catch (_) {
      return _buildFallback(command, date: date);
    }
  }

  Future<String> _fetchGeckoPayload(GeckoCommand command) async {
    final body = {'tpl': command.tpl, 'tph': command.tph};
    final getUri = endpoint.replace(
      queryParameters: {...endpoint.queryParameters, ...body},
    );

    // The browser uses POST through gecko.js, but this device also serves the
    // same payload through query parameters and is more reliable that way.
    final getResponse = await _client
        .get(getUri)
        .timeout(const Duration(seconds: 8));
    if (getResponse.statusCode >= 200 && getResponse.statusCode < 300) {
      return getResponse.body;
    }

    final postResponse = await _client
        .post(endpoint, body: body)
        .timeout(const Duration(seconds: 8));
    if (postResponse.statusCode >= 200 && postResponse.statusCode < 300) {
      return postResponse.body;
    }
    throw StateError('Gecko command failed: ${postResponse.statusCode}');
  }

  DashboardData _parsePayload(
    String payload,
    GeckoCommand command, {
    String? date,
    required bool live,
  }) {
    final labels = _parseHourLabels(payload);
    final hourlySeries = _parseHourlySeries(payload);
    final dailyUsed = _parseDailyPoints(payload);
    final status = _parseStatus(payload);

    if (hourlySeries.isEmpty || dailyUsed.isEmpty) {
      return _buildFallback(command, date: date);
    }

    return DashboardData(
      labels: labels.isEmpty ? _defaultHourLabels() : labels,
      hourlySeries: hourlySeries,
      dailyUsed: dailyUsed,
      status: status,
      sourceLabel: 'Live Gecko device (${command.tpl}/${command.tph})',
      live: live,
    );
  }

  List<String> _parseHourLabels(String payload) {
    final match = RegExp(
      r'labels:\s*\[([\s\S]*?)\]\s*,\s*datasets:',
      multiLine: true,
    ).firstMatch(payload);
    if (match == null) return const [];

    return RegExp(r'"([^"]+)"')
        .allMatches(match.group(1) ?? '')
        .map((match) => match.group(1) ?? '')
        .where((label) => label.contains(':'))
        .toList();
  }

  List<HourlySeries> _parseHourlySeries(String payload) {
    final chartStart = payload.indexOf('id":"hourChart"');
    final chartEnd = payload.indexOf('used = [');
    if (chartStart == -1 || chartEnd == -1 || chartEnd <= chartStart) {
      return const [];
    }

    final chartPayload = payload.substring(chartStart, chartEnd);
    final matches = RegExp(
      r"\{\s*type:\s*'(line|bar)'[\s\S]*?label:\s*([^,\n]+),[\s\S]*?data:\s*(\[[\s\S]*?\])[\s\S]*?(?:borderColor:\s*([^,\n}]+)|backgroundColor:\s*\[?\s*([^,\n\]]+))",
      multiLine: true,
    ).allMatches(chartPayload);

    return matches
        .map((match) {
          final kind = match.group(1) == 'line'
              ? SeriesKind.line
              : SeriesKind.bar;
          final rawLabel = match.group(2) ?? '';
          final colorToken = match.group(4) ?? match.group(5) ?? '';
          return HourlySeries(
            label: _cleanJsLabel(rawLabel),
            kind: kind,
            color: _colorForSeries(rawLabel, colorToken),
            points: _parseChartPoints(match.group(3) ?? ''),
          );
        })
        .where((series) => series.points.isNotEmpty)
        .toList();
  }

  List<ChartPoint> _parseChartPoints(String block) {
    return RegExp(
      r'x:\s*"([^"]+)"\s*,\s*y:\s*([0-9.]+)',
      multiLine: true,
    ).allMatches(block).map((match) {
      return ChartPoint(
        x: match.group(1) ?? '',
        y: double.tryParse(match.group(2) ?? '') ?? 0,
      );
    }).toList();
  }

  List<DailyPoint> _parseDailyPoints(String payload) {
    final used = _parseNamedPointArray(payload, 'used');
    final used2 = _parseNamedPointArray(payload, 'used2');
    final colors = _parseDailyColors(payload);
    final result = <DailyPoint>[];

    for (var i = 0; i < used.length; i++) {
      final primary = used[i];
      final trend = i < used2.length ? used2[i].y : null;
      final highlighted =
          i < colors.length && colors[i].toUpperCase() == '#FAA0A0';
      result.add(
        DailyPoint(
          date: primary.x,
          value: primary.y,
          trendValue: trend,
          highlighted: highlighted,
        ),
      );
    }
    return result;
  }

  List<ChartPoint> _parseNamedPointArray(String payload, String name) {
    final match = RegExp(
      '$name\\s*=\\s*\\[([\\s\\S]*?)\\];',
      multiLine: true,
    ).firstMatch(payload);
    if (match == null) return const [];
    return RegExp(
      r'x:\s*"([^"]+)"\s*,\s*y:\s*([0-9.]+)\+0',
      multiLine: true,
    ).allMatches(match.group(1) ?? '').map((match) {
      return ChartPoint(
        x: match.group(1) ?? '',
        y: double.tryParse(match.group(2) ?? '') ?? 0,
      );
    }).toList();
  }

  List<String> _parseDailyColors(String payload) {
    final match = RegExp(
      r'backgroundColor:\s*\[([\s\S]*?)\]\s*,\s*order:\s*1',
      multiLine: true,
    ).firstMatch(payload);
    if (match == null) return const [];
    return RegExp(r'"(#[A-Fa-f0-9]{6})"')
        .allMatches(match.group(1) ?? '')
        .map((match) => match.group(1) ?? '')
        .toList();
  }

  StatusData _parseStatus(String payload) {
    final ip = RegExp(r'Your IP:\s*([0-9.]+)').firstMatch(payload)?.group(1);
    final statusTexts = RegExp(
      r'"text":"([^"]*%[^"]*)"',
      multiLine: true,
    ).allMatches(payload).map((match) => match.group(1) ?? '').toList();
    final readings = RegExp(
      r'"text":"((?:Voltage|Pump)[^"]+)"',
      multiLine: true,
    ).allMatches(payload).map((match) => match.group(1) ?? '').toList();

    final activationText = statusTexts.isNotEmpty ? statusTexts.first : '0%';
    final meterText = statusTexts.length > 1 ? statusTexts[1] : activationText;

    return StatusData(
      deviceIp: ip ?? '10.0.26.203',
      activationText: activationText,
      activationPercent: _extractPercent(activationText),
      meterText: meterText,
      meterPercent: _extractPercent(meterText),
      readings: readings,
      updatedAt: DateTime.now(),
    );
  }

  String _cleanJsLabel(String raw) {
    final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final date = RegExp(r"'(\d{4}-\d{2}-\d{2})'").firstMatch(compact)?.group(1);
    if (compact.contains("'S: '")) return 'S: ${date ?? 'Solar'}';
    if (compact.contains("'O: '")) return 'O: ${date ?? 'Office'}';
    if (compact.contains("'T: '")) return 'T: ${date ?? 'Total'}';
    return date ?? compact.replaceAll("'", '').replaceAll('.toDate()', '');
  }

  Color _colorForSeries(String label, String token) {
    if (label.contains("'S: '")) return const Color(0xFF53CBF3);
    if (label.contains("'O: '")) return const Color(0xFF79AE6F);
    if (label.contains("'T: '")) return const Color(0xFF346739);
    if (token.contains('ff8503')) return const Color(0xFFFF8503);
    if (token.contains('0047AB')) return const Color(0xFF0047AB);
    if (token.contains('0096FF')) return const Color(0xFF0096FF);
    if (token.contains('89CFF0')) return const Color(0xFF89CFF0);
    return const Color(0xFF1D4ED8);
  }

  double _extractPercent(String text) {
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)%').firstMatch(text);
    final value = double.tryParse(match?.group(1) ?? '') ?? 0;
    return (value / 100).clamp(0, 1);
  }

  DashboardData _buildFallback(GeckoCommand command, {String? date}) {
    final selectedDate = date ?? availableDates.first;
    final labels = _defaultHourLabels();
    final seed = _hash('${command.tpl}|${command.tph}|$selectedDate');
    final solar = _hourlyFallback(
      labels,
      seed,
      'S: $selectedDate',
      const Color(0xFF53CBF3),
      0.18,
    );
    final office = _hourlyFallback(
      labels,
      seed + 8,
      'O: $selectedDate',
      const Color(0xFF79AE6F),
      0.08,
    );
    final total = HourlySeries(
      label: 'T: $selectedDate',
      kind: SeriesKind.line,
      color: const Color(0xFF346739),
      points: List.generate(labels.length, (i) {
        final y = solar.points[i].y + office.points[i].y;
        return ChartPoint(x: labels[i], y: _round(y));
      }),
    );
    final bar = HourlySeries(
      label: selectedDate,
      kind: SeriesKind.bar,
      color: command.tpl == 'office'
          ? const Color(0xFF0047AB)
          : const Color(0xFFFF8503),
      points: List.generate(labels.length, (i) {
        final y = total.points[i].y + ((seed + i) % 4) * 0.04;
        return ChartPoint(x: labels[i], y: _round(y));
      }),
    );

    return DashboardData(
      labels: labels,
      hourlySeries: [solar, office, total, bar],
      dailyUsed: _fallbackDaily(selectedDate, seed),
      status: StatusData(
        deviceIp: '10.0.26.203',
        activationText: '65% [$selectedDate 10:10]',
        activationPercent: 0.65,
        meterText: '100% (sample) [$selectedDate 10:10]',
        meterPercent: 1,
        readings: const [
          'Voltage: 28.14 Amps: 10.49',
          'Voltage: 44.01 Amps: 0.90',
          'Pump is on. 0.71A',
        ],
        updatedAt: DateTime.now(),
      ),
      sourceLabel: 'Offline sample (${command.tpl}/${command.tph})',
      live: false,
    );
  }

  HourlySeries _hourlyFallback(
    List<String> labels,
    int seed,
    String label,
    Color color,
    double base,
  ) {
    return HourlySeries(
      label: label,
      kind: SeriesKind.line,
      color: color,
      points: List.generate(labels.length, (hour) {
        final daylight = max(0.0, sin((hour - 6) / 12 * pi));
        final night = hour < 6 || hour > 18 ? 0.55 : 0.02;
        final value = base + daylight * ((seed % 7) / 10 + 0.55) + night;
        return ChartPoint(x: labels[hour], y: _round(value));
      }),
    );
  }

  List<DailyPoint> _fallbackDaily(String date, int seed) {
    final start = DateTime.parse(date);
    return List.generate(31, (i) {
      final day = start.subtract(Duration(days: i));
      final value = 12 + ((seed + i * 7) % 15) + (i % 5) * 0.35;
      return DailyPoint(
        date: _formatDate(day),
        value: _round(value),
        trendValue: _round(value * (0.85 + (i % 4) * 0.05)),
        highlighted: i % 7 == 3,
      );
    });
  }

  static List<String> _defaultHourLabels() {
    return List.generate(24, (i) => '$i:00');
  }

  static List<String> _buildDates(DateTime anchor, int count) {
    return List.generate(
      count,
      (i) => _formatDate(anchor.subtract(Duration(days: i))),
    );
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static int _hash(String input) {
    var value = 0;
    for (final code in input.codeUnits) {
      value = (value * 31 + code) & 0x7fffffff;
    }
    return value;
  }

  double _round(double value) => double.parse(value.toStringAsFixed(2));
}
