import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import 'report_page.dart';

class HomePage extends StatefulWidget {
  final String token;
  final String username;
  const HomePage({super.key, required this.token, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  VehicleType _vehicleType = VehicleType.midsized;
  VehicleSize _vehicleSize = VehicleSize.small;
  WashType _washType = WashType.outside;
  WashCategory _washCategory = WashCategory.basic;
  final _amountController = TextEditingController();
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _colorController = TextEditingController();
  final _frontConditionController = TextEditingController();
  final _backConditionController = TextEditingController();

  String? _frontImagePath;
  String? _backImagePath;

  int _bgIndex = 0;
  Timer? _bgTimer;

  int _todayCount = 0;
  double _todayTotal = 0;

  final List<List<Color>> _bgPalettes = [
    [const Color(0xFF1A2980), const Color(0xFF26D0CE)],
    [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)],
    [const Color(0xFF373B44), const Color(0xFF4286F4)],
    [const Color(0xFF4CA1AF), const Color(0xFFC4E0E5)],
    [const Color(0xFF232526), const Color(0xFF414345)],
    [const Color(0xFF000428), const Color(0xFF004E92)],
  ];

  @override
  void initState() {
    super.initState();
    _bgTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) setState(() => _bgIndex = (_bgIndex + 1) % _bgPalettes.length);
    });
    _refreshSummary();
  }

  @override
  void dispose() {
    _bgTimer?.cancel();
    _amountController.dispose();
    _plateController.dispose();
    _makeController.dispose();
    _colorController.dispose();
    _frontConditionController.dispose();
    _backConditionController.dispose();
    super.dispose();
  }

  Future<void> _refreshSummary() async {
    try {
      final summary = await ApiService.getSummary(widget.token, period: 'today');
      if (mounted) setState(() {
        _todayCount = summary['count'] ?? 0;
        _todayTotal = (summary['total'] ?? 0).toDouble();
      });
    } catch (_) {}
  }

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    final sale = Sale(
      vehicleType: _vehicleType,
      vehicleSize: _vehicleSize,
      washType: _washType,
      washCategory: _washCategory,
      amount: amount,
      licensePlate: _plateController.text.trim(),
      carMake: _makeController.text.trim(),
      carColor: _colorController.text.trim(),
      frontCondition: _frontConditionController.text.trim(),
      backCondition: _backConditionController.text.trim(),
    );

    try {
      await ApiService.createSale(widget.token, sale.toJson());
      _amountController.clear();
      _plateController.clear();
      _makeController.clear();
      _colorController.clear();
      _frontConditionController.clear();
      _backConditionController.clear();
      setState(() { _frontImagePath = null; _backImagePath = null; });
      await _refreshSummary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale recorded: K ${amount.toStringAsFixed(2)}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareToWhatsApp() async {
    try {
      final allSales = await ApiService.getSales(widget.token);
      if (allSales.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sales to share'), backgroundColor: Colors.orange),
        );
        return;
      }

      final now = DateTime.now();
      final all = allSales.map((s) => Sale.fromJson(s)).toList();
      final today = all.where((s) =>
        s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day
      ).toList();

      final todayTotal = today.fold(0.0, (s, v) => s + v.amount);
      final allTotal = all.fold(0.0, (s, v) => s + v.amount);

      String group(List<Sale> list, String Function(Sale) key) {
        final m = <String, double>{};
        for (final s in list) {
          final k = key(s); m[k] = (m[k] ?? 0) + s.amount;
        }
        return m.entries.map((e) => '• ${e.key}: K ${e.value.toStringAsFixed(2)}').join('\n');
      }

      final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      String report = '🚗 *FAIR CAR WASH SALES REPORT* 🚗\n';
      report += '━━━━━━━━━━━━━━━━━━━━\n';
      report += '📅 Date: $dateStr\n⏰ Time: $timeStr\n';
      report += '━━━━━━━━━━━━━━━━━━━━\n\n';
      report += '📊 *TODAY*\n• Count: ${today.length}\n• Total: K ${todayTotal.toStringAsFixed(2)}\n\n';
      report += '📈 *ALL TIME*\n• Sales: ${all.length}\n• Total: K ${allTotal.toStringAsFixed(2)}\n\n';
      report += '🚙 *BY VEHICLE*\n${group(all, (s) => s.vehicleTypeLabel)}\n\n';
      report += '🧽 *BY WASH TYPE*\n${group(all, (s) => s.washTypeLabel)}\n\n';
      report += '📋 *BY CATEGORY*\n${group(all, (s) => s.washCategory.label)}\n\n';

      if (today.isNotEmpty) {
        report += '📝 *TODAY DETAILS*\n';
        for (int i = 0; i < today.length && i < 10; i++) {
          final s = today[i];
          final h = s.timestamp.hour.toString().padLeft(2, '0');
          final m = s.timestamp.minute.toString().padLeft(2, '0');
          report += '${i+1}. ${s.vehicleTypeLabel} | ${s.washTypeLabel} | K ${s.amount.toStringAsFixed(2)} | $h:$m\n';
          if (s.licensePlate.isNotEmpty) report += '   Plate: ${s.licensePlate}\n';
        }
        if (today.length > 10) report += '   ... and ${today.length - 10} more\n';
      }
      report += '\n━━━━━━━━━━━━━━━━━━━━\n✅ Generated by Fair Car Wash';

      final uri = Uri.parse('https://wa.me/260977161191?text=${Uri.encodeFull(report)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _captureImage({required bool isFront}) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024, imageQuality: 70,
      );
      if (photo != null) setState(() {
        if (isFront) _frontImagePath = photo.path; else _backImagePath = photo.path;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildCameraButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500, fontSize: 14)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _bgPalettes[_bgIndex];
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: palette),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildTodaySummary(),
              const SizedBox(height: 16),
              _buildForm(),
            ]),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'whatsapp',
            onPressed: _shareToWhatsApp,
            backgroundColor: const Color(0xFF25D366),
            child: const Icon(Icons.share, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'report',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ReportPage(token: widget.token),
              ));
            },
            icon: const Icon(Icons.bar_chart),
            label: const Text('Sales Report'),
            backgroundColor: Colors.white.withOpacity(0.9),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const Icon(Icons.local_car_wash, color: Colors.white, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Fair Car Wash', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(widget.username, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: const Text('v2.0', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _buildTodaySummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _summaryItem(Icons.receipt_long, '$_todayCount', "Today's Sales"),
        Container(height: 40, width: 1, color: Colors.white30),
        _summaryItem(Icons.monetization_on, 'K ${_todayTotal.toStringAsFixed(0)}', "Today's Total"),
      ]),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, color: Colors.white, size: 28),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('New Wash Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _bgPalettes[_bgIndex].first)),
          const Divider(height: 24),
          const Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          _buildSegmentedControl(
            value: _vehicleType,
            items: {VehicleType.midsized: '🚗 Mid Sized', VehicleType.big: '🚙 Big', VehicleType.van: '🚐 Van'},
            onChanged: (v) => setState(() => _vehicleType = v),
          ),
          const SizedBox(height: 16),
          const Text('Vehicle Size', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          _buildSegmentedControl(
            value: _vehicleSize,
            items: {VehicleSize.small: 'Small', VehicleSize.big: 'Big'},
            onChanged: (v) => setState(() => _vehicleSize = v),
          ),
          const SizedBox(height: 16),
          const Text('Wash Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          _buildSegmentedControl(
            value: _washType,
            items: {WashType.outside: 'Outside Wash', WashType.inside: 'Inside Wash', WashType.both: 'Both'},
            onChanged: (v) => setState(() => _washType = v),
          ),
          const SizedBox(height: 16),
          const Text('Wash Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          DropdownButtonFormField<WashCategory>(
            value: _washCategory,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: WashCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) { if (v != null) setState(() => _washCategory = v); },
          ),
          const SizedBox(height: 16),
          const Text('License Plate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _plateController, textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: 'e.g. AB 1234', prefixIcon: const Icon(Icons.confirmation_number, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(height: 12),
          const Text('Car Make / Model', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _makeController, textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: 'e.g. Toyota Corolla', prefixIcon: const Icon(Icons.directions_car, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(height: 12),
          const Text('Car Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _colorController, textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: 'e.g. White, Blue, Red', prefixIcon: const Icon(Icons.palette, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(height: 16),
          const Text('Front Condition', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _frontConditionController, maxLines: 2, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'e.g. Muddy, dusty, bird droppings', prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 30), child: Icon(Icons.front_hand, size: 20)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(height: 12),
          const Text('Front Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          _buildCameraButton(label: _frontImagePath != null ? 'Front Photo Captured' : 'Capture Front Photo', icon: Icons.camera_alt, onTap: () => _captureImage(isFront: true)),
          if (_frontImagePath != null) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_frontImagePath!), height: 80, width: double.infinity, fit: BoxFit.cover)),
          ),
          const SizedBox(height: 12),
          const Text('Back Condition', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _backConditionController, maxLines: 2, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'e.g. Muddy, dusty, exhaust stains', prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 30), child: Icon(Icons.back_hand, size: 20)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(height: 8),
          const Text('Back Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          _buildCameraButton(label: _backImagePath != null ? 'Back Photo Captured' : 'Capture Back Photo', icon: Icons.camera_alt, onTap: () => _captureImage(isFront: false)),
          if (_backImagePath != null) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_backImagePath!), height: 80, width: double.infinity, fit: BoxFit.cover)),
          ),
          const SizedBox(height: 16),
          const Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(prefixText: 'K ', hintText: '0.00', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            validator: (v) { if (v == null || v.isEmpty) return 'Enter amount'; final n = double.tryParse(v); if (n == null || n <= 0) return 'Enter a valid amount'; return null; },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _submitSale,
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), foregroundColor: Colors.white),
              child: const Text('Record Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSegmentedControl<T>({required T value, required Map<T, String> items, required ValueChanged<T> onChanged}) {
    return Row(children: items.entries.map((entry) {
      final selected = entry.key == value;
      return Expanded(child: GestureDetector(
        onTap: () => onChanged(entry.key),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: selected ? Colors.blue : Colors.grey[200], borderRadius: BorderRadius.circular(10)),
          child: Text(entry.value, textAlign: TextAlign.center,
            style: TextStyle(color: selected ? Colors.white : Colors.grey[700], fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ),
      ));
    }).toList());
  }
}
