import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _groupBy = 'day';
  bool _isLoading = false;
  List<String> _allAgents = [];
  List<String> _selectedAgents = [];
  bool _selectAllAgents = true;
  Map<String, String> _agentIdToNameMap = {};
  List<BarChartGroupData> _chartData = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchAgents();
    await _loadChartData();
  }

  Future<void> _fetchAgents() async {
    try {
      final snapshot = await _firestore.collection('users')
          .where('role', isEqualTo: 'agent')
          .get();
      
      setState(() {
        _agentIdToNameMap = {
          for (var doc in snapshot.docs) 
            doc.id: doc['name'] as String
        };
        _allAgents = _agentIdToNameMap.values.toList();
        _selectedAgents = List.from(_allAgents);
      });
    } catch (e) {
      _handleError('Error fetching agents: $e');
    }
  }

  Future<void> _loadChartData() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    try {
      final data = await _getChartData();
      setState(() => _chartData = data);
    } catch (e) {
      _handleError('Error loading chart data: $e');
      setState(() => _chartData = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<BarChartGroupData>> _getChartData() async {
    try {
      Query query = _firestore.collectionGroup('sales')
        .where('date', isGreaterThanOrEqualTo: _dateRange.start)
        .where('date', isLessThanOrEqualTo: _dateRange.end);

      if (!_selectAllAgents && _selectedAgents.isNotEmpty) {
        final agentIds = _selectedAgents.map((name) => 
          _agentIdToNameMap.keys.firstWhere((id) => _agentIdToNameMap[id] == name))
          .toList();
        query = query.where('agentId', whereIn: agentIds);
      }

      final QuerySnapshot snapshot = await query.orderBy('date').get();
      final Map<String, double> groupedData = {};

      for (final doc in snapshot.docs) {
        try {
          final date = (doc['date'] as Timestamp).toDate();
          final amount = (doc['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final agentId = doc['agentId'] as String? ?? '';
          final agentName = _agentIdToNameMap[agentId] ?? 'Unknown';
          final periodKey = _getPeriodKey(date);
          final groupKey = '${periodKey}_$agentName';
          
          groupedData.update(
            groupKey,
            (value) => value + amount,
            ifAbsent: () => amount,
          );
        } catch (e) {
          debugPrint('Error processing document ${doc.id}: $e');
        }
      }

      final groupKeys = groupedData.keys.toList();
      return groupedData.entries.map((entry) {
        return BarChartGroupData(
          x: groupKeys.indexOf(entry.key),
          barRods: [
            BarChartRodData(
              toY: entry.value,
              color: Colors.blue,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          showingTooltipIndicators: [0],
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching chart data: $e');
      return [];
    }
  }

  Future<Map<String, Map<String, double>>> _getExportData() async {
    try {
      Query query = _firestore.collectionGroup('sales')
        .where('date', isGreaterThanOrEqualTo: _dateRange.start)
        .where('date', isLessThanOrEqualTo: _dateRange.end);

      if (!_selectAllAgents && _selectedAgents.isNotEmpty) {
        final agentIds = _selectedAgents.map((name) => 
          _agentIdToNameMap.keys.firstWhere((id) => _agentIdToNameMap[id] == name))
          .toList();
        query = query.where('agentId', whereIn: agentIds);
      }

      final QuerySnapshot snapshot = await query.orderBy('date').get();
      final Map<String, Map<String, double>> exportData = {};

      for (final doc in snapshot.docs) {
        final date = (doc['date'] as Timestamp).toDate();
        final amount = (doc['totalAmount'] as num).toDouble();
        final agentId = doc['agentId'] as String;
        final agentName = _agentIdToNameMap[agentId] ?? 'Unknown';
        final periodKey = _getPeriodKey(date);

        exportData.putIfAbsent(periodKey, () => {});
        exportData[periodKey]!.update(
          agentName,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }

      return exportData;
    } catch (e) {
      debugPrint('Error fetching export data: $e');
      return {};
    }
  }

  String _getPeriodKey(DateTime date) {
    switch (_groupBy) {
      case 'day':
        return DateFormat('yyyy-MM-dd').format(date);
      case 'week':
        return 'Week ${DateFormat('w').format(date)}';
      case 'month':
        return DateFormat('yyyy-MM').format(date);
      default:
        return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Future<Directory> _getSafeDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Request permission to manage external storage
        PermissionStatus permission = await Permission.manageExternalStorage.request();
        if (!permission.isGranted) {
          throw Exception('Permission denied to access storage.');
        }

        // Try to access the real Downloads folder
        final directories = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (directories == null || directories.isEmpty) {
          throw Exception('Downloads directory not found.');
        }
        return directories.first;
      } else if (Platform.isIOS) {
        // For iOS, use the safe downloads directory
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Downloads directory not available on iOS.');
        }
        return directory;
      } else {
        // For other platforms, fallback to temporary directory
        return await getTemporaryDirectory();
      }
    } catch (e) {
      debugPrint('Error accessing download directory: $e');
      // If any error happens, fallback to temporary directory
      return await getTemporaryDirectory();
    }
  }


  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);
    try {
      final data = await _getExportData();
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export')),
        );
        return;
      }

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];

      // Write Excel content
      sheet.getRangeByName('A1').setText('Period');
      int col = 1;
      final allAgents = _selectAllAgents ? _allAgents : _selectedAgents;
      for (final agent in allAgents) {
        sheet.getRangeByIndex(1, ++col).setText(agent);
      }
      sheet.getRangeByIndex(1, ++col).setText('Total');
      sheet.getRangeByName('A1:${_getExcelColumnName(col)}1').cellStyle.bold = true;

      int row = 2;
      data.forEach((period, agentData) {
        sheet.getRangeByIndex(row, 1).setText(period);
        double rowTotal = 0;
        col = 1;
        for (final agent in allAgents) {
          final amount = agentData[agent] ?? 0;
          sheet.getRangeByIndex(row, ++col).setNumber(amount);
          rowTotal += amount;
        }
        sheet.getRangeByIndex(row, ++col).setNumber(rowTotal);
        row++;
      });

      sheet.getRangeByIndex(row, 1).setText('TOTAL');
      col = 1;
      for (final agent in allAgents) {
        final colLetter = _getExcelColumnName(++col);
        sheet.getRangeByName('$colLetter$row').setFormula('SUM(${colLetter}2:${colLetter}${row-1})');
      }
      final totalCol = _getExcelColumnName(++col);
      sheet.getRangeByName('${totalCol}$row').setFormula('SUM(${totalCol}2:${totalCol}${row-1})');
      sheet.getRangeByName('A$row:$totalCol$row').cellStyle.bold = true;
      sheet.getRangeByName('A1:$totalCol$row').autoFitColumns();

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      // Ask user to pick a folder
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No folder selected')),
        );
        return;
      }

      final fileName = 'SalesReport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('$selectedDirectory/$fileName');
      await file.writeAsBytes(bytes);

      await OpenFile.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to $fileName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  String _getExcelColumnName(int column) {
    String name = '';
    while (column > 0) {
      column--;
      name = '${String.fromCharCode(65 + column % 26)}$name';
      column = column ~/ 26;
    }
    return name;
  }

  Future<void> _exportToPDF() async {
    setState(() => _isLoading = true);
    try {
      final data = await _getExportData();
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export')),
        );
        return;
      }

      final pdf = pw.Document();
      final allAgents = _selectAllAgents ? _allAgents : _selectedAgents;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Sales Report',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Text(
                  'Date Range: ${DateFormat('MMM dd, yyyy').format(_dateRange.start)} - '
                  '${DateFormat('MMM dd, yyyy').format(_dateRange.end)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                if (!_selectAllAgents)
                  pw.Text(
                    'Agents: ${_selectedAgents.join(', ')}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  context: context,
                  headers: ['Period', ...allAgents, 'Total'],
                  data: data.entries.map((entry) {
                    final period = entry.key;
                    final agentData = entry.value;
                    final total = agentData.values.fold(0.0, (sum, amount) => sum + amount);

                    return [
                      period,
                      ...allAgents.map((agent) => agentData[agent]?.toStringAsFixed(2) ?? '0.00'),
                      total.toStringAsFixed(2)
                    ];
                  }).toList(),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            );
          },
        ),
      );

      // Save the PDF file
      final directory = await _getSafeDownloadDirectory();
      final fileName = 'SalesReport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Try to open the file
      final result = await OpenFile.open(file.path);

      // Notify the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to $fileName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _showAgentFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter by Agent'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('All Agents'),
                      value: _selectAllAgents,
                      onChanged: (value) {
                        setState(() {
                          _selectAllAgents = value ?? true;
                          if (_selectAllAgents) {
                            _selectedAgents = List.from(_allAgents);
                          }
                        });
                      },
                    ),
                    const Divider(),
                    ..._allAgents.map((agent) {
                      return CheckboxListTile(
                        title: Text(agent),
                        value: _selectedAgents.contains(agent),
                        onChanged: _selectAllAgents
                            ? null
                            : (value) {
                                setState(() {
                                  if (value ?? false) {
                                    _selectedAgents.add(agent);
                                  } else {
                                    _selectedAgents.remove(agent);
                                  }
                                });
                              },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadChartData();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    
    if (picked != null && picked != _dateRange) {
      setState(() => _dateRange = picked);
      await _loadChartData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showAgentFilterDialog,
            tooltip: 'Filter by Agent',
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Select Date Range',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.group_work),
            onSelected: (value) {
              setState(() => _groupBy = value);
              _loadChartData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'day', child: Text('Daily')),
              const PopupMenuItem(value: 'week', child: Text('Weekly')),
              const PopupMenuItem(value: 'month', child: Text('Monthly')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (value) {
              if (value == 'excel') _exportToExcel();
              if (value == 'pdf') _exportToPDF();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'excel', child: Text('Export to Excel')),
              const PopupMenuItem(value: 'pdf', child: Text('Export to PDF')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chartData.isEmpty
              ? const Center(child: Text('No sales data available'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Sales Report: ${DateFormat('MMM dd, yyyy').format(_dateRange.start)} - '
                        '${DateFormat('MMM dd, yyyy').format(_dateRange.end)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (!_selectAllAgents)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Agents: ${_selectedAgents.join(', ')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barGroups: _chartData,
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                  reservedSize: 40,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < _chartData.length) {
                                      final date = _dateRange.start.add(Duration(days: index));
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          _getPeriodKey(date),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 32,
                                ),
                              ),
                            ),
                            gridData: FlGridData(show: true),
                            borderData: FlBorderData(show: false),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (BarChartGroupData group) => Colors.blueGrey,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final date = _dateRange.start.add(Duration(days: groupIndex));
                                  return BarTooltipItem(
                                    '${_getPeriodKey(date)}\n',
                                    const TextStyle(color: Colors.white),
                                    children: [
                                      TextSpan(
                                        text: '€${rod.toY.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.yellow,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
    void _handleError(String message) {
    debugPrint(message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}