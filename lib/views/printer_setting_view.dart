import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image_picker/image_picker.dart';

class PrinterSettingView extends StatefulWidget {
  const PrinterSettingView({super.key});

  @override
  State<PrinterSettingView> createState() => _PrinterSettingViewState();
}

class _PrinterSettingViewState extends State<PrinterSettingView> {
  final ipCtrl = TextEditingController();
  final labelIpCtrl = TextEditingController();
  bool _isTesting = false;
  String _logoPath = "";
  bool _enableLabelPrinter = false;
  String _selectedLabelPrinterType = "58mm"; // 58mm, 80mm
  
  bool get _hasLogo => _logoPath.isNotEmpty && File(_logoPath).existsSync();

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      ipCtrl.text = prefs.getString('printer_ip') ?? "192.168.1.100";
      _logoPath = prefs.getString('shop_logo_path') ?? "";
      _enableLabelPrinter = prefs.getBool('enable_label_printer') ?? false;
      labelIpCtrl.text = prefs.getString('label_printer_ip') ?? "192.168.1.101";
      _selectedLabelPrinterType = prefs.getString('label_printer_type') ?? "58mm";
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_logo_path', file.path);
    setState(() {
      _logoPath = file.path;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ LƯU LOGO HÓA ĐƠN")));
    }
  }

  Future<void> _saveAndTest() async {
    if (ipCtrl.text.isEmpty) return;
    
    setState(() => _isTesting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_ip', ipCtrl.text);
    await prefs.setBool('enable_label_printer', _enableLabelPrinter);
    await prefs.setString('label_printer_ip', labelIpCtrl.text);
    await prefs.setString('label_printer_type', _selectedLabelPrinterType);

    // THỬ IN TEST QUA WIFI
    const PaperSize paper = PaperSize.mm58; // Thường máy in mini dùng 58mm
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(ipCtrl.text, port: 9100);

    if (res == PosPrintResult.success) {
      // In thử 1 đoạn ngắn
      final generator = Generator(paper, profile);
      printer.text('TEST KET NOI THANH CONG!', styles: const PosStyles(align: PosAlign.center, bold: true));
      printer.feed(2);
      printer.cut();
      printer.disconnect();
      
      // Test máy in tem nếu được bật
      if (_enableLabelPrinter && labelIpCtrl.text.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 1)); // Đợi 1 giây
        
        final labelPaper = _selectedLabelPrinterType == "58mm" ? PaperSize.mm58 : PaperSize.mm80;
        final labelProfile = await CapabilityProfile.load();
        final labelPrinter = NetworkPrinter(labelPaper, labelProfile);
        
        final labelRes = await labelPrinter.connect(labelIpCtrl.text, port: 9100);
        if (labelRes == PosPrintResult.success) {
          labelPrinter.text('TEM TEST', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
          labelPrinter.feed(1);
          labelPrinter.cut();
          labelPrinter.disconnect();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CẢ HAI MÁY IN ĐỀU THÀNH CÔNG!")));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("MÁY IN HÓA ĐƠN OK, NHƯNG MÁY IN TEM LỖI!")));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("KẾT NỐI THÀNH CÔNG & ĐÃ IN THỬ!")));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("LỖI: ${res.msg}. Hãy kiểm tra lại địa chỉ IP!")));
      }
    }
    setState(() => _isTesting = false);
  }

  Future<void> _testLabelPrinter() async {
    if (labelIpCtrl.text.isEmpty) return;
    
    setState(() => _isTesting = true);
    
    // THỬ IN TEM TEST
    final paper = _selectedLabelPrinterType == "58mm" ? PaperSize.mm58 : PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(labelIpCtrl.text, port: 9100);

    if (res == PosPrintResult.success) {
      // In thử tem nhỏ
      final generator = Generator(paper, profile);
      printer.text('TEM TEST', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
      printer.feed(1);
      printer.cut();
      printer.disconnect();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("MÁY IN TEM: KẾT NỐI THÀNH CÔNG!")));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("MÁY IN TEM LỖI: ${res.msg}")));
      }
    }
    setState(() => _isTesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("CÀI ĐẶT MÁY IN", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                ),
                child: Column(
                  children: [
                    const Icon(Icons.wifi_tethering_rounded, size: 60, color: Colors.blueAccent),
                    const SizedBox(height: 15),
                    const Text("MÁY IN WIFI / LAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Text("Kết nối qua địa chỉ IP mạng nội bộ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text("ĐỊA CHỈ IP MÁY IN (VD: 192.168.1.100)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              TextField(
                controller: ipCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: "192.168.1.XXX",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.lan_rounded, color: Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 25),
              
              // MÁY IN TEM THERMAL
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.label_important_rounded, size: 30, color: Colors.orangeAccent),
                        const SizedBox(width: 10),
                        const Text("MÁY IN TEM THERMAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Switch(
                          value: _enableLabelPrinter,
                          onChanged: (value) => setState(() => _enableLabelPrinter = value),
                          activeColor: Colors.orangeAccent,
                        ),
                      ],
                    ),
                    if (_enableLabelPrinter) ...[
                      const SizedBox(height: 15),
                      const Text("LOẠI MÁY IN TEM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedLabelPrinterType,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: "58mm", child: Text("58mm (Tem nhỏ - phổ biến)")),
                            DropdownMenuItem(value: "80mm", child: Text("80mm (Tem lớn)")),
                          ],
                          onChanged: (value) => setState(() => _selectedLabelPrinterType = value!),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text("ĐỊA CHỈ IP MÁY IN TEM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: labelIpCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                        decoration: InputDecoration(
                          hintText: "192.168.1.XXX",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.lan_rounded, color: Colors.orangeAccent),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testLabelPrinter,
                          icon: _isTesting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.orangeAccent, strokeWidth: 2)) : const Icon(Icons.print_rounded, size: 18),
                          label: Text(_isTesting ? "ĐANG TEST..." : "TEST MÁY IN TEM", style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orangeAccent),
                            foregroundColor: Colors.orangeAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 25),
              
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                    ),
                    child: _hasLogo
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(_logoPath), fit: BoxFit.cover),
                          )
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("LOGO HÓA ĐƠN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        SizedBox(height: 4),
                        Text("Chọn ảnh logo (vuông, nền trắng) để in trên hóa đơn chia sẻ.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text("Chọn logo", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isTesting ? null : _saveAndTest,
                  icon: _isTesting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.print_rounded),
                  label: Text(_isTesting ? "ĐANG KIỂM TRA..." : "LƯU & IN THỬ${_enableLabelPrinter ? ' (HÓA ĐƠN+TEM)' : ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Lưu ý: Điện thoại và máy in phải bắt cùng một cục Wifi. Máy in tem chỉ hoạt động khi được bật.",
                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
