import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/apiservice.dart';
import '../models/sensordata.dart';
import '../models/settings.dart';

class DashboardPage extends StatefulWidget {
  final String deviceId;
  final ValueChanged<String>? onDeviceChanged;

  const DashboardPage({Key? key, required this.deviceId, this.onDeviceChanged})
    : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardPage> {
  SensorData? latestData;
  Settings? settings;
  List<SensorData> historyData = [];
  List<String> deviceIds = [];
  bool isLoading = true;
  bool isLoadingDevices = false;
  String? error;
  Timer? _timer;

  String selectedMetric = 'Temperature';
  int selectedDays = 1;

  final List<String> metrics = ['Temperature', 'Humidity', 'Gas Level'];
  final List<int> dayOptions = [1, 3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    fetchDevices();
    fetchData();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        fetchLatestOnly();
        fetchHistory();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId) {
      setState(() {
        latestData = null;
        settings = null;
        historyData = [];
        isLoading = true;
        error = null;
      });
      fetchData();
    }
  }

  Future<void> refreshDashboard() async {
    await Future.wait([fetchDevices(), fetchData()]);
  }

  Future<void> fetchDevices() async {
    setState(() {
      isLoadingDevices = true;
    });

    try {
      final data = await ApiService().getDeviceList();
      final devices = data.isEmpty ? [widget.deviceId] : data;

      if (!mounted) return;

      setState(() {
        deviceIds = devices;
        isLoadingDevices = false;
      });

      if (!devices.contains(widget.deviceId) && devices.isNotEmpty) {
        widget.onDeviceChanged?.call(devices.first);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        deviceIds = [widget.deviceId];
        isLoadingDevices = false;
      });
      print('Error fetching devices: $e');
    }
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    await Future.wait([fetchLatestOnly(), fetchSettings(), fetchHistory()]);

    if (!mounted) return;

