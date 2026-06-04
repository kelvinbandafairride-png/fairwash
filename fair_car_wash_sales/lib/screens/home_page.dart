import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'login_page.dart';
import 'sales_history_page.dart';

class HomePage extends StatefulWidget {
  final String role;
  final String username;
  const HomePage({super.key, required this.role, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String _carType = 'Sedan';
  File? _imageFile;
  final _picker = ImagePicker();
  bool _uploading = false;

  int _bgIndex = 0;
  Timer? _bgTimer;
  List<Sale> _sales = [];
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
    _loadData();
  }

  @override
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1024);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take Photo'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _bgTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _sales = await StorageService.getSales();
    _updateSummary();
  }

  void _updateSummary() {
    final now = DateTime.now();
    final today = _sales.where((s) =>
      s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day
    ).toList();
    setState(() {
      _todayCount = today.length;
      _todayTotal = today.fold(0.0, (s, v) => s + v.amount);
    });
  }

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _uploading = true);

    String? savedImage;
    if (_imageFile != null) {
      savedImage = await StorageService.copyImage(_imageFile!.path);
    }

    final sale = Sale(amount: amount, carType: _carType, imagePath: savedImage);

    await StorageService.addSale(sale);
    _sales.add(sale);
    _amountController.clear();
    setState(() { _imageFile = null; _carType = 'Sedan'; _uploading = false; });
    _updateSummary();

    if (ApiService.isConfigured) {
      final ok = await ApiService.addSale(sale);
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally, cloud sync failed'), backgroundColor: Colors.orange),
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale recorded: K ${amount.toStringAsFixed(2)}'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _shareToWhatsApp() async {
    if (_sales.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sales to share'), backgroundColor: Colors.orange),
      );
      return;
    }

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
      if (today.length > 10) report += '   ... and ${today.length - 10} more\n';
    }
    report += '\n━━━━━━━━━━━━━━━━━━━━\n✅ Generated by Fair Car Wash';

    final uri = Uri.parse('https://wa.me/260977161191?text=${Uri.encodeFull(report)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'whatsapp',
        onPressed: _shareToWhatsApp,
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.share, color: Colors.white),
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
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Fair Car Wash', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text('${widget.username} (${widget.role})', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white70),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SalesHistoryPage(role: widget.role, username: widget.username))),
          tooltip: 'History',
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white70),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
          tooltip: 'Logout',
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
          const Text('Car Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _carType,
            items: const [
              DropdownMenuItem(value: 'Sedan', child: Text('Sedan')),
              DropdownMenuItem(value: 'Medium Size', child: Text('Medium Size')),
              DropdownMenuItem(value: 'Big Van', child: Text('Big Van')),
            ],
            onChanged: (v) { if (v != null) setState(() => _carType = v); },
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(height: 14),
          const Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(prefixText: 'K ', hintText: '0.00', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            validator: (v) { if (v == null || v.isEmpty) return 'Enter amount'; final n = double.tryParse(v); if (n == null || n <= 0) return 'Enter a valid amount'; return null; },
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text(_imageFile != null ? 'Change Photo' : 'Add Photo'),
                onPressed: _showImagePicker,
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            if (_imageFile != null) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_imageFile!, width: 48, height: 48, fit: BoxFit.cover),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _imageFile = null),
                child: const Icon(Icons.close, size: 18, color: Colors.red),
              ),
            ],
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _uploading ? null : _submitSale,
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), foregroundColor: Colors.white),
              child: _uploading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Record Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}
