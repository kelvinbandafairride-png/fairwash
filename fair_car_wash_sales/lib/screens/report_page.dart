import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale.dart';
import '../services/api_service.dart';

class ReportPage extends StatefulWidget {
  final String token;
  const ReportPage({super.key, required this.token});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<Sale> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getSales(widget.token);
      if (mounted) setState(() {
        _sales = data.map((s) => Sale.fromJson(s)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Sales Report')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_sales.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sales Report')),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No sales recorded yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
        ])),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Color(0xFF25D366)), onPressed: _shareToWhatsApp, tooltip: 'Share via WhatsApp'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadSales(), tooltip: 'Refresh'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSales,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildGrandTotalCard(),
            const SizedBox(height: 16),
            _buildBreakdownCard(title: 'By Vehicle Type', icon: Icons.directions_car, data: _breakdownBy('vehicleTypeLabel')),
            const SizedBox(height: 12),
            _buildBreakdownCard(title: 'By Wash Type', icon: Icons.clean_hands, data: _breakdownBy('washTypeLabel')),
            const SizedBox(height: 12),
            _buildBreakdownCard(title: 'By Wash Category', icon: Icons.category, data: _breakdownBy('category')),
            const SizedBox(height: 12),
            _buildBreakdownCard(title: 'By Vehicle Size', icon: Icons.straighten, data: _breakdownBy('size')),
            const SizedBox(height: 12),
            _buildRecentSales(),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Map<String, double> _breakdownBy(String key) {
    final map = <String, double>{};
    for (final s in _sales) {
      String k;
      switch (key) {
        case 'vehicleTypeLabel': k = s.vehicleTypeLabel; break;
        case 'washTypeLabel': k = s.washTypeLabel; break;
        case 'category': k = s.washCategory.label; break;
        case 'size': k = s.vehicleSizeLabel; break;
        default: k = '';
      }
      map[k] = (map[k] ?? 0) + s.amount;
    }
    return map;
  }

  Widget _buildGrandTotalCard() {
    final total = _sales.fold(0.0, (s, v) => s + v.amount);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A2980), Color(0xFF26D0CE)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        const Text('Grand Total Revenue', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Text('K ${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${_sales.length} sale${_sales.length == 1 ? '' : 's'} recorded', style: const TextStyle(color: Colors.white60, fontSize: 14)),
        const SizedBox(height: 4),
        Text('📅 ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    );
  }

  Widget _buildBreakdownCard({required String title, required IconData icon, required Map<String, double> data}) {
    final total = data.values.fold(0.0, (s, v) => s + v);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 20, color: Colors.blueGrey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        const Divider(height: 20),
        ...data.entries.map((entry) {
          final pct = total > 0 ? (entry.value / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(flex: 3, child: Text(entry.key, style: const TextStyle(fontSize: 14))),
              Expanded(flex: 2, child: Text('K ${entry.value.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              const SizedBox(width: 8),
              SizedBox(width: 50, child: Text('${pct.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
            ]),
          );
        }),
        const Divider(height: 8),
        Row(children: [const Spacer(), Text('Total: K ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
      ]),
    );
  }

  Widget _buildRecentSales() {
    final recent = _sales.reversed.take(10).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.receipt_long, size: 20, color: Colors.blueGrey), const SizedBox(width: 8), const Text('Recent Sales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        const Divider(height: 20),
        ...recent.map((sale) {
          final hour = sale.timestamp.hour.toString().padLeft(2, '0');
          final min = sale.timestamp.minute.toString().padLeft(2, '0');
          final day = sale.timestamp.day.toString().padLeft(2, '0');
          final month = sale.timestamp.month.toString().padLeft(2, '0');
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Icon(sale.vehicleType == VehicleType.midsized ? Icons.directions_car : sale.vehicleType == VehicleType.van ? Icons.airport_shuttle : Icons.directions_bus, size: 20, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${sale.vehicleTypeLabel} (${sale.vehicleSizeLabel}) - ${sale.washTypeLabel}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(sale.washCategory.label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('K ${sale.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                    Text('$day/$month $hour:$min', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ]),
                ]),
                if (sale.licensePlate.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
                    Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text('🔑 ${sale.licensePlate}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.orange.shade800))),
                    if (sale.carMake.isNotEmpty) Text(sale.carMake, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    if (sale.carMake.isNotEmpty && sale.carColor.isNotEmpty) Text('  •  ', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    if (sale.carColor.isNotEmpty) Text(sale.carColor, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  ])),
              ]),
            ),
          );
        }),
        if (_sales.length > 10) Padding(padding: const EdgeInsets.only(top: 8),
          child: Center(child: Text('Showing 10 of ${_sales.length} sales', style: TextStyle(color: Colors.grey[500], fontSize: 12)))),
      ]),
    );
  }

  void _shareToWhatsApp() {
    if (_sales.isEmpty) return;
    final now = DateTime.now();
    final today = _sales.where((s) =>
      s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day
    ).toList();
    final todayTotal = today.fold(0.0, (s, v) => s + v.amount);
    final allTotal = _sales.fold(0.0, (s, v) => s + v.amount);

    String group(String Function(Sale) key) {
      final m = <String, double>{};
      for (final s in _sales) { final k = key(s); m[k] = (m[k] ?? 0) + s.amount; }
      return m.entries.map((e) => '• ${e.key}: K ${e.value.toStringAsFixed(2)}').join('\n');
    }

    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    String report = '🚗 *FAIR CAR WASH SALES REPORT* 🚗\n';
    report += '━━━━━━━━━━━━━━━━━━━━\n📅 Date: $dateStr\n⏰ Time: $timeStr\n━━━━━━━━━━━━━━━━━━━━\n\n';
    report += '📊 *TODAY*\n• Count: ${today.length}\n• Total: K ${todayTotal.toStringAsFixed(2)}\n\n';
    report += '📈 *ALL TIME*\n• Sales: ${_sales.length}\n• Total: K ${allTotal.toStringAsFixed(2)}\n\n';
    report += '🚙 *BY VEHICLE*\n${group((s) => s.vehicleTypeLabel)}\n\n';
    report += '🧽 *BY WASH TYPE*\n${group((s) => s.washTypeLabel)}\n\n';
    report += '📋 *BY CATEGORY*\n${group((s) => s.washCategory.label)}\n\n';

    if (today.isNotEmpty) {
      report += '📝 *TODAY DETAILS*\n';
      for (int i = 0; i < today.length && i < 10; i++) {
        final s = today[i];
        final h = s.timestamp.hour.toString().padLeft(2, '0');
        final m = s.timestamp.minute.toString().padLeft(2, '0');
        report += '${i+1}. ${s.vehicleTypeLabel} | ${s.washTypeLabel} | K ${s.amount.toStringAsFixed(2)} | $h:$m\n';
        if (s.licensePlate.isNotEmpty) report += '   Plate: ${s.licensePlate}\n';
      }
    }
    report += '\n━━━━━━━━━━━━━━━━━━━━\n✅ Generated by Fair Car Wash';

    final uri = Uri.parse('https://wa.me/260977161191?text=${Uri.encodeFull(report)}');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
