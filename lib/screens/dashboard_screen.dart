import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../app_strings.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.strings, this.isEmbedded = false});
  final AppStrings strings;
  final bool isEmbedded;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    if (widget.isEmbedded) {
      return DashboardContent(strings: widget.strings);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.t('dashboardTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: DashboardContent(strings: widget.strings),
    );
  }
}

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key, required this.strings, this.isScrollable = true});
  final AppStrings strings;
  final bool isScrollable;

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final DBHelper _dbHelper = DBHelper.instance;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await _dbHelper.getDashboardStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Section: Indicators & Gauges
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _CircularIndicatorCard(
                    title: 'Przegląd beczek (Lód/Woda)',
                    value: _stats['barrelRate'] ?? 0.0,
                    label: 'OK',
                    icon: Icons.opacity,
                    color: Colors.blue,
                    trend: 0,
                  ),
                  const SizedBox(height: 8),
                  _CircularIndicatorCard(
                    title: 'Kamery wizyjne',
                    value: _stats['cameraRate'] ?? 0.0,
                    label: 'CZYSTE',
                    icon: Icons.videocam_outlined,
                    color: Colors.green,
                    trend: 0,
                  ),
                  _NumericStatCard(
                    title: 'Otwarte awarie',
                    value: (_stats['openFailures'] ?? 0).toString(),
                    unit: 'SZT',
                    trend: 0,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _NumericStatCard(
                    title: 'Suma przestojów (Prod)',
                    value: (_stats['totalProductionDowntime'] ?? 0).toStringAsFixed(0),
                    unit: 'MIN',
                    trend: 0,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _NumericStatCard(
                    title: 'Przestoje awaryjne',
                    value: (_stats['failureDowntimeHours'] ?? 0).toStringAsFixed(1),
                    unit: 'GODZ',
                    trend: 0,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(height: 8),
                  _NumericStatCard(
                    title: 'Wadliwe wózki',
                    value: (_stats['totalDefectiveCarts'] ?? 0).toString(),
                    unit: 'SZT',
                    trend: 0,
                    color: Colors.blueGrey,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 2. Middle Section: Line Chart (Downtime Trend)
        _ChartContainer(
          title: 'Trend przestojów (minuty/dzień)',
          child: _TrendLineChart(data: Map<String, double>.from(_stats['dailyDowntime'] ?? {})),
        ),
        
        const SizedBox(height: 12),
        
        // 3. Bottom Section: Bar Chart (Defective Carts Trend)
        _ChartContainer(
          title: 'Wadliwe wózki wg dni',
          child: _ActivityBarChart(data: Map<String, int>.from(_stats['dailyDefects'] ?? {})),
        ),
        
        const SizedBox(height: 24),
        
        _SectionTitle(title: 'Awarie wg linii produkcyjnych'),
        const SizedBox(height: 8),
        _SimpleBarChart(
          data: Map<String, int>.from(_stats['lineFailureStats'] ?? {}),
          color: Colors.red.shade400,
        ),
      ],
    );

    if (widget.isScrollable) {
      return RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: content,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: content,
      );
    }
  }
}

class _ChartContainer extends StatelessWidget {
  const _ChartContainer({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const Spacer(),
                const Icon(Icons.more_horiz, size: 16, color: Colors.grey),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(height: 200, child: child),
          ),
        ],
      ),
    );
  }
}

class _CircularIndicatorCard extends StatelessWidget {
  const _CircularIndicatorCard({
    required this.title,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.trend,
  });

  final String title;
  final double value;
  final String label;
  final IconData icon;
  final Color color;
  final double trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, size: 32, color: Colors.grey.shade400),
              const Spacer(),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: value / 10,
                      strokeWidth: 5,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(value * 10).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumericStatCard extends StatelessWidget {
  const _NumericStatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.trend,
    required this.color,
  });

  final String title;
  final String value;
  final String unit;
  final double trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({required this.data});
  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('Brak danych'));

    final sortedKeys = data.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedKeys.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[sortedKeys[i]]!));
    }

    final maxY = data.values.isEmpty ? 100.0 : data.values.reduce((a, b) => a > b ? a : b) * 1.2;

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < sortedKeys.length) {
                  final date = sortedKeys[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(date.substring(5), style: const TextStyle(fontSize: 8, color: Colors.grey)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 8, color: Colors.grey)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (sortedKeys.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}

class _ActivityBarChart extends StatelessWidget {
  const _ActivityBarChart({required this.data});
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('Brak danych'));

    final sortedKeys = data.keys.toList()..sort();
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < sortedKeys.length; i++) {
      groups.add(BarChartGroupData(x: i, barRods: [BarChartRodData(toY: data[sortedKeys[i]]!.toDouble(), color: Colors.blue.shade700, width: 12, borderRadius: BorderRadius.circular(4))]));
    }

    final maxY = data.values.isEmpty ? 10.0 : data.values.reduce((a, b) => a > b ? a : b) * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < sortedKeys.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(sortedKeys[value.toInt()].substring(5), style: const TextStyle(fontSize: 8, color: Colors.grey)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 8, color: Colors.grey)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        barGroups: groups,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  const _SimpleBarChart({required this.data, this.color = Colors.blue});
  final Map<String, int> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Brak danych'));
    }

    final maxVal = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: data.entries.map((e) {
          final percent = e.value / maxVal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                    Text(e.value.toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.6), color],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ContributorList extends StatelessWidget {
  const _ContributorList({required this.data, required this.icon});
  final Map<String, int> data;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Brak danych'));
    }

    final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedEntries.take(3).toList();

    return Column(
      children: top3.map((e) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                e.value.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
