import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'data_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DataService _service = DataService();
  DashboardData? _data;
  bool _loading = false;
  String _selectedSection = 'Aircon';
  late final List<String> _availableDates;
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    _availableDates = _service.availableDates;
    _selectedDate = _availableDates.isNotEmpty ? _availableDates.first : '';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final nextData = await _service.fetchSection(
      _sectionToTpl(_selectedSection),
      date: _selectedDate.isEmpty ? null : _selectedDate,
    );
    if (!mounted) return;
    setState(() {
      _data = nextData;
      _loading = false;
    });
  }

  Future<void> _triggerGraph() async {
    setState(() => _loading = true);
    final next = await _service.triggerGraph(
      _sectionToTpl(_selectedSection),
      _selectedDate,
    );
    if (!mounted) return;
    setState(() {
      _data = next;
      _loading = false;
    });
  }

  Future<void> _onSectionSelected(String label) async {
    setState(() => _loading = true);
    final next = await _service.fetchSection(
      _sectionToTpl(label),
      date: _selectedDate,
    );
    if (!mounted) return;
    setState(() {
      _data = next;
      _selectedSection = label;
      _loading = false;
    });
  }

  Future<void> _onDateSelected(String date) async {
    setState(() => _loading = true);
    final next = await _service.fetchSection(
      _sectionToTpl(_selectedSection),
      date: date,
    );
    if (!mounted) return;
    setState(() {
      _data = next;
      _selectedDate = date;
      _loading = false;
    });
  }

  String _sectionToTpl(String label) {
    switch (label) {
      case 'Aircon In':
        return 'in';
      case 'Aircon Net':
        return 'savings';
      case 'Office':
        return 'office';
      case 'Aircon':
      default:
        return 'meters';
    }
  }

  Future<void> _confirmPump(bool on) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(on ? 'Confirm Turn Pump On' : 'Confirm Turn Pump Off'),
        content: Text(
          on
              ? 'This will send a pump on command to the device.'
              : 'This will send a pump off command to the device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    DashboardData next;
    try {
      next = on
          ? await _service.pumpOn(date: _selectedDate)
          : await _service.pumpOff(date: _selectedDate);
      if (!mounted) return;
      setState(() {
        _data = next;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(on ? 'Pump turned on' : 'Pump turned off')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Action failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : data == null
            ? const Center(child: Text('No data'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headerCard(data),
                    const SizedBox(height: 12),
                    _hourlyCard(data),
                    const SizedBox(height: 16),
                    _dailyCard(data),
                    const SizedBox(height: 16),
                    _statusCard(data),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _headerCard(DashboardData data) {
    final totals = data.dailyUsed.map((e) => e['y'] as double).toList();
    final total = totals.isEmpty
        ? 0.0
        : totals.reduce((value, element) => value + element);
    final average = totals.isEmpty ? 0.0 : total / totals.length;
    final statsText =
        'Average (last ${totals.length} days): ${average.toStringAsFixed(2)} kWh   '
        'Total: ${total.toStringAsFixed(2)} kWh';
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Data source: embedded sample',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(onPressed: _load, child: const Text('Refresh')),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Aircon', 'Aircon In', 'Aircon Net', 'Office'].map(
                    (label) {
                      return ChoiceChip(
                        label: Text(label),
                        selected: _selectedSection == label,
                        onSelected: (_) => _onSectionSelected(label),
                      );
                    },
                  ).toList(),
                ),
                if (_availableDates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableDates.map((date) {
                      return ChoiceChip(
                        label: Text(date),
                        selected: _selectedDate == date,
                        onSelected: (_) => _onDateSelected(date),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                if (isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statsText,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _triggerGraph,
                          child: const Text('Refresh graph'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          statsText,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _triggerGraph,
                        child: const Text('Refresh graph'),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hourlyCard(DashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final labels = data.labels;
        final maxY = _chartMax([...data.hourlyBar, ...data.hourlyBar2]);
        return _panel(
          title: 'Hourly Usage',
          subtitle: 'Mixed bars and trend lines',
          child: SizedBox(
            height: isCompact ? 240 : 320,
            child: Stack(
              children: [
                BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(show: true, drawVerticalLine: true),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(24, (i) {
                      final y = i < data.hourlyBar.length
                          ? data.hourlyBar[i]
                          : 0.0;
                      final y2 = i < data.hourlyBar2.length
                          ? data.hourlyBar2[i]
                          : 0.0;
                      return BarChartGroupData(
                        x: i,
                        barsSpace: isCompact ? 3 : 4,
                        barRods: [
                          BarChartRodData(
                            toY: y,
                            color: const Color(0xFF1997FF),
                            width: isCompact ? 6 : 8,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          BarChartRodData(
                            toY: y2,
                            color: const Color(0xFFFF8A00),
                            width: isCompact ? 6 : 8,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      );
                    }),
                    titlesData: _hourTitles(
                      labels,
                      step: isCompact ? 3 : 1,
                      compact: isCompact,
                    ),
                  ),
                ),
                LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          24,
                          (i) => FlSpot(
                            i.toDouble(),
                            i < data.hourlyBar.length ? data.hourlyBar[i] : 0.0,
                          ),
                        ),
                        isCurved: true,
                        color: const Color(0xFF1A39FF),
                        barWidth: isCompact ? 2.5 : 3,
                        dotData: FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: List.generate(
                          24,
                          (i) => FlSpot(
                            i.toDouble(),
                            i < data.hourlyBar2.length
                                ? data.hourlyBar2[i]
                                : 0.0,
                          ),
                        ),
                        isCurved: true,
                        color: const Color(0xFF7BC67E),
                        barWidth: isCompact ? 2 : 2.5,
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: _chartLegend(compact: isCompact),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dailyCard(DashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final barValues = data.dailyUsed
            .map((e) => (e['y'] as double) * 0.9)
            .toList();
        final maxY = _chartMax(barValues, min: 1.0, padding: 2.0);
        return _panel(
          title: 'Daily Usage',
          subtitle: 'Recent days and live reading trend',
          child: SizedBox(
            height: isCompact ? 220 : 280,
            child: Stack(
              children: [
                BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(data.dailyUsed.length, (i) {
                      final value = barValues[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: value,
                            width: isCompact ? 8 : 10,
                            color: i % 4 == 0
                                ? const Color(0xFFFF8D8D)
                                : const Color(0xFF9EC5E6),
                          ),
                        ],
                      );
                    }),
                    titlesData: _dayTitles(
                      data.dailyUsed,
                      step: isCompact ? 2 : 1,
                      compact: isCompact,
                    ),
                  ),
                ),
                LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          data.dailyUsed.length,
                          (i) => FlSpot(
                            i.toDouble(),
                            data.dailyUsed[i]['y'] as double,
                          ),
                        ),
                        isCurved: true,
                        color: Colors.red,
                        barWidth: isCompact ? 2.5 : 3,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusCard(DashboardData data) {
    final latest = data.dailyUsed.isNotEmpty
        ? data.dailyUsed.first['y'] as double
        : 0.0;
    return _panel(
      title: 'Status',
      subtitle: 'Current device state and recent readings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _confirmPump(true),
                child: const Text('Pump On'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _confirmPump(false),
                child: const Text('Pump Off'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Voltage: 1.22 Amps: 0.00    Pump is off. ${latest.toStringAsFixed(2)}A',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _readingChip('Voltage: 12.66', Colors.blueGrey.shade50),
              _readingChip('Amps: 0.08', Colors.blueGrey.shade50),
              _readingChip('Pump is off.', Colors.red.shade50),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  FlTitlesData _hourTitles(
    List<String> labels, {
    int step = 1,
    bool compact = false,
  }) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: compact ? 32 : 40,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox.shrink();
            return Text(
              value.toStringAsFixed(1),
              style: TextStyle(fontSize: compact ? 9 : 10),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: compact ? 22 : 28,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
            if (step > 1 && idx % step != 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                labels[idx],
                style: TextStyle(fontSize: compact ? 8 : 9),
              ),
            );
          },
        ),
      ),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlTitlesData _dayTitles(
    List<Map<String, dynamic>> dailyUsed, {
    int step = 1,
    bool compact = false,
  }) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: compact ? 34 : 40,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox.shrink();
            return Text(
              value.toStringAsFixed(0),
              style: TextStyle(fontSize: compact ? 9 : 10),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: compact ? 22 : 28,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= dailyUsed.length) {
              return const SizedBox.shrink();
            }
            if (step > 1 && idx % step != 0) return const SizedBox.shrink();
            final date = dailyUsed[idx]['x'] as String;
            final label = compact && date.length >= 5
                ? date.substring(5)
                : date;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label, style: TextStyle(fontSize: compact ? 8 : 9)),
            );
          },
        ),
      ),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _chartLegend({bool compact = false}) {
    final size = compact ? 10.0 : 14.0;
    final fontSize = compact ? 10.0 : 12.0;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _LegendDot(
          color: const Color(0xFF1997FF),
          text: 'Bar A',
          size: size,
          fontSize: fontSize,
        ),
        _LegendDot(
          color: const Color(0xFFFF8A00),
          text: 'Bar B',
          size: size,
          fontSize: fontSize,
        ),
        _LegendDot(
          color: const Color(0xFF1A39FF),
          text: 'Trend A',
          size: size,
          fontSize: fontSize,
        ),
        _LegendDot(
          color: const Color(0xFF7BC67E),
          text: 'Trend B',
          size: size,
          fontSize: fontSize,
        ),
      ],
    );
  }

  Widget _statusBar({
    required String label,
    required double value,
    required bool active,
  }) {
    final background = active
        ? const Color(0xFFB6D9F5)
        : const Color(0xFFD8EAF8);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF8FC7F1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readingChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  double _maxOf(List<double> values) {
    if (values.isEmpty) return 1;
    return values.reduce((a, b) => a > b ? a : b);
  }

  double _chartMax(
    List<double> values, {
    double min = 1.0,
    double padding = 0.4,
  }) {
    final maxValue = _maxOf(values);
    final padded = maxValue + padding + (maxValue * 0.1);
    return padded < min ? min : padded;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;
  final double size;
  final double fontSize;

  const _LegendDot({
    required this.color,
    required this.text,
    this.size = 14,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: size, height: size, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: fontSize)),
      ],
    );
  }
}
