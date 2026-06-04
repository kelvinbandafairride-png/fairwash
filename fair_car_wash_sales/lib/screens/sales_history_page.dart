import 'dart:io';
import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../services/storage_service.dart';

class SalesHistoryPage extends StatefulWidget {
  final String role;
  final String username;
  const SalesHistoryPage({super.key, required this.role, required this.username});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  List<Sale> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    _sales = await StorageService.getSales();
    _sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSales, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No sales recorded yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadSales,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sales.length,
                    itemBuilder: (_, i) => _buildSaleCard(_sales[i]),
                  ),
                ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    final day = sale.timestamp.day.toString().padLeft(2, '0');
    final month = sale.timestamp.month.toString().padLeft(2, '0');
    final year = sale.timestamp.year.toString();
    final hour = sale.timestamp.hour.toString().padLeft(2, '0');
    final min = sale.timestamp.minute.toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          if (sale.imagePath != null && File(sale.imagePath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(sale.imagePath!), width: 56, height: 56, fit: BoxFit.cover),
            )
          else
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.local_car_wash, color: Colors.grey),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('K ${sale.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 2),
              Text('${sale.carType}  •  $day/$month/$year $hour:$min', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }
}
