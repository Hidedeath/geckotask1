import 'dart:async';
import 'dart:math';

// The blueprint for a single live point on the chart
class EnergyDataPoint {
  final double time;
  final double solar;
  final double office;
  final double total;

  EnergyDataPoint({
    required this.time,
    required this.solar,
    required this.office,
    required this.total,
  });
}

class DashboardData {
  final List<String> labels;
  final List<double> hourlyBar;
  final List<double> hourlyBar2;
  final List<Map<String, dynamic>> dailyUsed;
  DashboardData({
    required this.labels,
    required this.hourlyBar,
    required this.hourlyBar2,
    required this.dailyUsed,
  });
}

class DataService {
  final List<String> availableDates;
  final Map<String, int> _graphTicks = {};

  // --- LIVE STREAM VARIABLES ---
  final StreamController<List<EnergyDataPoint>> _controller =
      StreamController<List<EnergyDataPoint>>.broadcast();
  Timer? _timer;
  final List<EnergyDataPoint> _currentLiveData = [];
  final Random _random = Random();
  String currentZone = 'Main'; // Default starting zone
  double _currentTimeIndex = 0;

  Stream<List<EnergyDataPoint>> get energyStream => _controller.stream;

  DataService({DateTime? anchorDate, int days = 5})
    : availableDates = _buildDates(anchorDate ?? DateTime.now(), days);

  // --- LIVE STREAM METHODS ---
  void startSimulation() {
    _generateHistoricalLiveData();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      _addLivePoint();
    });
  }

  void stopSimulation() {
    _timer?.cancel();
    _controller.close();
  }

  void switchZone(String newZone) {
    currentZone = newZone;
    _currentTimeIndex = 0;
    _generateHistoricalLiveData();
    _controller.add(List.from(_currentLiveData));
  }

  void _generateHistoricalLiveData() {
    _currentLiveData.clear();
    for (int i = 0; i < 15; i++) {
      _addLivePoint();
    }
  }

  void _addLivePoint() {
    double solar = 0, office = 0, total = 0;

    switch (currentZone) {
      case 'Main':
        solar = 0.5 + _random.nextDouble() * 0.8;
        office = 0.8 + _random.nextDouble() * 0.5;
        total = solar + office;
        break;
      case 'Aircon':
      case 'Aircon In':
        solar = 0.0;
        office = 1.5 + _random.nextDouble() * 1.2;
        total = office;
        break;
      case 'Aircon Net':
        solar = 0.0;
        office = 2.0 + _random.nextDouble() * 0.3;
        total = office;
        break;
      case 'Office':
        solar = 0.0;
        office = 0.3 + _random.nextDouble() * 0.2;
        total = office;
        break;
    }

    _currentLiveData.add(
      EnergyDataPoint(
        time: _currentTimeIndex,
        solar: solar,
        office: office,
        total: total,
      ),
    );

    if (_currentLiveData.length > 20) {
      _currentLiveData.removeAt(0);
    }
    _currentTimeIndex += 1;

    if (!_controller.isClosed) {
      _controller.add(List.from(_currentLiveData));
    }
  }

  // --- TEAMMATE'S STATIC DATA METHODS ---
  Future<DashboardData> fetchDashboard({
    String tpl = 'meters',
    String? date,
  }) async {
    return fetchSection(tpl, date: date);
  }

  Future<DashboardData> triggerGraph(String tpl, String date) async {
    final key = '$tpl|$date';
    _graphTicks[key] = (_graphTicks[key] ?? 0) + 1;
    return fetchSection(tpl, date: date);
  }

  Future<DashboardData> pumpOn({String? date}) async {
    return fetchSection('meters', date: date ?? availableDates.first);
  }

  Future<DashboardData> pumpOff({String? date}) async {
    return fetchSection('meters', date: date ?? availableDates.first);
  }

  Future<DashboardData> fetchSection(String tpl, {String? date}) async {
    final selectedDate = date ?? availableDates.first;
    final tick = _graphTicks['$tpl|$selectedDate'] ?? 0;
    return _buildData(tpl, selectedDate, tick);
  }

  DashboardData _buildData(String tpl, String date, int tick) {
    final labels = List.generate(
      24,
      (i) => '${i.toString().padLeft(2, '0')}:00',
    );
    final seed = _hash('$tpl|$date');
    final base = 0.8 + (seed % 5) * 0.25;

    final hourlyBar = List<double>.generate(
      24,
      (i) => _seriesValue(
        hour: i,
        base: base,
        seed: seed,
        tick: tick,
        scale: 0.18,
        drift: 0.8,
      ),
    );

    final hourlyBar2 = List<double>.generate(
      24,
      (i) => _seriesValue(
        hour: i,
        base: base * 0.8,
        seed: seed + 3,
        tick: tick,
        scale: 0.12,
        drift: 0.6,
      ),
    );

    final dailyUsed = _buildDailyWindow(date, seed, base, tick);

    return DashboardData(
      labels: labels,
      hourlyBar: hourlyBar,
      hourlyBar2: hourlyBar2,
      dailyUsed: dailyUsed,
    );
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

  double _seriesValue({
    required int hour,
    required double base,
    required int seed,
    required int tick,
    required double scale,
    required double drift,
  }) {
    final bump = ((hour % 6) + 1) * scale;
    final wave = ((seed + hour) % 7) * 0.03;
    final value =
        base +
        bump +
        (hour / 24) * drift +
        tick * 0.05 +
        (hour.isEven ? wave : -wave);
    return _round(value);
  }

  List<Map<String, dynamic>> _buildDailyWindow(
    String date,
    int seed,
    double base,
    int tick,
  ) {
    final start = DateTime.parse(date);
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < 30; i++) {
      final day = start.subtract(Duration(days: i));
      final level =
          base * 6 + ((seed + i) % 9) * 0.8 + (i % 6) * 0.45 + tick * 0.2;
      items.add({'x': _formatDate(day), 'y': _round(level)});
    }
    return items;
  }

  double _round(double value) => double.parse(value.toStringAsFixed(2));
}
