import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_view.dart';

class IntroView extends StatefulWidget {
  final void Function(Locale)? setLocale;
  const IntroView({super.key, this.setLocale});

  @override
  State<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<IntroView> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _introData = [
    {
      "title": "QUẢN LÝ KHO THÔNG MINH",
      "desc": "Nhập kho siêu tốc bằng mã QR và IMEI. Kiểm soát hàng hóa chính xác 100% trong lòng bàn tay.",
      "icon": "📦"
    },
    {
      "title": "IN HÓA ĐƠN SIÊU CẤP",
      "desc": "Kết nối máy in nhiệt Bluetooth/WiFi. In tem nhãn, hóa đơn chuyên nghiệp chỉ với 1 chạm.",
      "icon": "🖨️"
    },
    {
      "title": "CHẤM CÔNG & TÍNH LƯƠNG",
      "desc": "Nhân viên chấm công bằng Selfie thực tế. Tự động tính hoa hồng và doanh số minh bạch.",
      "icon": "🎯"
    },
    {
      "title": "ĐỒNG BỘ ĐÁM MÂY 24/7",
      "desc": "Dữ liệu luôn an toàn và đồng bộ tức thì giữa tất cả các máy. Quản trị shop từ xa mọi lúc mọi nơi.",
      "icon": "☁️"
    }
  ];

  Future<void> _completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', false);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.setLocale != null ? LoginView(setLocale: widget.setLocale) : const Scaffold(body: Center(child: Text("Lỗi khởi tạo")))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _introData.length,
            onPageChanged: (v) => setState(() => _currentPage = v),
            itemBuilder: (ctx, i) => _buildSlide(_introData[i]),
          ),
          
          // Nút Skip
          Positioned(
            top: 50, right: 20,
            child: TextButton(onPressed: _completeIntro, child: const Text("BỎ QUA", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ),

          // Chỉ báo trang & Nút tiếp tục
          Positioned(
            bottom: 50, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(_introData.length, (index) => _buildDot(index)),
                ),
                FloatingActionButton(
                  onPressed: () {
                    if (_currentPage < _introData.length - 1) {
                      _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                    } else {
                      _completeIntro();
                    }
                  },
                  backgroundColor: const Color(0xFF2962FF),
                  child: Icon(_currentPage == _introData.length - 1 ? Icons.check : Icons.arrow_forward),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSlide(Map<String, String> data) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data['icon']!, style: const TextStyle(fontSize: 100)),
          const SizedBox(height: 40),
          Text(data['title']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E), letterSpacing: 1.2)),
          const SizedBox(height: 20),
          Text(data['desc']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.blueGrey, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      height: 8, width: _currentPage == index ? 24 : 8,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(color: _currentPage == index ? const Color(0xFF2962FF) : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
    );
  }
}
