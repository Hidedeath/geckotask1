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
  final ScrollController _hourlyScrollController = ScrollController();
  final ScrollController _dailyScrollController = ScrollController();
  DashboardData? _data;
  bool _loading = false;
  String _selectedSection = 'Main';
  late final List<String> _availableDates;
  String _selectedDate = '';
  bool _showPreviousTrend = true;
  bool _showSelectedTrend = true;
  bool _showPreviousBar = true;
  bool _showSelectedBar = true;

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
    _hourlyScrollController.dispose();
    _dailyScrollController.dispose();
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
      case 'Aircon In':
        return 'in';
      case 'Aircon Net':
        return 'savings';
      case 'Office':
        return 'office';
      case 'Aircon':
        return 'aircon';
      case 'Main':
      default:
        return 'meters';
    }
  }

  bool get _isMainSection => _selectedSection == 'Main';
  bool get _isAirconSection => _selectedSection.startsWith('Aircon');

  String get _hourlyChartTitle {
    if (_isMainSection) return 'Main System Hourly';
    if (_isAirconSection) return 'Aircon Circuit Hourly';
    return '$_selectedSection Hourly';
  }

  String get _hourlyChartSubtitle {
    if (_isMainSection) return 'Solar generation and total consumption';
    if (_isAirconSection) return 'Circuit-specific cooling demand';
    return 'Circuit-specific energy usage';
  }

  String get _monthlyChartTitle {
    if (_isMainSection) return 'Main 30-Day Trend';
    if (_isAirconSection) return 'Aircon 30-Day Usage Trend';
    return '$_selectedSection 30-Day Trend';
  }

  String get _monthlyChartSubtitle {
    if (_isMainSection) return 'Daily system kWh with smoothed performance trend';
    if (_isAirconSection) return 'Daily aircon kWh with smoothed usage trend';
    return 'Daily circuit kWh with smoothed usage trend';
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
    try {
      final next = on
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Monitor - $_selectedSection',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.1),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monitor_heart, color: Colors.cyanAccent, size: 48),
                  SizedBox(height: 10),
                  Text(
                    'ZONES',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 20,
                      letterSpacing: 2,
                    ),
                  ),
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
                    ],
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
      title: Text(
        label,
        style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white),
      ),
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 20.0),
            child: Text(
              "LIVE DRAW",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: StreamBuilder<List<EnergyDataPoint>>(
              stream: _service.energyStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text(
                    "0.00 kW",
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  );
                }
                final latest = snapshot.data!.last;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      latest.total.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0, left: 8.0),
                      child: Text(
                        "kW",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<EnergyDataPoint>>(
              stream: _service.energyStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty)
                  return const SizedBox();
                final data = snapshot.data!;
                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: Colors.grey.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (v, m) => Text(
                            v.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data
                            .map((e) => FlSpot(e.time, e.office))
                            .toList(),
                        isCurved: true,
                        color: Colors.cyanAccent,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.cyanAccent.withOpacity(0.1),
                        ),
                      ),
                      if (_selectedSection == 'Main')
                        LineChartBarData(
                          spots: data
                              .map((e) => FlSpot(e.time, e.solar))
                              .toList(),
                          isCurved: true,
                          color: Colors.yellowAccent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- TEAMMATE'S STATIC PANELS (Updated for Dark Mode UI) ---
  Widget _headerCard(DashboardData data) {
    final totals = data.dailyUsed.map((e) => e['y'] as double).toList();
    final total = totals.isEmpty
        ? 0.0
        : totals.reduce((value, element) => value + element);
    final average = totals.isEmpty ? 0.0 : total / totals.length;
    final statsText =
        'Average: ${average.toStringAsFixed(2)} kWh   Total: ${total.toStringAsFixed(2)} kWh';

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
                const Text(
                  'Data source: embedded sample',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _load,
                  child: const Text(
                    'Refresh',
                    style: TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_availableDates.isNotEmpty) ...[
              const Text(
                'Date',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
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
                    selectedColor: Colors.cyanAccent.withOpacity(0.2),
                    showCheckmark: false,
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
        final axisWidth = isCompact ? 32.0 : 40.0;
        final chartViewportWidth = constraints.maxWidth - axisWidth;
        final chartWidth = chartViewportWidth > 760
            ? chartViewportWidth
            : 760.0;
        final chartHeight = isCompact ? 240.0 : 320.0;
        return _panel(
          title: _hourlyChartTitle,
          subtitle: _hourlyChartSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _chartLegend(compact: isCompact),
              const SizedBox(height: 8),
              SizedBox(
                height: chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fixedYAxis(
                      maxY: maxY,
                      width: axisWidth,
                      bottomReserved: isCompact ? 22 : 28,
                      interval: 0.5,
                      decimals: 1,
                      compact: isCompact,
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _hourlyScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _hourlyScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            height: chartHeight,
                            child: Stack(
                              children: [
                                BarChart(
                                  BarChartData(
                                    minY: 0,
                                    maxY: maxY,
                                    alignment: BarChartAlignment.spaceAround,
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      getDrawingHorizontalLine: (v) => FlLine(
                                        color: Colors.grey.withOpacity(0.1),
                                        strokeWidth: 1,
                                      ),
                                    ),
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
                                          if (_showPreviousBar)
                                            BarChartRodData(
                                              toY: y,
                                              color: const Color(0xFF1997FF),
                                              width: isCompact ? 6 : 8,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          if (_showSelectedBar)
                                            BarChartRodData(
                                              toY: y2,
                                              color: const Color(0xFFFF8A00),
                                              width: isCompact ? 6 : 8,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                        ],
                                      );
                                    }),
                                    titlesData: _hourTitles(
                                      labels,
                                      step: isCompact ? 3 : 1,
                                      compact: isCompact,
                                      showLeft: false,
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
                                      if (_showPreviousTrend)
                                        LineChartBarData(
                                          spots: List.generate(
                                            24,
                                            (i) => FlSpot(
                                              i.toDouble(),
                                              i < data.hourlyBar.length
                                                  ? data.hourlyBar[i]
                                                  : 0.0,
                                            ),
                                          ),
                                          isCurved: true,
                                          color: const Color(0xFF1A39FF),
                                          barWidth: isCompact ? 2.5 : 3,
                                          dotData: const FlDotData(show: false),
                                        ),
                                      if (_showSelectedTrend)
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
                                          dotData: const FlDotData(show: false),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dailyCard(DashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final monthlyTrend = data.dailyUsed.reversed.toList();
        final barValues = monthlyTrend.map((e) => e['y'] as double).toList();
        final trendValues = _movingAverage(barValues, radius: 2);
        final maxY = _chartMax(
          [...barValues, ...trendValues],
          min: 1.0,
          padding: 2.0,
        );
        final dailyTotal = monthlyTrend.fold<double>(
          0,
          (sum, item) => sum + (item['y'] as double),
        );
        final dailyAverage = monthlyTrend.isEmpty
            ? 0.0
            : dailyTotal / monthlyTrend.length;
        final chartWidth = constraints.maxWidth > monthlyTrend.length * 38.0
            ? constraints.maxWidth
            : monthlyTrend.length * 38.0;
        final trendMaxX = monthlyTrend.isEmpty
            ? 0.5
            : monthlyTrend.length - 0.5;
        final axisWidth = isCompact ? 34.0 : 40.0;
        final chartHeight = isCompact ? 220.0 : 280.0;
        return _panel(
          title: _monthlyChartTitle,
          subtitle: _monthlyChartSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dailyLegend(compact: isCompact),
              const SizedBox(height: 8),
              SizedBox(
                height: chartHeight,
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _fixedYAxis(
                          maxY: maxY,
                          width: axisWidth,
                          bottomReserved: (isCompact ? 22 : 28) + 18,
                          interval: 5,
                          decimals: 0,
                          compact: isCompact,
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: _dailyScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _dailyScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: chartWidth,
                                height: chartHeight,
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 18,
                                      ),
                                      child: BarChart(
                                        BarChartData(
                                          alignment:
                                              BarChartAlignment.spaceAround,
                                          minY: 0,
                                          maxY: maxY,
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: false,
                                            getDrawingHorizontalLine: (v) =>
                                                FlLine(
                                                  color: Colors.grey
                                                      .withOpacity(0.1),
                                                  strokeWidth: 1,
                                                ),
                                          ),
                                          borderData: FlBorderData(show: false),
                                          barTouchData: BarTouchData(
                                            enabled: true,
                                            touchTooltipData:
                                                BarTouchTooltipData(
                                                  tooltipPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6,
                                                      ),
                                                  tooltipMargin: 8,
                                                  fitInsideHorizontally: true,
                                                  fitInsideVertically: true,
                                                  getTooltipColor: (_) =>
                                                      Colors.black87,
                                                  getTooltipItem:
                                                      (
                                                        group,
                                                        groupIndex,
                                                        rod,
                                                        rodIndex,
                                                      ) {
                                                        return BarTooltipItem(
                                                          _dailyTooltipText(
                                                            monthlyTrend,
                                                            groupIndex,
                                                            rod.toY,
                                                            trendValues[groupIndex],
                                                          ),
                                                          const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                          textAlign:
                                                              TextAlign.left,
                                                        );
                                                      },
                                                ),
                                          ),
                                          barGroups: List.generate(
                                            monthlyTrend.length,
                                            (i) {
                                              final date = DateTime.parse(
                                                monthlyTrend[i]['x'] as String,
                                              );
                                              return BarChartGroupData(
                                                x: i,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: barValues[i],
                                                    width: isCompact ? 8 : 10,
                                                    color: _isSunday(date)
                                                        ? const Color(
                                                            0xFFFF8D8D,
                                                          )
                                                        : const Color(
                                                            0xFF9EC5E6,
                                                          ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          titlesData: _dayTitles(
                                            monthlyTrend,
                                            step: isCompact ? 3 : 1,
                                            compact: isCompact,
                                            showLeft: false,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 18,
                                      ),
                                      child: IgnorePointer(
                                        child: LineChart(
                                          LineChartData(
                                            minX: -0.5,
                                            maxX: trendMaxX,
                                            minY: 0,
                                            maxY: maxY,
                                            gridData: FlGridData(show: false),
                                            borderData: FlBorderData(
                                              show: false,
                                            ),
                                            titlesData: FlTitlesData(
                                              show: false,
                                            ),
                                            lineTouchData: const LineTouchData(
                                              enabled: false,
                                            ),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: List.generate(
                                                  trendValues.length,
                                                  (i) => FlSpot(
                                                    i.toDouble(),
                                                    trendValues[i],
                                                  ),
                                                ),
                                                isCurved: true,
                                                color: Colors.redAccent,
                                                barWidth: isCompact ? 2.5 : 3,
                                                dotData: const FlDotData(
                                                  show: true,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 2,
                      bottom: 0,
                      child: Text(
                        'Average (of last 30 days): ${dailyAverage.toStringAsFixed(2)}kWh Total: ${dailyTotal.toStringAsFixed(2)}kWh',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: isCompact ? 9 : 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusCard(DashboardData data) {
    final latest = data.dailyUsed.isNotEmpty
        ? data.dailyUsed.first['y'] as double
        : 0.0;
    final readingTime = '${_legendDate(_selectedDate)} 11:17';
    return _panel(
      title: 'Status',
      subtitle: 'Current device state and recent readings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusProgressBar(value: 0.66, label: '66% ($readingTime)'),
          const SizedBox(height: 4),
          _statusActionLabels(),
          const SizedBox(height: 8),
          _statusProgressBar(
            value: 1,
            label: '100% (10978742.00) ($readingTime)',
          ),
          const SizedBox(height: 6),
          Text(
            'Voltage: 30.80 Amps: 12.21        Voltage: 42.73 Amps: 0.80        Pump is off. ${latest.toStringAsFixed(2)}A',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyLegend({bool compact = false}) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: [
        _StaticLegendDot(
          color: Colors.redAccent,
          text: 'Trend',
          size: compact ? 10 : 14,
          fontSize: compact ? 10 : 12,
        ),
        _StaticLegendDot(
          color: const Color(0xFFFF8D8D),
          text: 'Sundays',
          size: compact ? 10 : 14,
          fontSize: compact ? 10 : 12,
        ),
        _StaticLegendDot(
          color: const Color(0xFF9EC5E6),
          text: 'Days',
          size: compact ? 10 : 14,
          fontSize: compact ? 10 : 12,
        ),
      ],
    );
  }

  String _dailyTooltipText(
    List<Map<String, dynamic>> dailyUsed,
    int index,
    double value,
    double? trendValue,
  ) {
    if (index < 0 || index >= dailyUsed.length) {
      final trendText = trendValue == null
          ? ''
          : '\nTrend: ${trendValue.toStringAsFixed(2)}';
      return 'Days: ${value.toStringAsFixed(2)}$trendText';
    }

    final date = DateTime.parse(dailyUsed[index]['x'] as String);
    final day = _weekdayLabel(date.weekday);
    final month = date.month.toString().padLeft(2, '0');
    final dateDay = date.day.toString().padLeft(2, '0');
    final marker = _isSunday(date) ? 'Sunday\n' : '';
    final trendText = trendValue == null
        ? ''
        : '\nTrend: ${trendValue.toStringAsFixed(2)}';
    return '$day $month/$dateDay\n${marker}Days: ${value.toStringAsFixed(2)}$trendText';
  }

  bool _isSunday(DateTime date) => date.weekday == DateTime.sunday;

  List<double> _movingAverage(List<double> values, {int radius = 2}) {
    if (values.isEmpty) return const [];

    return List<double>.generate(values.length, (index) {
      final start = (index - radius).clamp(0, values.length - 1).toInt();
      final end = (index + radius).clamp(0, values.length - 1).toInt();
      var total = 0.0;

      for (var i = start; i <= end; i++) {
        total += values[i];
      }

      return total / (end - start + 1);
    });
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday - 1];
  }

  Widget _statusActionLabels() {
    return Row(
      children: [
        InkWell(
          onTap: () => _confirmPump(true),
          mouseCursor: SystemMouseCursors.click,
          child: const Text(
            'Turn On!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => _confirmPump(false),
          mouseCursor: SystemMouseCursors.click,
          child: const Text(
            'Turn Off!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusProgressBar({required double value, required String label}) {
    final clampedValue = value.clamp(0.0, 1.0);
    return SizedBox(
      height: 24,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade500),
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: clampedValue,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.lightBlue.shade200),
            ),
          ),
          Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
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
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade400)),
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
    bool showLeft = true,
  }) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: showLeft,
          reservedSize: compact ? 32 : 40,
          getTitlesWidget: (v, m) => v == 0
              ? const SizedBox.shrink()
              : Text(
                  v.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    color: Colors.grey,
                  ),
                ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: compact ? 22 : 28,
          getTitlesWidget: (v, m) {
            final idx = v.toInt();
            if (idx < 0 ||
                idx >= labels.length ||
                (step > 1 && idx % step != 0))
              return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                labels[idx],
                style: TextStyle(fontSize: compact ? 8 : 9, color: Colors.grey),
              ),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlTitlesData _dayTitles(
    List<Map<String, dynamic>> dailyUsed, {
    int step = 1,
    bool compact = false,
    bool showLeft = true,
  }) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: showLeft,
          reservedSize: compact ? 34 : 40,
          getTitlesWidget: (v, m) => v == 0
              ? const SizedBox.shrink()
              : Text(
                  v.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    color: Colors.grey,
                  ),
                ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: compact ? 22 : 28,
          getTitlesWidget: (v, m) {
            final idx = v.toInt();
            if (idx < 0 ||
                idx >= dailyUsed.length ||
                (step > 1 && idx % step != 0))
              return const SizedBox.shrink();
            final date = dailyUsed[idx]['x'] as String;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                compact && date.length >= 5 ? date.substring(5) : date,
                style: TextStyle(fontSize: compact ? 8 : 9, color: Colors.grey),
              ),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _fixedYAxis({
    required double maxY,
    required double width,
    required double bottomReserved,
    required double interval,
    required int decimals,
    bool compact = false,
  }) {
    final labels = <double>[];
    for (var value = interval; value <= maxY; value += interval) {
      labels.add(value);
    }

    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotHeight = constraints.maxHeight - bottomReserved;
          return Stack(
            clipBehavior: Clip.none,
            children: labels.map((value) {
              final top = ((maxY - value) / maxY * plotHeight) - 6;
              return Positioned(
                top: top,
                right: 8,
                child: Text(
                  value.toStringAsFixed(decimals),
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    color: Colors.grey,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _chartLegend({bool compact = false}) {
    final selectedDate = _legendDate(_selectedDate);
    final previousDate = _legendDate(_previousDate(_selectedDate));
    final trendLabel = _isMainSection ? 'Solar' : 'Trend';
    final barLabel = _isMainSection ? 'Total' : 'Usage';

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _LegendDot(
          color: const Color(0xFF1A39FF),
          text: '$trendLabel: $previousDate',
          isActive: _showPreviousTrend,
          onTap: () => setState(() => _showPreviousTrend = !_showPreviousTrend),
          size: compact ? 10 : 14,
          fontSize: compact ? 10 : 12,
        ),
        _LegendDot(
          color: const Color(0xFF7BC67E),
          text: '$trendLabel: $selectedDate',
          isActive: _showSelectedTrend,
          onTap: () => setState(() => _showSelectedTrend = !_showSelectedTrend),
          size: compact ? 10 : 14,
          fontSize: compact ? 10 : 12,
        ),
        _LegendDot(
          color: const Color(0xFF1997FF),
          text: '$barLabel: $previousDate',
          isActive: _showPreviousBar,
          onTap: () => setState(() => _showPreviousBar = !_showPreviousBar),
          size: compact ? 10 : 14,
          fontSize: compact ? 10 : 12,
        ),
        _LegendDot(
          color: const Color(0xFFFF8A00),
          text: '$barLabel: $selectedDate',
          isActive: _showSelectedBar,
          onTap: () => setState(() => _showSelectedBar = !_showSelectedBar),
          size: compact ? 10 : 14,
          fontSize: compact ? 10 : 12,
        ),
      ],
    );
  }

  String _previousDate(String date) {
    if (date.isEmpty) return date;
    final previous = DateTime.parse(date).subtract(const Duration(days: 1));
    return '${previous.year.toString().padLeft(4, '0')}-${previous.month.toString().padLeft(2, '0')}-${previous.day.toString().padLeft(2, '0')}';
  }

  String _legendDate(String date) {
    if (date.isEmpty) return '';
    return _formatLegendDate(DateTime.parse(date));
  }

  String _formatLegendDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
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
  final bool isActive;
  final VoidCallback? onTap;

  const _LegendDot({
    required this.color,
    required this.text,
    this.size = 14,
    this.fontSize = 12,
    this.isActive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isActive ? 'Hide $text' : 'Show $text',
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(4),
        child: Opacity(
          opacity: isActive ? 1 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: size, height: size, color: color),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.grey,
                    decoration: isActive ? null : TextDecoration.lineThrough,
                    decorationColor: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticLegendDot extends StatelessWidget {
  final Color color;
  final String text;
  final double size;
  final double fontSize;

  const _StaticLegendDot({
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
        Text(
          text,
          style: TextStyle(fontSize: fontSize, color: Colors.grey),
        ),
      ],
    );
  }
}
