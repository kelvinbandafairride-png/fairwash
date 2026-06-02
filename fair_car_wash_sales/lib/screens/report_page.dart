import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'login_page.dart';

class ReportPage extends StatefulWidget {
  final String role;
  final String username;
  const ReportPage({super.key, required this.role, required this.username});

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
    final local = await StorageService.getSales();
    if (ApiService.isConfigured) {
      final cloud = await ApiService.fetchSales();
      final ids = local.map((s) => s.id).toSet();
      for (final s in cloud) {
        if (!ids.contains(s.id)) local.add(s);
      }
      local.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    _sales = local;
    if (mounted) setState(() => _loading = false);
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()))),
        title: Text('Sales Report · ${widget.username}'),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Color(0xFF25D366)), onPressed: _shareToWhatsApp, tooltip: 'Share via WhatsApp'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadSales(), tooltip: 'Refresh'),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())), tooltip: 'Logout'),
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
            _buildRecentSales(),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
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
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.local_car_wash, size: 20, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Car Wash', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('K ${sale.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                  Text('$day/$month $hour:$min', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ]),
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

    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    String report = '🚗 *FAIR CAR WASH SALES REPORT* 🚗\n';
    report += '━━━━━━━━━━━━━━━━━━━━\n📅 Date: $dateStr\n⏰ Time: $timeStr\n━━━━━━━━━━━━━━━━━━━━\n\n';
    report += '📊 *TODAY*\n• Count: ${today.length}\n• Total: K ${todayTotal.toStringAsFixed(2)}\n\n';
    report += '📈 *ALL TIME*\n• Sales: ${_sales.length}\n• Total: K ${allTotal.toStringAsFixed(2)}\n\n';

    if (today.isNotEmpty) {
      report += '📝 *TODAY DETAILS*\n';
      for (int i = 0; i < today.length && i < 10; i++) {
        final s = today[i];
        final h = s.timestamp.hour.toString().padLeft(2, '0');
        final m = s.timestamp.minute.toString().padLeft(2, '0');
        report += '${i+1}. K ${s.amount.toStringAsFixed(2)} | $h:$m\n';
      }
    }
    report += '\n━━━━━━━━━━━━━━━━━━━━\n✅ Generated by Fair Car Wash';

    final uri = Uri.parse('https://wa.me/260977161191?text=${Uri.encodeFull(report)}');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
