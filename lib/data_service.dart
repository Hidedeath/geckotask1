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

  DataService({DateTime? anchorDate, int days = 5})
    : availableDates = _buildDates(anchorDate ?? DateTime.now(), days);

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
    for (var i = 0; i < 7; i++) {
      final day = start.subtract(Duration(days: i));
      final level =
          base * 3 + ((seed + i) % 5) * 0.7 + (6 - i) * 0.5 + tick * 0.2;
      items.add({'x': _formatDate(day), 'y': _round(level)});
    }
    return items;
  }

  double _round(double value) => double.parse(value.toStringAsFixed(2));
}
