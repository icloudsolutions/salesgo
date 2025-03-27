import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<List<BarChartGroupData>> _getChartData() async {
    final snapshot = await FirebaseFirestore.instance.collectionGroup('sales').get();

    final data = snapshot.docs.map((doc) => SalesData(
          doc['agentId'],
          doc['totalAmount'].toDouble(),
        )).toList();

    return data.asMap().entries.map((entry) {
      int index = entry.key;
      SalesData sales = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [BarChartRodData(toY: sales.amount, color: Colors.blue)],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: FutureBuilder<List<BarChartGroupData>>(
        future: _getChartData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: BarChart(
              BarChartData(
                barGroups: snapshot.data!,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: true),
              ),
            ),
          );
        },
      ),
    );
  }

  void _exportToExcel() {
    // Intégrer l'export XLSX ici
  }
}

class SalesData {
  final String agent;
  final double amount;

  SalesData(this.agent, this.amount);
}
