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
  String _selectedSection = 'Main';
  late final List<String> _availableDates;
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    _availableDates = _service.availableDates;
    _selectedDate = _availableDates.isNotEmpty ? _availableDates.first : '';
    _service.startSimulation(); // Start Live Heartbeat
    _load();
  }

  @override
  void dispose() {
    _service.stopSimulation(); // Prevent memory leaks
    super.dispose();
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
    final next = await _service.triggerGraph(_sectionToTpl(_selectedSection), _selectedDate);
    if (!mounted) return;
    setState(() {
      _data = next;
      _loading = false;
    });
  }

  // Called when the user taps a zone in the Sidebar Drawer
  Future<void> _onSectionSelected(String label) async {
    setState(() => _loading = true);
    
    _service.switchZone(label); // Update live stream

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
      case 'Aircon In': return 'in';
      case 'Aircon Net': return 'savings';
      case 'Office': return 'office';
      case 'Aircon': 
      case 'Main':
      default: return 'meters';
    }
  }

  Future<void> _confirmPump(bool on) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(on ? 'Confirm Turn Pump On' : 'Confirm Turn Pump Off'),
        content: Text(on ? 'This will send a pump on command to the device.' : 'This will send a pump off command to the device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      final next = on ? await _service.pumpOn(date: _selectedDate) : await _service.pumpOff(date: _selectedDate);
      if (!mounted) return;
      setState(() {
        _data = next;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(on ? 'Pump turned on' : 'Pump turned off')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Monitor - $_selectedSection', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // --- THE SIDEBAR DRAWER ---
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.1)),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monitor_heart, color: Colors.cyanAccent, size: 48),
                  SizedBox(height: 10),
                  Text('ZONES', style: TextStyle(color: Colors.cyanAccent, fontSize: 20, letterSpacing: 2)),
                ],
              ),
            ),
            _drawerTile('Main', Icons.bolt),
            _drawerTile('Aircon', Icons.ac_unit),
            _drawerTile('Aircon In', Icons.ac_unit),
            _drawerTile('Aircon Net', Icons.router),
            _drawerTile('Office', Icons.desktop_windows),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading && data == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _liveHeroCard(), // Our new integrated live chart
                    const SizedBox(height: 16),
                    if (data != null) ...[
                      _headerCard(data), // Teammate's static cards below
                      const SizedBox(height: 12),
                      _hourlyCard(data),
                      const SizedBox(height: 16),
                      _dailyCard(data),
                      const SizedBox(height: 16),
                      _statusCard(data),
                    ]
                  ],
                ),
              ),
      ),
    );
  }

  // Sidebar List Tile Builder
  Widget _drawerTile(String label, IconData icon) {
    final isSelected = _selectedSection == label;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.cyanAccent : Colors.grey),
      title: Text(label, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white)),
      selected: isSelected,
      selectedTileColor: Colors.cyanAccent.withOpacity(0.05),
      onTap: () {
        Navigator.pop(context); // Close the drawer smoothly
        if (!isSelected) {
          _onSectionSelected(label);
        }
      },
    );
  }

  // --- OUR NEW LIVE NEON CHART PANEL ---
  Widget _liveHeroCard() {
    return Container(
      height: 320,
      padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 20.0),
            child: Text("LIVE DRAW", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: StreamBuilder<List<EnergyDataPoint>>(
              stream: _service.energyStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text("0.00 kW", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold));
                }
                final latest = snapshot.data!.last;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      latest.total.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0, left: 8.0),
                      child: Text("kW", style: TextStyle(fontSize: 20, color: Colors.cyanAccent)),
                    ),
                  ],
                );
              }
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<EnergyDataPoint>>(
              stream: _service.energyStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                final data = snapshot.data!;
                return LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(1), style: const TextStyle(color: Colors.grey, fontSize: 12)))),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.map((e) => FlSpot(e.time, e.office)).toList(),
                        isCurved: true,
                        color: Colors.cyanAccent,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: Colors.cyanAccent.withOpacity(0.1)),
                      ),
                      if (_selectedSection == 'Main')
                        LineChartBarData(
                          spots: data.map((e) => FlSpot(e.time, e.solar)).toList(),
                          isCurved: true,
                          color: Colors.yellowAccent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  // --- TEAMMATE'S STATIC PANELS (Updated for Dark Mode UI) ---
  Widget _headerCard(DashboardData data) {
    final totals = data.dailyUsed.map((e) => e['y'] as double).toList();
    final total = totals.isEmpty ? 0.0 : totals.reduce((value, element) => value + element);
    final average = totals.isEmpty ? 0.0 : total / totals.length;
    final statsText = 'Average: ${average.toStringAsFixed(2)} kWh   Total: ${total.toStringAsFixed(2)} kWh';
    
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Data source: embedded sample', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _load, child: const Text('Refresh', style: TextStyle(color: Colors.cyanAccent))),
              ],
            ),
            const SizedBox(height: 8),
            if (_availableDates.isNotEmpty) ...[
              const Text('Date', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableDates.map((date) {
                  return ChoiceChip(
                    label: Text(date),
                    selected: _selectedDate == date,
                    onSelected: (_) => _onDateSelected(date),
                    selectedColor: Colors.cyanAccent.withOpacity(0.2),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Text(statsText, style: TextStyle(color: Colors.grey.shade400)),
          ],
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
                    gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(24, (i) {
                      final y = i < data.hourlyBar.length ? data.hourlyBar[i] : 0.0;
                      final y2 = i < data.hourlyBar2.length ? data.hourlyBar2[i] : 0.0;
                      return BarChartGroupData(
                        x: i,
                        barsSpace: isCompact ? 3 : 4,
                        barRods: [
                          BarChartRodData(toY: y, color: const Color(0xFF1997FF), width: isCompact ? 6 : 8, borderRadius: BorderRadius.circular(2)),
                          BarChartRodData(toY: y2, color: const Color(0xFFFF8A00), width: isCompact ? 6 : 8, borderRadius: BorderRadius.circular(2)),
                        ],
                      );
                    }),
                    titlesData: _hourTitles(labels, step: isCompact ? 3 : 1, compact: isCompact),
                  ),
                ),
                LineChart(
                  LineChartData(
                    minY: 0, maxY: maxY,
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(spots: List.generate(24, (i) => FlSpot(i.toDouble(), i < data.hourlyBar.length ? data.hourlyBar[i] : 0.0)), isCurved: true, color: const Color(0xFF1A39FF), barWidth: isCompact ? 2.5 : 3, dotData: const FlDotData(show: false)),
                      LineChartBarData(spots: List.generate(24, (i) => FlSpot(i.toDouble(), i < data.hourlyBar2.length ? data.hourlyBar2[i] : 0.0)), isCurved: true, color: const Color(0xFF7BC67E), barWidth: isCompact ? 2 : 2.5, dotData: const FlDotData(show: false)),
                    ],
                  ),
                ),
                Positioned(top: 4, left: 0, right: 0, child: _chartLegend(compact: isCompact)),
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
        final barValues = data.dailyUsed.map((e) => (e['y'] as double) * 0.9).toList();
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
                    minY: 0, maxY: maxY,
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(data.dailyUsed.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [BarChartRodData(toY: barValues[i], width: isCompact ? 8 : 10, color: i % 4 == 0 ? const Color(0xFFFF8D8D) : const Color(0xFF9EC5E6))],
                      );
                    }),
                    titlesData: _dayTitles(data.dailyUsed, step: isCompact ? 2 : 1, compact: isCompact),
                  ),
                ),
                LineChart(
                  LineChartData(
                    minY: 0, maxY: maxY,
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(spots: List.generate(data.dailyUsed.length, (i) => FlSpot(i.toDouble(), data.dailyUsed[i]['y'] as double)), isCurved: true, color: Colors.redAccent, barWidth: isCompact ? 2.5 : 3, dotData: const FlDotData(show: true)),
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
    final latest = data.dailyUsed.isNotEmpty ? data.dailyUsed.first['y'] as double : 0.0;
    return _panel(
      title: 'Status',
      subtitle: 'Current device state and recent readings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: () => _confirmPump(true), 
                child: const Text('Pump On', style: TextStyle(fontWeight: FontWeight.bold))
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () => _confirmPump(false), 
                child: const Text('Pump Off', style: TextStyle(fontWeight: FontWeight.bold))
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Voltage: 1.22 Amps: 0.00    Pump is off. ${latest.toStringAsFixed(2)}A', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _readingChip('Voltage: 12.66', Colors.blueGrey.shade800),
              _readingChip('Amps: 0.08', Colors.blueGrey.shade800),
              _readingChip('Pump is off.', Colors.red.shade900),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panel({required String title, required String subtitle, required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  FlTitlesData _hourTitles(List<String> labels, {int step = 1, bool compact = false}) {
    return FlTitlesData(
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: compact ? 32 : 40, getTitlesWidget: (v, m) => v == 0 ? const SizedBox.shrink() : Text(v.toStringAsFixed(1), style: TextStyle(fontSize: compact ? 9 : 10, color: Colors.grey)))),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: compact ? 22 : 28, getTitlesWidget: (v, m) {
        final idx = v.toInt();
        if (idx < 0 || idx >= labels.length || (step > 1 && idx % step != 0)) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(labels[idx], style: TextStyle(fontSize: compact ? 8 : 9, color: Colors.grey)));
      })),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlTitlesData _dayTitles(List<Map<String, dynamic>> dailyUsed, {int step = 1, bool compact = false}) {
    return FlTitlesData(
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: compact ? 34 : 40, getTitlesWidget: (v, m) => v == 0 ? const SizedBox.shrink() : Text(v.toStringAsFixed(0), style: TextStyle(fontSize: compact ? 9 : 10, color: Colors.grey)))),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: compact ? 22 : 28, getTitlesWidget: (v, m) {
        final idx = v.toInt();
        if (idx < 0 || idx >= dailyUsed.length || (step > 1 && idx % step != 0)) return const SizedBox.shrink();
        final date = dailyUsed[idx]['x'] as String;
        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(compact && date.length >= 5 ? date.substring(5) : date, style: TextStyle(fontSize: compact ? 8 : 9, color: Colors.grey)));
      })),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _chartLegend({bool compact = false}) {
    return Wrap(
      spacing: 10, runSpacing: 8,
      children: [
        _LegendDot(color: const Color(0xFF1997FF), text: 'Bar A', size: compact ? 10 : 14, fontSize: compact ? 10 : 12),
        _LegendDot(color: const Color(0xFFFF8A00), text: 'Bar B', size: compact ? 10 : 14, fontSize: compact ? 10 : 12),
        _LegendDot(color: const Color(0xFF1A39FF), text: 'Trend A', size: compact ? 10 : 14, fontSize: compact ? 10 : 12),
        _LegendDot(color: const Color(0xFF7BC67E), text: 'Trend B', size: compact ? 10 : 14, fontSize: compact ? 10 : 12),
      ],
    );
  }

  Widget _readingChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white)),
    );
  }

  double _maxOf(List<double> values) {
    if (values.isEmpty) return 1;
    return values.reduce((a, b) => a > b ? a : b);
  }

  double _chartMax(List<double> values, {double min = 1.0, double padding = 0.4}) {
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

  const _LegendDot({required this.color, required this.text, this.size = 14, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: size, height: size, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: fontSize, color: Colors.grey)),
      ],
    );
  }
}