import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/z01_theme.dart';

/// One calendar day, reduced to what the charts need.
/// hours == 0 means the person did not clock in that day.
class _DayStat {
  final String label; // axis label
  final double hours; // time on premises
  final int arrivalMinutes; // minutes after midnight (522 = 08:42)
  const _DayStat(this.label, this.hours, this.arrivalMinutes);

  bool get present => hours > 0;
}

/// Frame 5: Insights. The campus is open 7 days a week, so every calendar
/// day is shown. Days without a check-in appear as gaps.
/// MOCK DATA for now. Real data comes from GET /attendance/history later.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _weekView = true;

  static List<_DayStat> _buildWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final list = <_DayStat>[];
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final label = weekdays[i];
      if (day.isAfter(now)) {
        list.add(_DayStat(label, 0, 0));
      } else if (i == 6) {
        list.add(_DayStat(label, 0, 0)); // Sunday
      } else if (i == 5) {
        list.add(_DayStat(label, 4.5, 600)); // Saturday
      } else {
        list.add(_DayStat(label, 8.2 + (i % 3) * 0.4, 495 + (i * 12) % 40));
      }
    }
    return list;
  }

  static List<_DayStat> _buildMonth() {
    final now = DateTime.now();
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    final list = <_DayStat>[];

    for (int d = 1; d <= totalDays; d++) {
      final date = DateTime(now.year, now.month, d);
      final wd = date.weekday; // 1 = Mon, 7 = Sun
      if (date.isAfter(now)) {
        list.add(_DayStat('$d', 0, 0));
      } else if (wd == 7) {
        list.add(_DayStat('$d', 0, 0)); // Sunday
      } else if (wd == 6) {
        list.add(d.isEven ? _DayStat('$d', 4.5, 600) : _DayStat('$d', 0, 0));
      } else {
        list.add(_DayStat('$d', 7.5 + ((d * 7) % 16) / 10, 490 + (d * 11) % 50));
      }
    }
    return list;
  }

  List<_DayStat> get _data => _weekView ? _buildWeek() : _buildMonth();

  // ---------- helpers ----------
  String _fmtHours(double h) {
    final whole = h.floor();
    final mins = ((h - whole) * 60).round();
    return '${whole}h ${mins.toString().padLeft(2, '0')}m';
  }

  String _fmtTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final p = Z01Palette.of(context);
    final data = _data;

    // Averages only count days the person was actually present.
    final presentDays = data.where((d) => d.present).toList();
    final avgHours = presentDays.isEmpty
        ? 0.0
        : presentDays.fold<double>(0, (s, d) => s + d.hours) /
            presentDays.length;
    final avgArrival = presentDays.isEmpty
        ? 0
        : (presentDays.fold<int>(0, (s, d) => s + d.arrivalMinutes) /
                presentDays.length)
            .round();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Header + Week/Month ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Insights',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                  _periodToggle(p),
                ],
              ),
              const SizedBox(height: 16),

              // ---------- Two stat cards ----------
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.brand,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AVG ON CAMPUS',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                color: p.onBrand),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fmtHours(avgHours),
                            style: Z01Theme.monoStyle(
                              context: context,
                              fontSize: 20,
                              color: p.onBrand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AVG ARRIVAL',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                color: p.muted),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            presentDays.isEmpty ? '--' : _fmtTime(avgArrival),
                            style: Z01Theme.monoStyle(
                                context: context, fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ---------- Hours on campus (area chart) ----------
              _card(
                p,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIME ON CAMPUS · HOURS PER DAY',
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 0.8, color: p.muted),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(height: 190, child: _hoursChart(p, data)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ---------- Arrival bars + days-present ring ----------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _card(
                      p,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ARRIVAL',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                color: p.muted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Taller bar = later',
                            style: TextStyle(fontSize: 10, color: p.muted),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(height: 110, child: _arrivalChart(p, data)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _card(
                      p,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAYS PRESENT',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                color: p.muted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _weekView ? 'This week' : 'This month',
                            style: TextStyle(fontSize: 10, color: p.muted),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 110,
                            child: _presenceRing(
                                p, presentDays.length, data.length),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI pieces ----------
  Widget _card(Z01Palette p, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }

  Widget _periodToggle(Z01Palette p) {
    Widget option(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? p.text : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? p.bg : p.muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.cardElevated,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          option('Week', _weekView, () => setState(() => _weekView = true)),
          option('Month', !_weekView, () => setState(() => _weekView = false)),
        ],
      ),
    );
  }

  // ---------- Charts ----------
  Widget _hoursChart(Z01Palette p, List<_DayStat> data) {
    // Absent days sit at 0, so the line drops to the floor and rises again.
    // (The averages above still ignore those days.)
    final spots = [
      for (int i = 0; i < data.length; i++)
        FlSpot(i.toDouble(), data[i].present ? data[i].hours : 0),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 12,
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: p.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 4,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}h',
                style: TextStyle(fontSize: 10, color: p.muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                // Month view: label the first day and every 5th day
                if (!_weekView && i != 0 && (i + 1) % 5 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data[i].label,
                    style: TextStyle(fontSize: 10, color: p.muted),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => p.text,
            getTooltipItems: (spots) => spots.map((s) {
              final d = data[s.x.toInt()];
              return LineTooltipItem(
                d.present
                    ? '${d.label} · ${_fmtHours(d.hours)}'
                    : '${d.label} · No check-in',
                TextStyle(
                  color: p.bg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            // Stops the smooth curve from dipping below zero
            preventCurveOverShooting: true,
            color: p.brand,
            barWidth: 2.5,
            // Dots only on days someone was present
            dotData: FlDotData(
              show: _weekView,
              checkToShowDot: (spot, barData) => spot.y > 0,
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  p.brand.withValues(alpha: 0.35),
                  p.brand.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrivalChart(Z01Palette p, List<_DayStat> data) {
    // Bar height = minutes after 07:30, so a taller bar means a later arrival.
    const base = 450;
    final lastPresent = data.lastIndexWhere((d) => d.present);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 180,
        alignment: BarChartAlignment.spaceBetween,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: _weekView,
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[i].label.substring(0, 2), // Mo Tu We Th Fr Sa Su
                    style: TextStyle(fontSize: 9, color: p.muted),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => p.text,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final d = data[group.x];
              if (!d.present) return null; // no tooltip for absent days
              return BarTooltipItem(
                _fmtTime(d.arrivalMinutes),
                TextStyle(
                  color: p.bg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (int i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  // Absent days draw nothing
                  toY: data[i].present
                      ? (data[i].arrivalMinutes - base).toDouble()
                      : 0,
                  width: _weekView ? 10 : 3,
                  color: i == lastPresent ? p.text : p.brand,
                  borderRadius: BorderRadius.circular(99),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _presenceRing(Z01Palette p, int present, int total) {
    final absent = (total - present).clamp(0, total).toDouble();

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            startDegreeOffset: -90,
            sectionsSpace: 0,
            centerSpaceRadius: 34,
            pieTouchData: PieTouchData(enabled: false),
            sections: [
              PieChartSectionData(
                value: present == 0 ? 0.0001 : present.toDouble(),
                color: p.brand,
                radius: 10,
                showTitle: false,
              ),
              PieChartSectionData(
                value: absent == 0 ? 0.0001 : absent,
                color: p.border,
                radius: 10,
                showTitle: false,
              ),
            ],
          ),
        ),
        Text(
          '$present/$total',
          style: Z01Theme.monoStyle(context: context, fontSize: 14),
        ),
      ],
    );
  }
}