    setState(() {
      isLoading = false;
      if (latestData == null) {
        error = 'No data available';
      }
    });
  }

  Future<void> fetchLatestOnly() async {
    try {
      final data = await ApiService().getLatestData(widget.deviceId);
      if (mounted) {
        setState(() {
          latestData = data;
        });
      }
    } catch (e) {
      print('Error fetching latest: $e');
    }
  }

  Future<void> fetchSettings() async {
    try {
      final data = await ApiService().getSettings(widget.deviceId);
      if (mounted) {
        setState(() {
          settings = data;
        });
      }
    } catch (e) {
      print('Error fetching settings: $e');
    }
  }

  Future<void> fetchHistory() async {
    try {
      final data = await ApiService().getHistory(
        widget.deviceId,
        days: selectedDays,
      );
      if (mounted) {
        setState(() {
          historyData = data;
        });
      }
    } catch (e) {
      print('Error fetching history: $e');
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'CRITICAL':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'CRITICAL':
        return 'CRITICAL';
      case 'WARNING':
        return 'WARNING';
      default:
        return 'NORMAL';
    }
  }

  Color getTemperatureColor() {
    final threshold = settings?.temperatureThreshold;
    if (threshold == null) return Colors.blue;
    return latestData!.temperature > threshold ? Colors.red : Colors.blue;
  }

  Color getHumidityColor() {
    final humidityLow = settings?.humidityThresholdLow;
    final humidityHigh = settings?.humidityThresholdHigh;
    if (humidityLow == null || humidityHigh == null) return Colors.blue;
    if (latestData!.humidity > humidityHigh) return Colors.red;
    if (latestData!.humidity < humidityLow) return Colors.orange;
    return Colors.blue;
  }

  Color getGasColor() {
    final normal = settings?.gasThresholdNormal;
    final warning = settings?.gasThresholdWarning;
    if (normal == null || warning == null) return Colors.green;
    if (latestData!.gasLevel > warning) return Colors.red;
    if (latestData!.gasLevel > normal) return Colors.orange;
    return Colors.green;
  }

  double getMetricValue(SensorData data) {
    switch (selectedMetric) {
      case 'Humidity':
        return data.humidity;
      case 'Gas Level':
        return data.gasLevel.toDouble();
      default:
        return data.temperature;
    }
  }

  String getMetricUnit() {
    switch (selectedMetric) {
      case 'Humidity':
        return '%';
      case 'Gas Level':
        return '';
      default:
        return '°C';
    }
  }

  Color getLineColor() {
    switch (selectedMetric) {
      case 'Humidity':
        return Colors.blue;
      case 'Gas Level':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  List<FlSpot> getChartData() {
    if (historyData.isEmpty) return [];

    return [
      for (int i = 0; i < historyData.length; i++)
        FlSpot(i.toDouble(), getMetricValue(historyData[i])),
    ];
  }

  double getMinValue() {
    if (historyData.isEmpty) return 0;
    final values = historyData.map(getMetricValue);
    final min = values.reduce((a, b) => a < b ? a : b);
    final padding = selectedMetric == 'Gas Level'
        ? 50.0
        : selectedMetric == 'Humidity'
        ? 5.0
        : 2.0;
    return selectedMetric == 'Gas Level' ? 0 : min - padding;
  }

  double getMaxValue() {
    if (historyData.isEmpty) return 100;
    final values = historyData.map(getMetricValue);
    final max = values.reduce((a, b) => a > b ? a : b);
    final padding = selectedMetric == 'Gas Level'
        ? 50.0
        : selectedMetric == 'Humidity'
        ? 5.0
        : 2.0;
    return max + padding;
  }

  double getAverageValue() {
    if (historyData.isEmpty) return 0;
    return historyData.map(getMetricValue).reduce((a, b) => a + b) /
        historyData.length;
  }

  double getLowestValue() {
    if (historyData.isEmpty) return 0;
    return historyData.map(getMetricValue).reduce((a, b) => a < b ? a : b);
  }

  double getHighestValue() {
    if (historyData.isEmpty) return 0;
    return historyData.map(getMetricValue).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshDashboard,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshDashboard,
        child: isLoading && latestData == null
            ? const Center(child: CircularProgressIndicator())
            : latestData == null
            ? _buildEmptyState()
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDeviceSelector(),
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSensorCard(
                            title: 'Temperature',
                            value: latestData!.temperature.toStringAsFixed(1),
                            unit: '°C',
                            icon: Icons.thermostat,
                            color: getTemperatureColor(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSensorCard(
                            title: 'Humidity',
                            value: latestData!.humidity.toStringAsFixed(1),
                            unit: '%',
                            icon: Icons.water_drop,
                            color: getHumidityColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSensorCard(
                            title: 'Gas Level',
                            value: latestData!.gasLevel.toString(),
                            unit: '',
                            icon: Icons.gas_meter,
                            color: getGasColor(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSensorCard(
                            title: 'Door',
                            value: latestData!.doorStatus,
                            unit: '',
                            icon: latestData!.doorStatus == 'OPEN'
                                ? Icons.door_back_door
                                : Icons.door_back_door_outlined,
                            color: latestData!.doorStatus == 'OPEN'
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildHistoryChart(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            error ?? 'No data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: fetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    final dropdownDevices = [
      if (widget.deviceId.isNotEmpty) widget.deviceId,
      ...deviceIds.where((deviceId) => deviceId != widget.deviceId),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.devices, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: widget.deviceId.isEmpty ? null : widget.deviceId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: const Text('Select device'),
              items: dropdownDevices.map((deviceId) {
                return DropdownMenuItem(value: deviceId, child: Text(deviceId));
              }).toList(),
              onChanged: isLoadingDevices
                  ? null
                  : (value) {
                      if (value != null && value != widget.deviceId) {
                        widget.onDeviceChanged?.call(value);
                      }
                    },
            ),
          ),
          if (isLoadingDevices)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getStatusColor(latestData!.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: getStatusColor(latestData!.status).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            latestData!.status == 'CRITICAL'
                ? Icons.dangerous
                : latestData!.status == 'WARNING'
                ? Icons.warning
                : Icons.check_circle,
            color: getStatusColor(latestData!.status),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Refrigerator Status',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  getStatusText(latestData!.status),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: getStatusColor(latestData!.status),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Last Update',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Text(
                DateFormat('HH:mm:ss').format(latestData!.createdAt),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildHistoryChart() {
  final unit = getMetricUnit();

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                value: selectedMetric,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: metrics.map((metric) {
                  return DropdownMenuItem(
                    value: metric,
                    child: Text('$metric Trend'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedMetric = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            DropdownButton<int>(
              value: selectedDays,
              underline: const SizedBox.shrink(),
              items: dayOptions.map((days) {
                return DropdownMenuItem(
                  value: days,
                  child: Text('$days days'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedDays = value;
                  });
                  fetchHistory();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: historyData.isEmpty
              ? const Center(
                  child: Text(
                    'No history data',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (historyData.isEmpty || index < 0 || index >= historyData.length) {
                              return const Text('');
                            }
                            
                            // Determine label format based on selected days
                            String format;
                            if (selectedDays <= 1) {
                              format = 'HH:mm';
                            } else {
                              format = 'MM/dd';
                            }
                            
                            // Show every 5th label or last one to avoid crowding
                            if (index % 5 == 0 || index == historyData.length - 1) {
                              return Text(
                                DateFormat(format).format(historyData[index].createdAt),
                                style: const TextStyle(fontSize: 8),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: historyData.length.toDouble() - 1,
                    minY: getMinValue(),
                    maxY: getMaxValue(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: getChartData(),
                        isCurved: true,
                        color: getLineColor(),
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: getLineColor().withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMiniStat(
              'Avg',
              historyData.isEmpty
                  ? '--'
                  : getAverageValue().toStringAsFixed(1),
              unit,
              Colors.blue,
            ),
            _buildMiniStat(
              'Min',
              historyData.isEmpty
                  ? '--'
                  : getLowestValue().toStringAsFixed(1),
              unit,
              Colors.green,
            ),
            _buildMiniStat(
              'Max',
              historyData.isEmpty
                  ? '--'
                  : getHighestValue().toStringAsFixed(1),
              unit,
              Colors.red,
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(
                    unit,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, String unit, Color color) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
